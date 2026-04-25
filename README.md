# Vela

Personal iOS streaming app. iPhone-first SwiftUI, iOS 26 with Liquid Glass styling. Sideloaded via AltStore.

Pulls metadata from TMDb, fetches torrent sources from Torrentio, resolves them through Real-Debrid, and plays them in-app via KSPlayer (FFmpeg under the hood, so MKV/AVI/etc. all work).

---

## Stack

| Piece | Choice |
|---|---|
| Language / UI | Swift, SwiftUI |
| Persistence | SwiftData (library, progress, settings) + Keychain (RD tokens) |
| Metadata | TMDb v3 API |
| Sources | Torrentio public addon (`torrentio.strem.fun`) |
| Debrid | Real-Debrid (device-code OAuth) |
| Playback | KSPlayer (FFmpeg-based, in-app) |
| Project gen | xcodegen (`project.yml` is the source of truth) |
| Distribution | AltStore sideloading |

Bundle ID: `dev.probable.levi.vela` · Deployment target: iOS 26

---

## First-time setup

You need: macOS 26 (Tahoe), Xcode 26, [xcodegen](https://github.com/yonaskolb/XcodeGen), and a TMDb v3 API key.

```bash
# 1. Clone
git clone https://github.com/Leviathan-42/Vela.git
cd Vela

# 2. Install xcodegen (one-time per machine)
brew install xcodegen

# 3. Add your TMDb key
cp Vela/Secrets.example.swift Vela/Secrets.swift
# Edit Vela/Secrets.swift and paste your key from https://www.themoviedb.org/settings/api

# 4. Generate the Xcode project
xcodegen generate

# 5. Open in Xcode
open Vela.xcodeproj
```

In Xcode:
- Project → Vela target → **Signing & Capabilities** → set **Team** to your Apple ID (Personal Team is fine for AltStore)
- Wait for **Resolving Package Graph…** to finish (downloads KSPlayer + FFmpeg, ~100MB, takes 1–3 min)
- ⌘R to run in the simulator

---

## Connecting Real-Debrid

You need an active **RD premium subscription** for source resolution to work.

1. Run the app
2. **Settings** tab → **Connect Real-Debrid**
3. A user code appears with a tappable link to `real-debrid.com/device`
4. Tap the link → log in if needed → enter the code → Allow
5. Settings flips to show your username and premium expiry

Tokens are stored in iOS Keychain. Auto-refresh is wired.

---

## Installing on a real iPhone via AltStore

Apple's "Distribute App" / Archive flow needs a paid dev account. Personal Team works for AltStore through this manual path:

1. In Xcode, change destination to **Any iOS Device (arm64)**
2. **⌘B** (Build, *not* Archive)
3. Run this in Terminal:
   ```bash
   APP=$(find ~/Library/Developer/Xcode/DerivedData/Vela-*/Build/Products/Debug-iphoneos -name "Vela.app" -type d 2>/dev/null | head -1)
   if [ -z "$APP" ]; then
     echo "No device build found — build for 'Any iOS Device' first"
   else
     WORK=$(mktemp -d) && mkdir -p "$WORK/Payload" && cp -R "$APP" "$WORK/Payload/"
     (cd "$WORK" && zip -qry ~/Desktop/Vela.ipa Payload)
     echo "Created: ~/Desktop/Vela.ipa"
   fi
   ```
4. AirDrop `Vela.ipa` to your iPhone → "Open with AltStore"
5. AltStore signs and installs (re-signs every 7 days; keep AltServer running on the same Wi-Fi for auto-refresh)

---

## Updating the app

Pretty much:

```bash
# pull latest
git pull

# regenerate project if project.yml changed
xcodegen generate

# build, repackage, reinstall
# (steps 2-5 from "Installing" above)
```

If KSPlayer ever re-downloads and the build complains about `libshaderc_combined` having an underscore in its bundle ID, the pre-build script in `project.yml` should handle it automatically. If it doesn't, the script in `project.yml` can be run by hand.

---

## Project layout

```
Vela/
  App/                  app shell, dependencies, root tab view
  Models/               domain models (MediaItem, Episode, SourceItem, etc.)
                        + SwiftData @Models (LibraryItem, PlaybackProgress, UserSettings)
  Services/             protocol-based service layer
                        - TMDbService, SourceService (Torrentio), RealDebridService,
                          KeychainService, LibraryService, PlaybackProgressService
  Features/             one folder per feature (Home, Search, Details, Sources,
                        Player, Library, Settings)
  UI/                   reusable components and theme
  Resources/            asset catalog (icon, accent color)
  Secrets.swift         gitignored — your TMDb key
  Secrets.example.swift template
```

`project.yml` defines the Xcode project (xcodegen). `CHECKLIST.md` tracks implementation phases.

---

## Roadmap

- [x] Phase 1 — App shell, models, service protocols
- [x] Phase 2 — TMDb metadata + browse + search
- [x] Phase 3 — Local library + watchlist
- [x] Phase 4 — Torrentio source flow + picker
- [x] Phase 5 — Real-Debrid OAuth + magnet resolve
- [x] Phase 6 — In-app playback with progress save & resume + Continue Watching
- [ ] Phase 7 — Polish (skeleton loaders, source filtering, error UX, app icon refinement)

Future ideas: iPad layouts, Trakt sync, downloads, AirPlay polish, subtitle search.

---

Personal use only.
