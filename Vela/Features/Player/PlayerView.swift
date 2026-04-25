import SwiftUI
import KSPlayer

struct PlayerContext: Identifiable, Hashable {
    let id = UUID()
    let streamURL: URL
    let mediaId: String
    let tmdbId: Int
    let mediaType: MediaType
    let title: String
    let posterPath: String?
    let season: Int?
    let episode: Int?
    let episodeTitle: String?
}

struct PlayerView: View {
    let context: PlayerContext

    @Environment(AppDependencies.self) private var deps
    @State private var coordinator = KSVideoPlayer.Coordinator()
    private let saveTick = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        KSVideoPlayerView(
            coordinator: coordinator,
            url: context.streamURL,
            options: makeOptions()
        )
        .ignoresSafeArea()
        .background(Color.black)
        .onAppear {
            print("[PlayerView] Stream URL: \(context.streamURL)")
            print("[PlayerView] Path extension: .\(context.streamURL.pathExtension)")
        }
        .onReceive(saveTick) { _ in
            saveProgress()
        }
        .onDisappear {
            saveProgress()
        }
    }

    private func makeOptions() -> KSOptions {
        let options = KSOptions()
        if let p = try? deps.progress.progress(
            mediaId: context.mediaId,
            season: context.season,
            episode: context.episode
        ), p.positionSeconds > 120, p.fractionComplete < 0.95 {
            options.startPlayTime = TimeInterval(p.positionSeconds)
        }
        return options
    }

    @MainActor
    private func saveProgress() {
        let current = Double(coordinator.timemodel.currentTime)
        let total = Double(coordinator.timemodel.totalTime)
        guard total > 0, current >= 0 else { return }
        try? deps.progress.record(
            mediaId: context.mediaId,
            tmdbId: context.tmdbId,
            mediaType: context.mediaType,
            title: context.title,
            posterPath: context.posterPath,
            season: context.season,
            episode: context.episode,
            episodeTitle: context.episodeTitle,
            position: current,
            duration: total
        )
    }
}
