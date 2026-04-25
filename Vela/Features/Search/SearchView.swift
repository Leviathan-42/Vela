import SwiftUI

@MainActor
@Observable
final class SearchViewModel {
    var query: String = ""
    var results: [MediaItem] = []
    var isLoading = false
    private var currentTask: Task<Void, Never>?

    func search(using tmdb: any TMDbService) {
        currentTask?.cancel()
        let q = query
        currentTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
            guard let self else { return }
            self.isLoading = true
            let found = (try? await tmdb.search(query: q)) ?? []
            if Task.isCancelled { return }
            self.results = found
            self.isLoading = false
        }
    }
}

struct SearchView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var model = SearchViewModel()

    var body: some View {
        Group {
            if model.query.isEmpty {
                ContentUnavailableView(
                    "Search movies and shows",
                    systemImage: "magnifyingglass"
                )
            } else if model.results.isEmpty && !model.isLoading {
                ContentUnavailableView.search(text: model.query)
            } else {
                List(model.results) { item in
                    NavigationLink(value: item) {
                        HStack(spacing: 12) {
                            PosterCard(item: item, width: 50, height: 75)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.headline)
                                Text(item.mediaType == .movie ? "Movie" : "TV Show")
                                    .font(.caption).foregroundStyle(Theme.subtle)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $model.query, prompt: "Search movies and shows")
        .onChange(of: model.query) { _, _ in
            model.search(using: deps.tmdb)
        }
        .navigationTitle("Search")
        .navigationDestination(for: MediaItem.self) { item in
            DetailsView(media: item)
        }
    }
}
