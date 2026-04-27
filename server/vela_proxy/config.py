import os
from pathlib import Path

BASE_DIR = Path(__file__).parent.parent.resolve()
SESSIONS_DIR = BASE_DIR / "sessions"
SESSIONS_DIR.mkdir(exist_ok=True)

RD_CLIENT_ID = os.getenv("RD_CLIENT_ID", "")
RD_CLIENT_SECRET = os.getenv("RD_CLIENT_SECRET", "")
RD_ACCESS_TOKEN = os.getenv("RD_ACCESS_TOKEN", "")
RD_REFRESH_TOKEN = os.getenv("RD_REFRESH_TOKEN", "")

TMDB_API_KEY = os.getenv("TMDB_API_KEY", "")

# Cleanup sessions older than this many hours
SESSION_TTL_HOURS = int(os.getenv("SESSION_TTL_HOURS", "24"))

# FFmpeg path (uses GPU if available)
FFMPEG_PATH = os.getenv("FFMPEG_PATH", "ffmpeg")
FFPROBE_PATH = os.getenv("FFPROBE_PATH", "ffprobe")

# Bind
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))
