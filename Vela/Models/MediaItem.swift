import Foundation

enum MediaType: String, Codable, Hashable, Sendable {
    case movie
    case show
}

struct MediaItem: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let tmdbId: Int
    let imdbId: String?
    let title: String
    let originalTitle: String?
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: Date?
    let mediaType: MediaType
    let genres: [String]
    let rating: Double?
    let runtimeMinutes: Int?

    var posterURL: URL? {
        TMDbImage.posterURL(path: posterPath)
    }

    var backdropURL: URL? {
        TMDbImage.backdropURL(path: backdropPath)
    }
}

enum TMDbImage {
    static let baseURL = URL(string: "https://image.tmdb.org/t/p")!

    static func posterURL(path: String?, size: String = "w500") -> URL? {
        guard let path else { return nil }
        return baseURL.appendingPathComponent(size).appendingPathComponent(path)
    }

    static func backdropURL(path: String?, size: String = "w1280") -> URL? {
        guard let path else { return nil }
        return baseURL.appendingPathComponent(size).appendingPathComponent(path)
    }
}
