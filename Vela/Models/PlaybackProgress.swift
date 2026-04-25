import Foundation
import SwiftData

@Model
final class PlaybackProgress {
    @Attribute(.unique) var id: String
    var mediaId: String
    var tmdbId: Int
    var mediaTypeRaw: String
    var title: String
    var posterPath: String?
    var seasonNumber: Int?
    var episodeNumber: Int?
    var episodeTitle: String?
    var positionSeconds: Double
    var durationSeconds: Double
    var lastPlayedAt: Date
    var completed: Bool

    init(
        id: String,
        mediaId: String,
        tmdbId: Int,
        mediaType: MediaType,
        title: String,
        posterPath: String?,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        episodeTitle: String? = nil,
        positionSeconds: Double,
        durationSeconds: Double,
        lastPlayedAt: Date = .now,
        completed: Bool = false
    ) {
        self.id = id
        self.mediaId = mediaId
        self.tmdbId = tmdbId
        self.mediaTypeRaw = mediaType.rawValue
        self.title = title
        self.posterPath = posterPath
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.episodeTitle = episodeTitle
        self.positionSeconds = positionSeconds
        self.durationSeconds = durationSeconds
        self.lastPlayedAt = lastPlayedAt
        self.completed = completed
    }

    var mediaType: MediaType { MediaType(rawValue: mediaTypeRaw) ?? .movie }

    var fractionComplete: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(1, positionSeconds / durationSeconds)
    }

    static func compositeId(mediaId: String, season: Int?, episode: Int?) -> String {
        if let season, let episode {
            return "\(mediaId):s\(season)e\(episode)"
        }
        return mediaId
    }
}
