# Vela Implementation Checklist

Phase-by-phase tracker. ✅ = working. See README.md for setup.

---

## Phase 0: One-time setup ✅

- [x] Xcode 26 on macOS 26 (Tahoe)
- [x] xcodegen installed (`brew install xcodegen`)
- [x] `xcodegen generate` produces a buildable `Vela.xcodeproj`
- [x] Personal Team signing works for simulator + device builds
- [x] `Secrets.swift` template + gitignore confirmed

---

## Phase 1: App foundation ✅

- [x] SwiftUI app shell (`VelaApp.swift`)
- [x] Tab navigation: Home / Search / Library / Settings
- [x] Core models in `Models/`
- [x] Protocol-based service layer in `Services/`
- [x] Theme + `PosterCard` reusable component

---

## Phase 2: TMDb metadata + browsing ✅

- [x] `TMDbServiceLive` implements: trending/popular movies+shows, search, details, seasons, episodes, external_ids
- [x] HomeView fetches all 4 rows in parallel with loading shimmer + pull-to-refresh
- [x] SearchView with 300ms debounce
- [x] DetailsView with backdrop, year/rating/runtime, genres, overview
- [x] Episode list with stills for TV shows + season picker

---

## Phase 3: Local library ✅

- [x] Watchlist toggle button on DetailsView with live state
- [x] LibraryView shows real watchlisted titles in a poster grid
- [x] `lastOpenedAt` touched on every Details view
- [x] SwiftData reactivity via `@Query` keeps state in sync across screens

---

## Phase 4: Source flow (Torrentio) ✅

- [x] Torrentio JSON fetched for movies and episodes
- [x] Parser extracts resolution / size / HDR / codec / cached status
- [x] Sort: cached → resolution → size
- [x] Source picker sheet with quality/cached/HDR/codec badges
- [x] Loading + empty states

---

## Phase 5: Real-Debrid integration ✅

- [x] Device-code OAuth flow (Settings → Connect → user code → poll → tokens)
- [x] Tokens stored in Keychain via `KeychainServiceLive`
- [x] Auto-refresh on near-expiry
- [x] `resolve(sourceLink:)` flow:
  - Add magnet → wait for files → pick largest non-sample video → select → poll for downloaded → unrestrict
- [x] Settings shows account username + premium expiry
- [x] Disconnect button
- [x] `magnetRejected` / `httpError` surfaced to UI on bad sources

---

## Phase 6: Playback ✅

- [x] KSPlayer integration (FFmpeg — handles MKV/AVI/MP4/etc. in-app)
- [x] libshaderc bundle-id patch wired into pre-build script
- [x] Resume from saved position (>2 min, <95% complete)
- [x] Progress save every 5s + on dismiss
- [x] Mark completed at ≥90%
- [x] Continue Watching row on Home with thumbnail, progress bar, episode label

---

## Phase 7: Polish (in progress)

- [x] App icon in `AppIcon.appiconset/`
- [x] Loading states + error banners
- [x] Source picker with full metadata badges
- [ ] Skeleton/shimmer loaders instead of plain spinners
- [ ] Codec/resolution preference filters in Settings
- [ ] Better source row info on long-press (full title, seeders if available)
- [ ] Improved "no sources / RD rejected" UX with retry button
- [ ] Subtitle preference memory in Settings

---

## Distribution ✅

- [x] AltStore sideload path documented in README
- [x] IPA-packaging command (manual `.app` → `Payload` → `.ipa`)
- [x] Personal Team signing confirmed working

---

## Future v2 ideas

- iPad-optimized layouts
- Trakt sync (cross-device watch history)
- Downloads / offline playback
- Source filtering controls (hide uncached, prefer codec, prefer audio language)
- Next episode autoplay
- AirPlay polish
- External subtitle search providers
- Source preference memory ("last picked 1080p H.264 for this show")
