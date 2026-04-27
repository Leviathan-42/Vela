# Vela Roku + Proxy — Handoff Document

## Project Overview
Vela is a personal streaming app. The **iOS version is complete** (Phases 1–6 done, Phase 7 polish in progress). The **Roku version + transcoding proxy** is under active development.

---

## iOS App (Complete)
- SwiftUI, iOS 26, SwiftData, Keychain
- TMDb metadata, Torrentio sources, Real-Debrid OAuth, KSPlayer playback
- Sideloaded via AltStore
- See `README.md` and `CHECKLIST.md` for full details

---

## Proxy Server (`server/`)

### Status: Scaffolded, needs testing
- FastAPI Python service running on Ubuntu home lab (`krakaren`, `192.168.7.114`)
- Receives direct media URLs, probes with FFmpeg, returns HLS manifest
- Smart strategy: direct proxy if Roku-safe, remux if audio is bad, transcode if video codec is bad
- Auto-cleanup of old sessions

### Run It
```bash
cd ~/Vela/server
source .venv/bin/activate
uvicorn vela_proxy.main:app --host 0.0.0.0 --port 8000
```

### Test
```bash
curl http://192.168.7.114:8000/health
```

### Files
| File | Purpose |
|---|---|
| `vela_proxy/main.py` | FastAPI app, `/stream` endpoint, HLS serving |
| `vela_proxy/ffmpeg.py` | ffprobe + FFmpeg transcode logic |
| `vela_proxy/rd_client.py` | Real-Debrid API wrapper (not wired into flow yet) |
| `vela_proxy/config.py` | Env vars, paths |
| `vela-proxy.service` | systemd unit template |

### Known Issues / TODO
- [ ] Has not been tested with a real RD direct URL yet
- [ ] `h264_nvenc` is hardcoded for transcode fallback; should detect GPU (NVENC vs QSV vs libx264)
- [ ] Session cleanup works but could leak if FFmpeg crashes
- [ ] No authentication on the proxy (home LAN only — acceptable for now)

---

## Roku App (`Roku Vela/`)

### Status: Compiles, but does not open (blank/purple screen on launch)
The channel sideloads successfully but crashes or hangs before rendering the Home screen.

### What Was Built
| Component | Status | Notes |
|---|---|---|
| `manifest` | ✅ | Basic channel config, icons commented out |
| `source/main.brs` | ✅ | Entry point, creates MainScene |
| `source/utils.brs` | ✅ | Registry helpers, progress, watchlist, RD token storage |
| `MainScene` | ✅ | Tab bar (Home/Search/Library/Settings), screen stack manager |
| `HomeScreen` | ✅ | Trending/Popular/Watchlist/Continue Watching menu + poster grid |
| `SearchScreen` | ✅ | On-screen keyboard + TMDb search results |
| `DetailScreen` | ✅ | Backdrop, metadata, season/episode picker for TV, Play/Sources/Watchlist buttons |
| `SourcePickerScreen` | ✅ | Fetches Torrentio sources, shows quality badges, sorted by rank |
| `PlayerScreen` | ✅ | Video node, resume position, progress save every 10s |
| `LibraryScreen` | ✅ | Watchlist grid |
| `SettingsScreen` | ✅ | RD connect/disconnect, proxy health check |
| `TMDbTask` | ⚠️ | Needs real API key inserted |
| `TorrentioTask` | ✅ | Parses sources, builds magnets, extracts resolution/size/HDR/codec/cached |
| `RDAuthTask` | ⚠️ | Uses default client_id `X245A4XAIBGVM`; may need user's own RD app creds |
| `RDResolveTask` | ✅ | Full flow: add magnet → poll → pick largest video → select → unrestrict |
| `StreamTask` | ✅ | Talks to proxy at `http://192.168.7.114:8000` |

### Current Bug (Blocking)
**Channel installs but shows only a purple/blank backdrop.**
- `LoadingIndicator` (not a real Roku node) was replaced with `BusySpinner`
- Corresponding `.visible = true/false` calls were replaced with `.control = "start"/"stop"`
- **User reports it still does not open after these fixes**

### Suspected Causes to Investigate
1. **XML node type errors** — Other non-existent node types may be in XML files (`ButtonGroup` exists, but verify `Button`, `Rectangle`, `PosterGrid`, `LabelList`, `Keyboard`, `BusySpinner`, `Video` all exist — they do)
2. **BrightScript runtime crash in `init()`** — `MainScene.brs` `showTabScreen("HomeScreen")` may fail if `HomeScreen.brs` crashes during init
3. **Missing `onShow` callback** — Some screens use `sub onShow()` which is NOT automatically called when a component is added to the scene graph via `appendChild`. Only `init()` is guaranteed. `onShow` is for screens in a `Screen` stack or when `visible` changes.
4. **Registry / `roDateTime` issues** — `source/utils.brs` uses `CreateObject("roDateTime")` which should work, but verify
5. **Array method compatibility** — `m.screenStack.clear()`, `.push()`, `.peek()`, `.count()` used in `MainScene.brs`. These require newer Roku OS. If the Roku is old, these may fail.

### How to Debug
Enable Roku debug logging and watch the console:
```bash
# From your laptop
nc YOUR_ROKU_IP 8085
# Or use telnet
telnet YOUR_ROKU_IP 8085
```
This streams BrightScript `print` statements and crash traces. Look for `Syntax error`, `Type mismatch`, or `Member function not found` immediately after launch.

### Environment Setup Required
1. **TMDb API key** must replace `YOUR_TMDB_API_KEY` in `Roku Vela/components/Tasks/TMDbTask.brs`
2. **Proxy IP** is hardcoded to `192.168.7.114:8000` in `Roku Vela/components/Tasks/StreamTask.brs`
3. **Real-Debrid client_id** in `Roku Vela/components/Tasks/RDAuthTask.brs` is a public default; replace with your own from RD dev panel if blocked

---

## Architecture Flow (Target)

```
Roku User
   ↓
Home / Search / Detail (TMDb metadata)
   ↓
SourcePicker → TorrentioTask fetches sources
   ↓
User picks source → RDResolveTask (magnet → RD → direct URL)
   ↓
StreamTask sends direct URL to Proxy Server (192.168.7.114:8000)
   ↓
Proxy probes → FFmpeg remux/transcode → HLS segments
   ↓
Roku Video node plays /sessions/{uuid}/index.m3u8
   ↓
Progress saved to Registry every 10s
```

---

## Next Steps for Resuming
1. **Fix the launch crash** — use `telnet ROKU_IP 8085` to capture the actual error message
2. **Test proxy independently** — `curl -X POST http://192.168.7.114:8000/stream -d '{"url":"DIRECT_RD_URL"}'`
3. **Replace TMDb key** in `TMDbTask.brs`
4. **Verify MainScene screen stack** works after crash is fixed
5. **Add `roAssociativeArray` safe guards** — Roku's `ParseJson` returns `roAssociativeArray`, field access with `.field` works, but check for `invalid` before using
6. **Consider replacing `m.screenStack` array methods** with manual array operations if the Roku OS is old
7. **Add actual images** to `images/` and uncomment manifest icon/splash lines

---

## Repo
https://github.com/Leviathan-42/Vela
Branch: `main`
Last commit: `8293120` — "Fix Roku crash: replace LoadingIndicator with BusySpinner and update control fields"

## Hardware Context
- **Server**: Ubuntu (`krakaren`), Intel 10th gen, GTX 1650 Super, 16GB RAM
- **Roku**: Same WiFi subnet as server + laptop
- **Dev machine**: Linux laptop (used for `git`, `zip`, `curl` sideload)
