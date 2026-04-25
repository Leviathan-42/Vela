# Vela iOS App Plan

## Overview
Vela is a personal, sideloaded iOS streaming app for iPhone, with possible iPad support later. It is designed to provide a clean, fast, Stremio-like experience focused on search, discovery, source selection, playback, and personal library tracking.

This app is intended for personal use via AltStore and development in Xcode on a Mac mini.

## Core Product Goal
Build an iPhone-first app where the user can:
- search movies and TV shows
- browse trending, popular, and discover pages
- open a title detail page
- fetch stream sources through a Torrentio-like provider flow
- use Real-Debrid to resolve playable links
- choose a source and play it in-app
- use subtitles
- track watch progress and continue watching
- save items to a personal library/watchlist

## v1 Scope
### Included in v1
- iPhone app
- SwiftUI app architecture
- Movies and TV shows
- Search
- Browse/discover
- Trending and popular sections
- Title details page
- Source list for movies and episodes
- Real-Debrid login/integration
- Torrentio-like source retrieval flow
- In-app video playback
- Subtitle support
- Continue watching
- Watch progress tracking
- Watchlist/library tracking
- Settings screen
- Local persistence on device
- Dark cinematic UI

### Not included in v1
- Downloads/offline playback
- App Store release
- Adult content support
- Multi-user accounts
- Backend server unless later required
- Chromecast
- tvOS version
- Complex social features

## Platform Targets
### Primary target
- iPhone

### Secondary target
- iPad support can be added after the iPhone experience is stable

### Distribution
- AltStore / sideloading only

## Product Principles
- Fast and simple flow from search to playback
- Minimal taps to start watching
- Dark, media-first UI
- Keep v1 local-first and low-complexity
- Prefer cached Real-Debrid-ready results first
- Avoid unnecessary backend infrastructure unless direct-on-device approach becomes limiting

## User Experience Summary
### Main user flow
1. User opens Vela
2. Home screen shows trending/popular/discover rows
3. User searches for a movie or show
4. User opens a title page
5. User selects a movie or episode
6. App fetches available sources
7. App shows source list with useful labels
8. User taps a source
9. App resolves the selected source via Real-Debrid
10. Video opens in player
11. App saves progress automatically
12. User can resume later from Continue Watching

## Recommended Tech Stack
### iOS app
- Language: Swift
- UI: SwiftUI
- Navigation: NavigationStack
- Playback: AVPlayer / AVKit
- Persistence: SwiftData preferred, with UserDefaults/Keychain where appropriate
- Networking: URLSession
- Image loading: AsyncImage initially, optional third-party caching later

### Credentials and secrets
- Real-Debrid auth tokens stored in iOS Keychain
- Any sensitive session data stored securely

### External services
- TMDb for metadata, posters, and discovery
- Real-Debrid for link resolution and debrid operations
- Torrentio-like provider endpoint/logic for source retrieval
- Optional subtitle provider later if embedded/external subtitle handling needs expansion

## Architecture Recommendation
## High-Level Architecture
Vela should start as a direct-to-service iOS app with no custom backend in v1.

### v1 architecture
- iOS app talks to TMDb for metadata
- iOS app talks to source provider endpoint for stream/source results
- iOS app talks to Real-Debrid for authentication and resolution
- iOS app stores local library, watchlist, and progress

### Why this is the right v1 choice
- simplest setup
- fastest to build
- easiest to test on simulator/device
- no need to maintain a server immediately
- good fit for personal use

### When to add a backend later
A backend should only be added if one or more of these become necessary:
- source scraping needs proxying or normalization
- CORS/rate-limit issues appear
- caching becomes important
- subtitle aggregation gets complicated
- multi-device sync is needed
- direct Real-Debrid integration from device becomes awkward

## Core App Modules
### 1. App Shell
Responsibilities:
- app launch
- tab navigation
- dependency setup
- theme configuration
- auth/session bootstrap

Suggested tabs:
- Home
- Search
- Library
- Settings

### 2. Home / Discover Module
Responsibilities:
- trending movies
- trending shows
- popular movies
- popular shows
- discover categories
- personalized continue watching row

Possible rows:
- Trending Movies
- Trending Shows
- Popular Now
- New Releases
- Top Rated
- Continue Watching
- Watchlist

### 3. Search Module
Responsibilities:
- title search
- result list
- filter by movies/shows
- recent searches

Search result item should show:
- poster
- title
- release year
- media type
- short subtitle or genre line

### 4. Details Module
Responsibilities:
- metadata display
- synopsis
- cast basics
- genres
- runtime
- ratings
- season/episode browser for shows
- add/remove watchlist
- play button / source picker

Movie detail page should include:
- poster/backdrop
- title/year/runtime
- rating
- genres
- overview
- play button
- source picker

TV detail page should include:
- series info
- season picker
- episode list
- watched state
- resume next episode

### 5. Source Module
Responsibilities:
- fetch available sources for a selected movie/episode
- show source quality metadata
- sort results
- pass selected source to resolver

Recommended source row labels:
- resolution (2160p, 1080p, 720p)
- file size
- codec if available
- HDR/DV if available
- language if available
- cached status if available

