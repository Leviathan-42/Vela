import asyncio
import json
import logging
import shutil
import subprocess
from pathlib import Path
from typing import Optional

from .config import FFMPEG_PATH, FFPROBE_PATH

logger = logging.getLogger(__name__)


class ProbeResult:
    def __init__(self, data: dict):
        self.data = data
        self.streams = data.get("streams", [])
        self.format = data.get("format", {})

    @property
    def video_codec(self) -> Optional[str]:
        for s in self.streams:
            if s.get("codec_type") == "video":
                return s.get("codec_name")
        return None

    @property
    def audio_codec(self) -> Optional[str]:
        for s in self.streams:
            if s.get("codec_type") == "audio":
                return s.get("codec_name")
        return None

    @property
    def has_subtitles(self) -> bool:
        for s in self.streams:
            if s.get("codec_type") == "subtitle":
                return True
        return False

    @property
    def is_roku_safe(self) -> bool:
        """True if Roku can likely direct-play this."""
        vc = self.video_codec
        ac = self.audio_codec
        safe_video = vc in ("h264", "hevc", "h265")
        safe_audio = ac in ("aac", "mp3", "eac3")
        # MP4 container is safest; MKV is questionable on Roku
        return safe_video and safe_audio


async def probe_url(url: str) -> Optional[ProbeResult]:
    """ffprobe a remote URL."""
    if not shutil.which(FFPROBE_PATH):
        logger.error("ffprobe not found in PATH")
        return None

    cmd = [
        FFPROBE_PATH,
        "-v", "quiet",
        "-print_format", "json",
        "-show_streams",
        "-show_format",
        url,
    ]
    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=30)
        if proc.returncode != 0:
            logger.error("ffprobe failed: %s", stderr.decode().strip())
            return None
        data = json.loads(stdout.decode())
        return ProbeResult(data)
    except Exception as e:
        logger.error("ffprobe exception: %s", e)
        return None


async def transcode_to_hls(
    input_url: str,
    output_dir: Path,
    probe: ProbeResult,
) -> asyncio.subprocess.Process:
    """Launch FFmpeg to produce HLS segments for Roku.

    Strategy:
    - Video: copy if H.264/HEVC, otherwise NVENC/Quick Sync transcode
    - Audio: copy if AAC/MP3/EAC3, otherwise transcode to AAC
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    playlist = output_dir / "index.m3u8"
    segment_pattern = str(output_dir / "%03d.ts")

    vc = probe.video_codec
    ac = probe.audio_codec

    # Video strategy
    if vc in ("h264", "hevc", "h265"):
        vcodec = "copy"
    else:
        # NVENC first, fallback to libx264
        vcodec = "h264_nvenc"
        # You can swap to h264_qsv for Intel Quick Sync if NVENC fails

    # Audio strategy
    if ac in ("aac", "mp3", "eac3"):
        acodec = "copy"
    else:
        acodec = "aac"

    cmd = [
        FFMPEG_PATH,
        "-fflags", "+discardcorrupt+fastseek",
        "-i", input_url,
        "-map", "0:v:0",
        "-map", "0:a:0",
        "-c:v", vcodec,
        "-preset", "fast",
        "-c:a", acodec,
        "-b:a", "192k",
        "-f", "hls",
        "-hls_time", "6",
        "-hls_list_size", "0",
        "-hls_segment_filename", segment_pattern,
        str(playlist),
    ]

    logger.info("Starting FFmpeg: %s", " ".join(cmd))

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    return proc
