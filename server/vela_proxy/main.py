import asyncio
import logging
import shutil
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path

import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, PlainTextResponse
from pydantic import BaseModel

from .config import BASE_DIR, FFMPEG_PATH, HOST, PORT, SESSION_TTL_HOURS
from .ffmpeg import probe_url, transcode_to_hls

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

sessions_dir = BASE_DIR / "sessions"
sessions_dir.mkdir(exist_ok=True)

active_sessions: dict[str, dict] = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Vela Proxy starting — sessions dir: %s", sessions_dir)
    cleanup_task = asyncio.create_task(session_cleanup_loop())
    yield
    # Shutdown
    cleanup_task.cancel()
    try:
        await cleanup_task
    except asyncio.CancelledError:
        pass


app = FastAPI(title="Vela Proxy", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class StreamRequest(BaseModel):
    url: str
    title: str = "unknown"


class StreamResponse(BaseModel):
    session_id: str
    manifest_url: str
    strategy: str
    message: str


@app.get("/health")
async def health():
    ffmpeg_ok = shutil.which(FFMPEG_PATH) is not None
    return {"status": "ok", "ffmpeg": ffmpeg_ok}


@app.post("/stream", response_model=StreamResponse)
async def create_stream(req: StreamRequest):
    """Given a direct media URL, probe it and start transcoding if needed."""
    logger.info("Stream request for: %s", req.url)

    probe = await probe_url(req.url)
    if not probe:
        raise HTTPException(status_code=400, detail="Could not probe media URL")

    logger.info(
        "Probe: video=%s audio=%s roku_safe=%s",
        probe.video_codec,
        probe.audio_codec,
        probe.is_roku_safe,
    )

    session_id = str(uuid.uuid4())
    output_dir = sessions_dir / session_id
    output_dir.mkdir(parents=True, exist_ok=True)

    if probe.is_roku_safe:
        # Write a simple HLS manifest pointing to the original URL
        # Roku handles direct MP4/HLS URLs fine
        strategy = "direct_proxy"
        manifest = output_dir / "index.m3u8"
        manifest.write_text(
            f"#EXTM3U\n"
            f"#EXT-X-VERSION:3\n"
            f"#EXT-X-TARGETDURATION:10\n"
            f"#EXTINF:10.0,\n"
            f"{req.url}\n"
            f"#EXT-X-ENDLIST\n"
        )
        message = "Direct proxy — no transcoding needed"
    else:
        strategy = "transcode"
        proc = await transcode_to_hls(req.url, output_dir, probe)
        active_sessions[session_id] = {
            "proc": proc,
            "started": datetime.now(timezone.utc),
            "url": req.url,
        }
        message = f"Transcoding: video={probe.video_codec} audio={probe.audio_codec}"

    manifest_url = f"/sessions/{session_id}/index.m3u8"

    return StreamResponse(
        session_id=session_id,
        manifest_url=manifest_url,
        strategy=strategy,
        message=message,
    )


@app.get("/sessions/{session_id}/{filename}")
async def serve_session_file(session_id: str, filename: str):
    file_path = sessions_dir / session_id / filename
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")

    if filename.endswith(".m3u8"):
        return PlainTextResponse(
            content=file_path.read_text(),
            media_type="application/vnd.apple.mpegurl",
        )
    elif filename.endswith(".ts"):
        return FileResponse(
            path=file_path,
            media_type="video/mp2t",
        )
    else:
        return FileResponse(path=file_path)


async def session_cleanup_loop():
    while True:
        await asyncio.sleep(600)  # every 10 minutes
        cutoff = datetime.now(timezone.utc) - timedelta(hours=SESSION_TTL_HOURS)
        cleaned = 0
        for sid, info in list(active_sessions.items()):
            if info["started"] < cutoff:
                proc = info.get("proc")
                if proc and proc.returncode is None:
                    proc.kill()
                session_dir = sessions_dir / sid
                if session_dir.exists():
                    shutil.rmtree(session_dir, ignore_errors=True)
                active_sessions.pop(sid, None)
                cleaned += 1
        # Also nuke orphaned session dirs
        for p in sessions_dir.iterdir():
            if p.is_dir():
                mtime = datetime.fromtimestamp(p.stat().st_mtime, tz=timezone.utc)
                if mtime < cutoff and p.name not in active_sessions:
                    shutil.rmtree(p, ignore_errors=True)
                    cleaned += 1
        if cleaned:
            logger.info("Cleaned up %d old sessions", cleaned)


def main():
    uvicorn.run("vela_proxy.main:app", host=HOST, port=PORT, reload=False)


if __name__ == "__main__":
    main()