Recommended sorting in v1:
1. cached first
2. higher quality first
3. better file size balance
4. cleaner labels / better reliability

### 6. Real-Debrid Module
Responsibilities:
- auth/login flow
- token storage
- source resolution
- error handling
- availability checks where possible

Recommended behavior:
- prefer cached results when detectable
- fail gracefully on expired auth
- show clear errors when a stream cannot be resolved

### 7. Playback Module
Responsibilities:
- in-app playback
- subtitle selection
- resume position
- play/pause/seek
- next episode handoff later

v1 player requirements:
- AVPlayer-based playback
- full screen playback
- subtitle selection support
- remember playback position
- mark item watched when threshold reached
- Picture in Picture if straightforward to add

### 8. Library Module
Responsibilities:
- watchlist
- history
- continue watching
- watched items
- in-progress episodes

Stored locally in v1:
- saved titles
- recently watched items
- playback positions
- episode progress
- source preferences if desired later

### 9. Settings Module
Responsibilities:
- Real-Debrid account status
- subtitle preferences
- playback preferences
- source sort preferences later
- debug tools/logs later

## Data Model Recommendation
### Core entities
#### MediaItem
Fields:
- id
- tmdbId
- imdbId optional
- title
- originalTitle optional
- overview
- posterURL
- backdropURL
- releaseDate
- mediaType (movie/show)
- genres
- rating
- runtime optional

#### ShowSeason
Fields:
- seasonNumber
- title
- episodeCount
- posterURL optional

#### Episode
Fields:
- id
- showId
- seasonNumber
- episodeNumber
- title
- overview
- stillURL
- runtime optional
- airDate optional

#### SourceItem
Fields:
- id
- displayName
- resolution
- size
- codec optional
- hdrType optional
- audio optional
- language optional
- providerName
- cachedStatus optional
- magnetOrSourceLink
- rankScore

#### PlaybackProgress
Fields:
- mediaId
- seasonNumber optional
- episodeNumber optional
- positionSeconds
- durationSeconds
- lastPlayedAt
- completed

#### LibraryItem
Fields:
- mediaId
- addedAt
- inWatchlist
- lastOpenedAt

#### UserSettings
Fields:
- subtitleEnabled
- preferredSubtitleLanguage
- autoplayNextEpisode later
- preferredQuality later
- hideUncached later

## Metadata Strategy
### Primary provider
- TMDb

### Why TMDb
- strong movie/show metadata
- poster and backdrop images
- browse/discover support
- easy fit for iOS UI sections

### TMDb use cases in Vela
- home rows
- search
- detail pages
- show seasons and episodes
- posters and backdrops

## Source and Resolution Strategy
### v1 model
Use a provider flow that behaves like this:
- take selected movie/show/episode identifiers
- request source list from a Torrentio-like endpoint/provider
- parse source labels into structured rows
- let user select source
- resolve selected source with Real-Debrid
- play returned stream URL

### v1 assumptions
- cached results should be prioritized where possible
- uncached handling may exist but should not be emphasized in UI
- if a source is not directly playable, show a clear error and allow another selection

### Source list UX goals
- fast to load
- easy to compare quality
- simple labels
- obvious best option near top

## Real-Debrid Integration Plan
### Functional goals
- connect user account
- securely store token
- validate session on launch
- resolve selected source into playable media URL
- handle token expiration cleanly

### UX recommendations
- Settings screen should show account connected/disconnected state
- If auth expires, show a simple reconnect prompt
- Resolution should happen after source tap with a visible loading state

## Subtitle Plan
### v1 subtitle support
- yes

### Recommended v1 approach
Start with the easiest reliable subtitle path:
- support subtitles already provided by the media stream when available
- support external subtitle attachment if a usable source is returned
- provide subtitle on/off and track selection in player UI if available through AVPlayer integration

### Nice v2 subtitle upgrades
- subtitle search providers
- subtitle language preference memory
- auto-load English subtitles
- subtitle styling controls

## Progress Tracking Plan
### v1 behavior
- save playback position periodically
- save playback position when exiting player
- show in-progress items on Home in Continue Watching
- for TV shows, resume the correct next episode or in-progress episode
- mark movie or episode watched after a completion threshold

### Suggested thresholds
- mark watched at ~90%
- resume if progress is greater than a minimal threshold such as 2 minutes

## UI / UX Direction
### Visual style
- dark
- cinematic
- clean typography
- poster/backdrop heavy
- minimal clutter

### Navigation
Tab bar:
- Home
- Search
- Library
- Settings

### Home screen structure
- hero or featured strip optional
- Continue Watching
- Trending Movies
- Trending Shows
- Popular Movies
- Popular Shows
- Watchlist

### Search screen
- search bar at top
- quick result switching between movies and shows
- recent searches
- clean result list/grid

### Detail screen
- large backdrop
- poster + metadata stack
- play button
- add to watchlist button
- overview
- season/episode picker for shows

### Source picker screen/sheet
- simple list
- sort best sources first
- resolution badges
- file size and format info
- cached badge if known

### Player screen
- native playback first
- subtitle support
- minimal overlays
- progress restoration

