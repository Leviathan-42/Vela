import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(AppDependencies.self) private var deps
    @Query(
        filter: #Predicate<LibraryItem> { $0.inWatchlist == true },
        sort: \LibraryItem.addedAt,
        order: .reverse
    ) private var items: [LibraryItem]

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "Your watchlist is empty",
                    systemImage: "books.vertical",
                    description: Text("Tap the + button on any title to add it here.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                LibraryCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Library")
        .background(Theme.background)
        .navigationDestination(for: LibraryItem.self) { item in
            DetailsView(media: item.asMediaItem())
        }
    }
}

private struct LibraryCard: View {
    let item: LibraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: TMDbImage.posterURL(path: item.posterPath)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(Theme.surface)
                }
            }
            .aspectRatio(2/3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))

            Text(item.title)
                .font(.caption)
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
    }
}

extension LibraryItem {
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
