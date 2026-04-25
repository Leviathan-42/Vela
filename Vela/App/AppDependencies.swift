import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class AppDependencies {
    let tmdb: any TMDbService
    let sources: any SourceService
    let keychain: any KeychainService
    let realDebrid: any RealDebridService
    let library: any LibraryService
    let progress: any PlaybackProgressService

    init(modelContainer: ModelContainer) {
        let context = modelContainer.mainContext
        let keychain = KeychainServiceLive()
        self.tmdb = TMDbServiceLive()
        self.sources = TorrentioSourceService()
        self.keychain = keychain
        self.realDebrid = RealDebridServiceLive(keychain: keychain)
        self.library = LibraryServiceLive(context: context)
        self.progress = PlaybackProgressServiceLive(context: context)
    }
}