## Persistence Plan
### Use SwiftData for:
- watchlist
- history
- continue watching
- playback progress
- user preferences if convenient

### Use Keychain for:
- Real-Debrid token
- auth-related secrets

### Use lightweight cache for:
- images
- temporary metadata responses if useful

## Suggested Project Structure
```text
Vela/
  App/
    VelaApp.swift
    AppRouter.swift
    AppDependencies.swift
  Models/
    MediaItem.swift
    Episode.swift
    SourceItem.swift
    PlaybackProgress.swift
    LibraryItem.swift
    UserSettings.swift
  Services/
    TMDbService.swift
    RealDebridService.swift
    SourceService.swift
    PlaybackProgressService.swift
    LibraryService.swift
    KeychainService.swift
  Features/
    Home/
    Search/
    Details/
    Sources/
    Player/
    Library/
    Settings/
  Persistence/
    SwiftDataModels/
    Repositories/
  UI/
    Components/
    Theme/
  Utilities/
    Extensions/
    Formatting/
    Parsing/
```

## Networking Plan
### TMDbService
Responsibilities:
- search
- trending
- popular
- discover
- details
- seasons/episodes

### SourceService
Responsibilities:
- build source queries for movie/show episode
- call provider endpoint
- parse stream/source labels
- normalize structured results

### RealDebridService
Responsibilities:
- auth/session
- link resolution
- availability checks if used
- token refresh/reconnect flow

## Error Handling Plan
### Common error cases
- no internet
- TMDb error
- provider/source list fetch failed
- no sources found
- Real-Debrid token expired
- source could not be resolved
- player cannot open returned stream
- subtitle loading failed

### UX approach
- keep messages simple
- always allow retry
- always allow source reselection
- avoid technical jargon in user-facing alerts

## Recommended Build Order
### Phase 1: App foundation
- create SwiftUI app shell
- set up tab navigation
- define core models
- create theme and reusable UI components

### Phase 2: Metadata and browsing
- integrate TMDb
- build Home screen rows
- build Search screen
- build Detail pages

### Phase 3: Local library
- add watchlist
- add history
- add continue watching data models
- persist data locally

### Phase 4: Source flow
- build source query pipeline
- fetch source list
- parse and display sources
- sort sources

### Phase 5: Real-Debrid integration
- add auth flow
- store token in Keychain
- resolve selected source
- handle auth expiration

### Phase 6: Playback
- AVPlayer integration
- resume playback position
- mark watched logic
- subtitle support

### Phase 7: Polish
- improve loading states
- improve error messages
- refine source badges
- test more movies/shows and edge cases

## MVP Definition
A working MVP is complete when Vela can:
- show trending and popular titles
- search movies and shows
- open a detail page
- fetch source results for a selected title/episode
- resolve a chosen source using Real-Debrid
- play video in-app
- support subtitles
- save progress
- show Continue Watching
- save titles to watchlist

## Future v2 Ideas
- iPad optimized layouts
- downloads/offline support
- advanced subtitle search
- source filtering controls
- preferred quality selection
- hide uncached items toggle
- next episode autoplay
- richer player UI
- Trakt sync
- backend for sync/caching
- AirPlay polish
- anime-focused enhancements

## Technical Risks
### 1. Source parsing inconsistency
Different source labels may be messy or inconsistent.

Mitigation:
- build a normalization/parser layer
- keep UI tolerant of missing fields

### 2. Real-Debrid auth and resolution edge cases
Some links may fail or sessions may expire.

Mitigation:
- robust reconnect flow
- graceful fallback to source list

### 3. AVPlayer compatibility
Some returned streams may not play cleanly.

Mitigation:
- validate URL types
- log failures in debug mode
- consider a more advanced player path later if needed

### 4. No-backend limitations
Direct calls may hit limitations later.

Mitigation:
- keep service layer modular so a backend can be inserted later without major UI rewrites

## Development Notes for Mac Mini / Xcode
### Recommended setup
- create Xcode project named `Vela`
- use SwiftUI app lifecycle
- target iOS 17+ if possible for a simpler modern stack
- organize by Features + Services + Models

### Suggested initial milestones in Xcode
1. Project skeleton and tab bar
2. TMDb integration and poster grids
3. Detail pages for movies/shows
4. Local watchlist/progress storage
5. Source list fetching/parsing
6. Real-Debrid auth and resolution
7. Playback and subtitles

## Suggested Definition of Done for v1
Vela v1 is done when:
- the app is stable on iPhone
- search and discover are reliable
- source selection feels fast enough
- Real-Debrid resolution works consistently enough for personal use
- playback works with subtitle support
- progress and continue watching work automatically
- the app is pleasant enough to use daily

## Final Recommendation
Build Vela as a direct-to-service, iPhone-first SwiftUI app with TMDb metadata, local library tracking, Real-Debrid integration, and a clean source-to-playback pipeline. Keep v1 focused and avoid downloads or backend infrastructure until the core viewing flow works well.

---

If handing this to a coding agent or developer, the next best artifact to create after this file is:
1. a concrete folder scaffold
2. Swift model definitions
3. service protocol interfaces
4. a step-by-step implementation checklist
