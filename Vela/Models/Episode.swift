import Foundation

struct Episode: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let showId: String
    let showImdbId: String?
    let seasonNumber: Int
    let episodeNumber: Int
    let title: String
    let overview: String
    let stillPath: String?
    let runtimeMinutes: Int?
    let airDate: Date?

    var stillURL: URL? {
        TMDbImage.posterURL(path: stillPath, size: "w500")
    }
}
