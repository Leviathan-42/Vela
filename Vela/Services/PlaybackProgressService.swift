import Foundation
import SwiftData

@MainActor
protocol PlaybackProgressService {
    func record(
        mediaId: String,
        tmdbId: Int,
        mediaType: MediaType,
        title: String,
        posterPath: String?,
        season: Int?,
        episode: Int?,
        episodeTitle: String?,
        position: Double,
        duration: Double
    ) throws
    func progress(mediaId: String, season: Int?, episode: Int?) throws -> PlaybackProgress?
    func inProgressItems(limit: Int) throws -> [PlaybackProgress]
    func markCompleted(mediaId: String, season: Int?, episode: Int?) throws
}

@MainActor
struct PlaybackProgressServiceLive: PlaybackProgressService {
    let context: ModelContext
    let completionThreshold: Double = 0.9

    func record(
        mediaId: String,
        tmdbId: Int,
        mediaType: MediaType,
        title: String,
        posterPath: String?,
        season: Int?,
        episode: Int?,
        episodeTitle: String?,
        position: Double,
        duration: Double
    ) throws {
        let id = PlaybackProgress.compositeId(mediaId: mediaId, season: season, episode: episode)
        let fetch = FetchDescriptor<PlaybackProgress>(predicate: #Predicate { $0.id == id })
        let existing = try context.fetch(fetch).first

        if let existing {
            existing.positionSeconds = position
            existing.durationSeconds = duration
            existing.lastPlayedAt = .now
            existing.title = title
            existing.posterPath = posterPath
            existing.episodeTitle = episodeTitle
            if duration > 0, position / duration >= completionThreshold {
                existing.completed = true
            }
        } else {
            let progress = PlaybackProgress(
                id: id,
                mediaId: mediaId,
                tmdbId: tmdbId,
                mediaType: mediaType,
                title: title,
                posterPath: posterPath,
                seasonNumber: season,
                episodeNumber: episode,
                episodeTitle: episodeTitle,
                positionSeconds: position,
                durationSeconds: duration
            )
            context.insert(progress)
        }
        try context.save()
    }

    func progress(mediaId: String, season: Int?, episode: Int?) throws -> PlaybackProgress? {
        let id = PlaybackProgress.compositeId(mediaId: mediaId, season: season, episode: episode)
        let fetch = FetchDescriptor<PlaybackProgress>(predicate: #Predicate { $0.id == id })
        return try context.fetch(fetch).first
    }

    func inProgressItems(limit: Int) throws -> [PlaybackProgress] {
        var fetch = FetchDescriptor<PlaybackProgress>(
            predicate: #Predicate { $0.completed == false },
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        fetch.fetchLimit = limit
        return try context.fetch(fetch)
    }

    func markCompleted(mediaId: String, season: Int?, episode: Int?) throws {
        if let p = try progress(mediaId: mediaId, season: season, episode: episode) {
            p.completed = true
            try context.save()
        }
    }
}
