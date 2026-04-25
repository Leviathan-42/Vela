import Foundation

struct ShowSeason: Identifiable, Hashable, Sendable, Codable {
    var id: Int { seasonNumber }
    let seasonNumber: Int
    let title: String
    let episodeCount: Int
    let posterPath: String?

    var posterURL: URL? {
        TMDbImage.posterURL(path: posterPath)
    }
}
