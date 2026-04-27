# Vela Proxy Server

Lightweight transcoding proxy that sits between Real-Debrid and Roku (or any client).

## What It Does

1. Receives a direct media URL from the client
2. Probes it with `ffprobe`
3. If already Roku-safe (H.264/HEVC + AAC) → serves direct proxy manifest
4. If not safe → FFmpeg transcodes/remuxes to HLS on-the-fly
5. Client plays the HLS manifest

## Requirements

- Python 3.10+
- FFmpeg + ffprobe installed
- For GPU transcoding: NVIDIA drivers + NVENC, or Intel drivers + QSV

## Install

```bash
cd server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run

```bash
# Development
uvicorn vela_proxy.main:app --host 0.0.0.0 --port 8000

# Or via the wrapper
python -m vela_proxy.main
```

## Environment Variables

| Var | Default | Description |
|---|---|---|
| `HOST` | `0.0.0.0` | Bind address |
| `PORT` | `8000` | Bind port |
| `FFMPEG_PATH` | `ffmpeg` | Path to ffmpeg binary |
| `FFPROBE_PATH` | `ffprobe` | Path to ffprobe binary |
| `SESSION_TTL_HOURS` | `24` | Auto-cleanup old sessions |

## Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Health check |
| POST | `/stream` | Start a stream session |
| GET | `/sessions/{id}/index.m3u8` | HLS manifest |
| GET | `/sessions/{id}/{n}.ts` | HLS segment |

## Systemd Service

```bash
sudo cp vela-proxy.service /etc/systemd/system/
sudo systemctl enable --now vela-proxy
```

## Roku Integration

Point your Roku `Video` node at:
```
http://YOUR_SERVER_IP:8000/sessions/{session_id}/index.m3u8
```

Or use the `/stream` endpoint to create sessions programmatically.
