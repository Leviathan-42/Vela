import SwiftUI

enum SourceTarget: Hashable {
    case movie(imdbId: String)
    case episode(showImdbId: String, season: Int, episode: Int)
}

struct ResolvedStream: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let displayName: String
}

@MainActor
@Observable
final class SourcePickerModel {
    var items: [SourceItem] = []
    var isLoading = false
    var isResolving = false
    var errorMessage: String?
    var resolved: ResolvedStream?

    func load(target: SourceTarget, using sources: any SourceService) async {
        isLoading = true
        errorMessage = nil
        items = []
        do {
            switch target {
            case .movie(let imdb):
                items = try await sources.sources(forMovie: imdb)
            case .episode(let showImdb, let s, let e):
                items = try await sources.sources(forShow: showImdb, season: s, episode: e)
            }
            if items.isEmpty {
                errorMessage = "No sources found."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func resolve(_ source: SourceItem, using rd: any RealDebridService) async {
        isResolving = true
        errorMessage = nil
        do {
            let url = try await rd.resolve(sourceLink: source.sourceLink, fileIndex: source.fileIndex)
            resolved = ResolvedStream(url: url, displayName: source.displayName)
        } catch {
            errorMessage = error.localizedDescription
        }
        isResolving = false
    }
}

struct SourcePickerSheet: View {
    let target: SourceTarget
    let onPlay: (ResolvedStream) -> Void

    @Environment(AppDependencies.self) private var deps
    @Environment(\.dismiss) private var dismiss
    @State private var model = SourcePickerModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Finding sources…")
                            .foregroundStyle(Theme.subtle)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.errorMessage, model.items.isEmpty {
                    ContentUnavailableView(
                        "No sources",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    List(model.items) { source in
                        Button { select(source) } label: {
                            SourceRow(source: source)
                        }
                        .disabled(model.isResolving)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Choose source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if model.isResolving {
                    ZStack {
                        Color.black.opacity(0.5).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Resolving on Real-Debrid…")
                                .foregroundStyle(.white)
                        }
                        .padding()
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .alert(
                "Error",
                isPresented: .constant(model.errorMessage != nil && !model.items.isEmpty),
                presenting: model.errorMessage
            ) { _ in
                Button("OK") { model.errorMessage = nil }
            } message: { msg in
                Text(msg)
            }
            .task {
                await model.load(target: target, using: deps.sources)
            }
            .onChange(of: model.resolved) { _, newValue in
                if let resolved = newValue {
                    onPlay(resolved)
                    dismiss()
                }
            }
        }
    }

    private func select(_ source: SourceItem) {
        Task {
            guard await deps.realDebrid.isAuthenticated() else {
                model.errorMessage = "Connect Real-Debrid in Settings first."
                return
            }
            await model.resolve(source, using: deps.realDebrid)
        }
    }
}

private struct SourceRow: View {
    let source: SourceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                badge(source.resolution.rawValue, color: resolutionColor)
                if source.cachedStatus == .cached {
                    badge("CACHED", color: .green)
                }
                if let hdr = source.hdrType {
                    badge(hdr.rawValue, color: .orange)
                }
                if let codec = source.codec {
                    badge(codec, color: Theme.subtle.opacity(0.8))
                }
                Spacer()
                if let size = source.formattedSize {
                    Text(size).font(.caption).foregroundStyle(Theme.subtle)
                }
            }
            Text(source.displayName)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    private var resolutionColor: Color {
        switch source.resolution {
        case .uhd2160p: .purple
        case .hd1080p: .blue
        case .hd720p: .cyan
        case .sd480p, .unknown: .gray
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }
}
