import SwiftUI
import SwiftData

@MainActor
@Observable
final class DetailsViewModel {
    var details: MediaItem?
    var imdbId: String?
    var seasons: [ShowSeason] = []
    var selectedSeason: Int?
    var episodes: [Episode] = []
    var isLoadingDetails = false
    var isLoadingEpisodes = false
    var errorMessage: String?

    func load(media: MediaItem, tmdb: any TMDbService) async {
        isLoadingDetails = true
        errorMessage = nil
        do {
            switch media.mediaType {
            case .movie:
                let d = try await tmdb.movieDetails(tmdbId: media.tmdbId)
                details = d
                if let direct = d.imdbId {
                    imdbId = direct
                } else {
                    imdbId = try? await tmdb.imdbId(forMovie: media.tmdbId)
                }
            case .show:
                async let d = tmdb.showDetails(tmdbId: media.tmdbId)
                async let s = tmdb.seasons(showTmdbId: media.tmdbId)
                async let ext = tmdb.imdbId(forShow: media.tmdbId)
                details = try await d
                seasons = (try await s).filter { $0.seasonNumber > 0 }
                imdbId = try await ext
                if let first = seasons.first {
                    await selectSeason(first.seasonNumber, showTmdbId: media.tmdbId, tmdb: tmdb)
                }
            }
        } catch {
            errorMessage = "Couldn't load details: \(error.localizedDescription)"
        }
        isLoadingDetails = false
    }

    func selectSeason(_ number: Int, showTmdbId: Int, tmdb: any TMDbService) async {
        selectedSeason = number
        isLoadingEpisodes = true
        episodes = []
        do {
            episodes = try await tmdb.episodes(showTmdbId: showTmdbId, season: number)
        } catch {
            errorMessage = "Couldn't load episodes: \(error.localizedDescription)"
        }
        isLoadingEpisodes = false
    }
}

struct DetailsView: View {
    let media: MediaItem

    @Environment(AppDependencies.self) private var deps
    @Query private var watchlistEntries: [LibraryItem]
    @State private var vm = DetailsViewModel()
    @State private var sourceTarget: SourceTarget?
    @State private var playerContext: PlayerContext?

    init(media: MediaItem) {
        self.media = media
        let id = media.id
        _watchlistEntries = Query(
            filter: #Predicate<LibraryItem> { $0.mediaId == id && $0.inWatchlist == true }
        )
    }

