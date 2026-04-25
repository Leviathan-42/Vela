# Vela Implementation Checklist

This is the step-by-step execution plan. Work top to bottom. Each item should be small enough to complete in one session.

---

## Phase 0: One-time setup (do this first)

- [ ] Confirm **Xcode 26** is installed and selected (`xcode-select -p` → should point at Xcode 26)
- [ ] Confirm Mac mini is on **macOS 26 (Tahoe)** — required for Xcode 26
- [ ] Install xcodegen: `brew install xcodegen`
- [ ] From `/Users/levi/Documents/Vela`, run: `xcodegen generate` → creates `Vela.xcodeproj`
- [ ] Open the project: `open Vela.xcodeproj`
- [ ] In Xcode: Signing & Capabilities tab → set your Apple ID as the team (personal team is fine for sideloading)
- [ ] Build for iPhone simulator (⌘R) — should launch empty tab bar
- [ ] Initialize git here if desired: `git init && git add . && git commit -m "initial scaffold"` (Secrets.swift is already gitignored)
- [ ] Confirm your iPhone is on iOS 26 for AltStore sideloading later

---

## Phase 1: App foundation ✅ (scaffolded)

- [x] SwiftUI app shell (`VelaApp.swift`)
- [x] Tab navigation with Home / Search / Library / Settings (`RootView.swift`)
- [x] Core models (`Models/`)
- [x] Service protocols (`Services/`)
- [x] Theme (`UI/Theme/Theme.swift`)

**Remaining in Phase 1:**
- [ ] Reusable components: `PosterCard`, `RowSection`, `BackdropHeader` in `UI/Components/`
- [ ] Loading/error state views
- [ ] Liquid Glass polish pass on nav bars and sheets

---

## Phase 2: TMDb metadata and browsing

- [ ] Implement `TMDbServiceLive.trendingMovies()` — GET `/trending/movie/week`
- [ ] Implement `trendingShows`, `popularMovies`, `popularShows`
- [ ] Implement `search(query:)` using `/search/multi`
- [ ] Implement `movieDetails`, `showDetails`
- [ ] Implement `seasons`, `episodes`
- [ ] Implement `imdbId(forMovie:)` and `imdbId(forShow:)` via `/external_ids` (needed for Torrentio)
- [ ] Build JSON decoding models for TMDb responses (keep separate from domain `MediaItem`)
- [ ] Wire `HomeView` to call trending/popular and display poster rows
- [ ] Wire `SearchView` to call `/search/multi` with debounce
- [ ] Wire `DetailsView` navigation from home rows and search results
- [ ] For shows: season picker + episode list inside `DetailsView`
- [ ] Handle empty/loading/error states uniformly

---

## Phase 3: Local library

- [ ] Add `LibraryService.add/remove` wiring to a watchlist button on `DetailsView`
- [ ] `LibraryView` shows watchlist grouped or sorted nicely
- [ ] `PlaybackProgressService.record` called from player on progress
- [ ] Continue Watching row on `HomeView` driven by `inProgressItems(limit:)`
- [ ] For shows, figure out "next episode to resume" logic (helper on progress service)
- [ ] Touch `lastOpenedAt` when user opens a detail page

---

## Phase 4: Source flow (Torrentio)

- [ ] Implement `TorrentioSourceService.sources(forMovie:)` — GET `https://torrentio.strem.fun/stream/movie/{imdbId}.json`
- [ ] Implement `sources(forShow:season:episode:)` — `/stream/series/{imdbId}:{s}:{e}.json`
- [ ] Build Torrentio response decoder (fields: `name`, `title`, `infoHash`, `fileIdx`, `behaviorHints`)
- [ ] Parser: extract resolution, HDR, size, codec from the `title` field (it's a formatted string with size and flags)
- [ ] Detect cached status: Torrentio prefixes names with `[RD+]` for cached Real-Debrid
- [ ] Sort: cached first → resolution desc → size desc
- [ ] `SourcePickerView` presented as a sheet from `DetailsView` play button
- [ ] Handle "no sources found" state

---

## Phase 5: Real-Debrid integration

- [ ] Implement `beginDeviceCodeFlow()`:
  - GET `https://api.real-debrid.com/oauth/v2/device/code?client_id=X245A4XAIBGVM&new_credentials=yes`
- [ ] Settings UI: show user code + verification URL + a "Copy code" button
- [ ] Implement `pollForToken(deviceCode:interval:)`:
  - Poll `/oauth/v2/device/credentials?client_id=...&code={deviceCode}` until client_id/client_secret returned
  - Then POST `/oauth/v2/token` with grant_type=http://oauth.net/grant_type/device/1.0
- [ ] Store resulting `RDTokens` in Keychain (already wired)
- [ ] Implement `resolve(sourceLink:)`:
  - If magnet: POST `/torrents/addMagnet` → `/torrents/selectFiles` with file index → poll `/torrents/info/{id}` → `/unrestrict/link` on the resulting link
  - Handle "not cached yet" gracefully (show progress or fall back)
- [ ] Implement token refresh on 401
- [ ] Implement `disconnect()` and `accountInfo()`
- [ ] Settings shows account status + username + premium expiry

---

## Phase 6: Playback

- [ ] `PlayerView` receives resolved URL from Real-Debrid and plays
- [ ] Periodic position save (every 5s) through `PlaybackProgressService.record`
- [ ] Save final position on dismiss
- [ ] Mark completed at ≥ 90% of duration
- [ ] Resume from saved position on replay (if > 2 minutes in)
- [ ] Subtitle track selection using `AVPlayer` media selection APIs
- [ ] Picture in Picture toggle (stretch)

---

## Phase 7: Polish

- [ ] Better skeleton / shimmer loading
- [ ] Consistent error alerts with retry
- [ ] Liquid Glass review: ensure sheets, nav, source picker all use the system glass treatment
- [ ] App icon (1024x1024 into `AppIcon.appiconset`)
- [ ] Launch screen
- [ ] Test on physical iPhone via AltStore

---

## Known open questions (decide before Phase 5)

- Do you want to paste a Real-Debrid API key as a fallback (simpler), or only support device-code OAuth? Plan says OAuth — keep that unless you hit friction.
- For uncached torrents: skip them in v1 (cleaner UX) or show with a "download to RD" flow (more complex)?
