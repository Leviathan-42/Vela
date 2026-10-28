import SwiftUI
import SwiftData
import Observation

@MainActor
@Observable
final class HomeViewModel {
    var trendingMovies: [MediaItem] = []
    var trendingShows: [MediaItem] = []
    var popularMovies: [MediaItem] = []
    var popularShows: [MediaItem] = []
    var isLoading = false
    var errorMessage: String?

    func load(using tmdb: any TMDbService) async {
        isLoading = true
        errorMessage = nil
        do {
            async let tm = tmdb.trendingMovies()
            async let ts = tmdb.trendingShows()
            async let pm = tmdb.popularMovies()
            async let ps = tmdb.popularShows()
            trendingMovies = try await tm
            trendingShows = try await ts
            popularMovies = try await pm
            popularShows = try await ps
        } catch {
            errorMessage = "Couldn't load content: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

struct HomeView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var model = HomeViewModel()
    @Query(
        filter: #Predicate<PlaybackProgress> { $0.completed == false },
        sort: \PlaybackProgress.lastPlayedAt,
        order: .reverse
    ) private var inProgress: [PlaybackProgress]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.rowGap) {
                if let err = model.errorMessage {
                    errorBanner(err)
                }
                if !inProgress.isEmpty {
                    continueWatchingRow
                }
                row(title: "Trending Movies", items: model.trendingMovies)
                row(title: "Trending Shows", items: model.trendingShows)
                row(title: "Popular Movies", items: model.popularMovies)
                row(title: "Popular Shows", items: model.popularShows)
            }
            .padding(.vertical)
        }
        #if os(iOS)
        .navigationTitle("Vela")
        #endif
        .background(Theme.background)
        .navigationDestination(for: MediaItem.self) { item in
            DetailsView(media: item)
        }
        .task {
            if model.trendingMovies.isEmpty {
                await model.load(using: deps.tmdb)
            }
        }
        .refreshable { await model.load(using: deps.tmdb) }
    }

    private var continueWatchingRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.cardGap) {
            Text("Continue Watching").font(.title2.bold()).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.cardGap) {
                    ForEach(inProgress.prefix(10), id: \.id) { item in
                        NavigationLink(value: item.asMediaItem()) {
                            ContinueWatchingCard(item: item)
                        }
                        .tvFocusCard()
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func row(title: String, items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.cardGap) {
            Text(title).font(.title2.bold()).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.cardGap) {
                    if items.isEmpty && model.isLoading {
                        ForEach(0..<6, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .fill(Theme.surface)
                                .frame(width: Theme.Size.posterWidth, height: Theme.Size.posterHeight)
                        }
                    } else {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                PosterCard(item: item)
                            }
                            .tvFocusCard()
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func errorBanner(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
    }
}

private struct ContinueWatchingCard: View {
    let item: PlaybackProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottom) {
                AsyncImage(url: TMDbImage.posterURL(path: item.posterPath)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(Theme.surface)
                    }
                }
                .frame(width: Theme.Size.cwWidth, height: Theme.Size.cwHeight)
                .clipped()

                GeometryReader { geo in
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * item.fractionComplete, height: 3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                .frame(height: 3)
            }
            .frame(width: Theme.Size.cwWidth, height: Theme.Size.cwHeight)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))

            Text(item.title).font(.caption.weight(.semibold)).lineLimit(1)
            if let s = item.seasonNumber, let e = item.episodeNumber {
                Text("S\(s) · E\(e)").font(.caption2).foregroundStyle(Theme.subtle)
            } else {
                Text(timeRemainingText).font(.caption2).foregroundStyle(Theme.subtle)
            }
        }
        .frame(width: Theme.Size.cwWidth)
    }

    private var timeRemainingText: String {
        let remaining = max(0, item.durationSeconds - item.positionSeconds)
        let minutes = Int(remaining / 60)
        return minutes > 0 ? "\(minutes) min left" : "Finishing up"
    }
}

extension PlaybackProgress {
    func asMediaItem() -> MediaItem {
        MediaItem(
            id: mediaId,
            tmdbId: tmdbId,
            imdbId: nil,
            title: title,
            originalTitle: nil,
            overview: "",
            posterPath: posterPath,
            backdropPath: nil,
            releaseDate: nil,
            mediaType: mediaType,
            genres: [],
            rating: nil,
            runtimeMinutes: nil
        )
    }
}
