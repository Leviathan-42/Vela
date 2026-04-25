import Foundation
import SwiftData

@MainActor
protocol LibraryService {
    func add(_ media: MediaItem) throws
    func remove(mediaId: String) throws
    func isInWatchlist(mediaId: String) throws -> Bool
    func watchlist() throws -> [LibraryItem]
    func touch(mediaId: String) throws
}

@MainActor
struct LibraryServiceLive: LibraryService {
    let context: ModelContext

    func add(_ media: MediaItem) throws {
        let id = media.id
        let fetch = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.mediaId == id })
        if let existing = try context.fetch(fetch).first {
            existing.inWatchlist = true
            existing.addedAt = .now
        } else {
            let item = LibraryItem(
                mediaId: media.id,
                tmdbId: media.tmdbId,
                title: media.title,
                posterPath: media.posterPath,
                mediaType: media.mediaType
            )
            context.insert(item)
        }
        try context.save()
    }

    func remove(mediaId: String) throws {
        let fetch = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.mediaId == mediaId })
        if let item = try context.fetch(fetch).first {
            context.delete(item)
            try context.save()
        }
    }

    func isInWatchlist(mediaId: String) throws -> Bool {
        let fetch = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.mediaId == mediaId })
        return try (context.fetch(fetch).first?.inWatchlist ?? false)
    }

    func watchlist() throws -> [LibraryItem] {
        let fetch = FetchDescriptor<LibraryItem>(
            predicate: #Predicate { $0.inWatchlist == true },
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return try context.fetch(fetch)
    }

    func touch(mediaId: String) throws {
        let fetch = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.mediaId == mediaId })
        if let item = try context.fetch(fetch).first {
            item.lastOpenedAt = .now
            try context.save()
        }
    }
}
