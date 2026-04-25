import Foundation
import SwiftData

@Model
final class LibraryItem {
    @Attribute(.unique) var mediaId: String
    var tmdbId: Int
    var title: String
    var posterPath: String?
    var mediaTypeRaw: String
    var addedAt: Date
    var inWatchlist: Bool
    var lastOpenedAt: Date?

    init(
        mediaId: String,
        tmdbId: Int,
        title: String,
        posterPath: String?,
        mediaType: MediaType,
        addedAt: Date = .now,
        inWatchlist: Bool = true,
        lastOpenedAt: Date? = nil
    ) {
        self.mediaId = mediaId
        self.tmdbId = tmdbId
        self.title = title
        self.posterPath = posterPath
        self.mediaTypeRaw = mediaType.rawValue
        self.addedAt = addedAt
        self.inWatchlist = inWatchlist
        self.lastOpenedAt = lastOpenedAt
    }

    var mediaType: MediaType {
        MediaType(rawValue: mediaTypeRaw) ?? .movie
    }
}
