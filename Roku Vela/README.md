# Vela for Roku

A BrightScript/SceneGraph rewrite of Vela for Roku devices.

## ⚠️ Critical Limitation: Video Playback

**Roku has no custom video player.** You cannot bundle FFmpeg, VLC, or any alternative decoder. All playback goes through the built-in `Video` node, which only supports Roku-approved codecs and containers.

### What This Means
- **H.264 / AAC in MP4/MOV** → Works
- **HEVC (H.265)** → Works on most modern Rokus
- **MKV container** → **Often fails** — Roku's MKV support is limited and buggy
- **DTS audio** → Usually fails
- **AVI, weird codecs, etc.** → Will not play

Real-Debrid sometimes returns MKV files. On iOS, KSPlayer/FFmpeg handles these perfectly. On Roku, **they may simply not play**. This is a hardware/platform limitation you cannot code around.

## Project Structure

```
Roku Vela/
  manifest              Channel metadata
  source/
    main.brs            Entry point
  components/
    MainScene.xml/brs   Root scene
    Screens/            Home, Search, Details, Player, Settings
    Tasks/              Async HTTP tasks (TMDb, Torrentio, RD)
  images/               Icons and splash screens
  locale/               Translations
```

## Getting Started

1. Create a Roku developer account at https://developer.roku.com
2. Enable developer mode on your Roku: Home ×5, Up, Right, Down, Left, Up
3. Note the IP address shown
4. Zip this folder (make sure `manifest` is at root)
5. Upload via http://`<roku-ip>`:80

## Services (same as iOS)

| Service | Status | Notes |
|---|---|---|
| TMDb metadata | ✅ Ready | Same REST API, BrightScript `roUrlTransfer` |
| Torrentio sources | 🔄 Todo | Same JSON, parse in BrightScript |
| Real-Debrid auth | 🔄 Todo | Device-code flow works, token storage uses Registry (not Keychain) |
| In-app playback | ⚠️ Limited | Native `Video` node only, codec compatibility is the big risk |
| Subtitles | 🔄 Todo | Roku supports embedded + external SRT/VTT |
| Progress tracking | 🔄 Todo | `roRegistry` key-value store |

## Next Steps

1. Replace `YOUR_TMDB_API_KEY` in `components/Tasks/TMDbTask.brs`
2. Add Search screen with `roSearchScreen` or custom keyboard
3. Add Detail screen with season/episode picker
4. Add Torrentio source task
5. Add Real-Debrid OAuth and resolve tasks
6. Wire up `Video` node for playback
7. Add `roRegistry` storage for watchlist/progress