    private var isInWatchlist: Bool { !watchlistEntries.isEmpty }
    private var displayed: MediaItem { vm.details ?? media }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                backdrop
                headerBlock
                actionRow
                if !displayed.overview.isEmpty {
                    Text(displayed.overview)
                        .font(.body)
                        .foregroundStyle(.primary.opacity(0.85))
                        .padding(.horizontal)
                }
                if media.mediaType == .show {
                    showBrowser
                }
            }
            .padding(.bottom, 32)
        }
        #if os(iOS)
        .navigationTitle(displayed.title)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(Theme.background)
        .task {
            try? deps.library.touch(mediaId: media.id)
            if vm.details == nil {
                await vm.load(media: media, tmdb: deps.tmdb)
            }
        }
        .sheet(item: $sourceTarget) { target in
            SourcePickerSheet(target: target) { resolved in
                let season = (target.isEpisode ? target.season : nil)
                let episode = (target.isEpisode ? target.episode : nil)
                let epTitle = vm.episodes.first { $0.episodeNumber == episode }?.title
                playerContext = PlayerContext(
                    streamURL: resolved.url,
                    mediaId: media.id,
                    tmdbId: media.tmdbId,
                    mediaType: media.mediaType,
                    title: displayed.title,
                    posterPath: displayed.posterPath ?? media.posterPath,
                    season: season,
                    episode: episode,
                    episodeTitle: epTitle
                )
            }
        }
        .fullScreenCover(item: $playerContext) { ctx in
            PlayerView(context: ctx)
        }
    }

    // MARK: - Sections

    private var backdrop: some View {
        AsyncImage(url: displayed.backdropURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                Rectangle().fill(Theme.surface)
            }
        }
        .frame(height: Theme.Size.backdropHeight)
        .clipped()
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, Theme.background],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: Theme.Size.backdropHeight * 0.4)
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayed.title).font(.title.bold())
            HStack(spacing: 10) {
                if let year = releaseYear {
                    Text(year)
                }
                if let rating = displayed.rating {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                }
                if let runtime = displayed.runtimeMinutes {
                    Text("\(runtime) min")
                }
            }
            .font(.caption)
            .foregroundStyle(Theme.subtle)
            if !displayed.genres.isEmpty {
                Text(displayed.genres.joined(separator: " • "))
                    .font(.caption)
                    .foregroundStyle(Theme.subtle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                if media.mediaType == .movie {
                    openMovieSources()
                }
            } label: {
                Label(
                    media.mediaType == .movie ? "Play" : "Pick an episode below",
                    systemImage: "play.fill"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(media.mediaType == .show || (media.mediaType == .movie && vm.imdbId == nil))

            Button(action: toggleWatchlist) {
                Image(systemName: isInWatchlist ? "checkmark" : "plus")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .tint(isInWatchlist ? .green : Theme.subtle)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var showBrowser: some View {
        if vm.seasons.count > 1 {
            Picker("Season", selection: Binding(
                get: { vm.selectedSeason ?? vm.seasons.first?.seasonNumber ?? 1 },
                set: { newValue in
                    Task { await vm.selectSeason(newValue, showTmdbId: media.tmdbId, tmdb: deps.tmdb) }
                }
            )) {
                ForEach(vm.seasons) { season in
                    Text(season.title).tag(season.seasonNumber)
                }
            }
            #if os(iOS)
            .pickerStyle(.menu)
            #endif
            .padding(.horizontal)
        }

        if vm.isLoadingEpisodes {
            ProgressView().frame(maxWidth: .infinity).padding()
        } else {
            VStack(spacing: 8) {
                ForEach(vm.episodes) { episode in
                    episodeRow(episode)
                }
            }
            .padding(.horizontal)
        }
    }

    private func episodeRow(_ episode: Episode) -> some View {
        Button {
            openEpisodeSources(episode)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                AsyncImage(url: episode.stillURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(Theme.surface)
                    }
                }
                .frame(width: Theme.Size.episodeStillWidth, height: Theme.Size.episodeStillHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(episode.episodeNumber). \(episode.title)")
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    if !episode.overview.isEmpty {
                        Text(episode.overview)
                            .font(.caption)
                            .foregroundStyle(Theme.subtle)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
            }
            .padding(10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
        }
        .tvFocusCard()
        .disabled(vm.imdbId == nil)
    }

    // MARK: - Helpers

    private var releaseYear: String? {
        guard let d = displayed.releaseDate ?? media.releaseDate else { return nil }
        return String(Calendar.current.component(.year, from: d))
    }

    private func toggleWatchlist() {
        if isInWatchlist {
            try? deps.library.remove(mediaId: media.id)
        } else {
            try? deps.library.add(media)
        }
    }

    private func openMovieSources() {
        guard let imdb = vm.imdbId else { return }
        sourceTarget = .movie(imdbId: imdb)
    }

    private func openEpisodeSources(_ episode: Episode) {
        guard let imdb = vm.imdbId else { return }
        sourceTarget = .episode(showImdbId: imdb, season: episode.seasonNumber, episode: episode.episodeNumber)
    }
}

private extension SourceTarget {
    var isEpisode: Bool {
        if case .episode = self { return true }
        return false
    }
    var season: Int? {
        if case .episode(_, let s, _) = self { return s }
        return nil
    }
    var episode: Int? {
        if case .episode(_, _, let e) = self { return e }
        return nil
    }
}

extension SourceTarget: Identifiable {
    var id: String {
        switch self {
        case .movie(let imdb): "m:\(imdb)"
        case .episode(let imdb, let s, let e): "s:\(imdb):\(s):\(e)"
        }
    }
}
