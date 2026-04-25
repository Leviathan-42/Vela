import Foundation

protocol TMDbService: Sendable {
    func trendingMovies() async throws -> [MediaItem]
    func trendingShows() async throws -> [MediaItem]
    func popularMovies() async throws -> [MediaItem]
    func popularShows() async throws -> [MediaItem]
    func search(query: String) async throws -> [MediaItem]
    func movieDetails(tmdbId: Int) async throws -> MediaItem
    func showDetails(tmdbId: Int) async throws -> MediaItem
    func seasons(showTmdbId: Int) async throws -> [ShowSeason]
    func episodes(showTmdbId: Int, season: Int) async throws -> [Episode]
    func imdbId(forMovie tmdbId: Int) async throws -> String?
    func imdbId(forShow tmdbId: Int) async throws -> String?
}

enum TMDbError: Error {
    case badResponse(Int)
    case decoding(Error)
    case invalidURL
}

struct TMDbServiceLive: TMDbService {
    let apiKey: String
    let session: URLSession
    let baseURL = URL(string: "https://api.themoviedb.org/3")!

    init(apiKey: String = Secrets.tmdbAPIKey, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Browse

    func trendingMovies() async throws -> [MediaItem] {
        let page: TMDbList<TMDbMovie> = try await get("/trending/movie/week")
        return page.results.map { $0.asMediaItem() }
    }

    func trendingShows() async throws -> [MediaItem] {
        let page: TMDbList<TMDbShow> = try await get("/trending/tv/week")
        return page.results.map { $0.asMediaItem() }
    }

    func popularMovies() async throws -> [MediaItem] {
        let page: TMDbList<TMDbMovie> = try await get("/movie/popular")
        return page.results.map { $0.asMediaItem() }
    }

    func popularShows() async throws -> [MediaItem] {
        let page: TMDbList<TMDbShow> = try await get("/tv/popular")
        return page.results.map { $0.asMediaItem() }
    }

    func search(query: String) async throws -> [MediaItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let page: TMDbList<TMDbMulti> = try await get(
            "/search/multi",
            query: [URLQueryItem(name: "query", value: trimmed)]
        )
        return page.results.compactMap { $0.asMediaItem() }
    }

    // MARK: - Details

    func movieDetails(tmdbId: Int) async throws -> MediaItem {
        let m: TMDbMovieDetails = try await get("/movie/\(tmdbId)")
        return m.asMediaItem()
    }

    func showDetails(tmdbId: Int) async throws -> MediaItem {
        let s: TMDbShowDetails = try await get("/tv/\(tmdbId)")
        return s.asMediaItem()
    }

    func seasons(showTmdbId: Int) async throws -> [ShowSeason] {
        let s: TMDbShowDetails = try await get("/tv/\(showTmdbId)")
        return s.seasons?.map {
            ShowSeason(
                seasonNumber: $0.season_number,
                title: $0.name ?? "Season \($0.season_number)",
                episodeCount: $0.episode_count ?? 0,
                posterPath: $0.poster_path
            )
        } ?? []
    }

    func episodes(showTmdbId: Int, season: Int) async throws -> [Episode] {
        let s: TMDbSeasonDetails = try await get("/tv/\(showTmdbId)/season/\(season)")
        return s.episodes.map {
            Episode(
                id: "\(showTmdbId):s\(season)e\($0.episode_number)",
                showId: "tmdb:tv:\(showTmdbId)",
                showImdbId: nil,
                seasonNumber: season,
                episodeNumber: $0.episode_number,
                title: $0.name ?? "Episode \($0.episode_number)",
                overview: $0.overview ?? "",
                stillPath: $0.still_path,
                runtimeMinutes: $0.runtime,
                airDate: TMDbDate.parse($0.air_date)
            )
        }
    }

    func imdbId(forMovie tmdbId: Int) async throws -> String? {
        let ext: TMDbExternalIds = try await get("/movie/\(tmdbId)/external_ids")
        return ext.imdb_id
    }

    func imdbId(forShow tmdbId: Int) async throws -> String? {
        let ext: TMDbExternalIds = try await get("/tv/\(tmdbId)/external_ids")
        return ext.imdb_id
    }

    // MARK: - Transport

    private func get<T: Decodable>(
        _ path: String,
        query: [URLQueryItem] = []
    ) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        var items = query
        items.append(URLQueryItem(name: "api_key", value: apiKey))
        items.append(URLQueryItem(name: "language", value: "en-US"))
        components.queryItems = items
        guard let url = components.url else { throw TMDbError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw TMDbError.badResponse(code)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw TMDbError.decoding(error)
        }
    }
}

// MARK: - Internal TMDb DTOs

private struct TMDbList<T: Decodable>: Decodable {
    let results: [T]
}

private struct TMDbMovie: Decodable {
    let id: Int
    let title: String
    let original_title: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let release_date: String?
    let vote_average: Double?
    let genre_ids: [Int]?

    func asMediaItem() -> MediaItem {
        MediaItem(
            id: "tmdb:movie:\(id)",
            tmdbId: id,
            imdbId: nil,
            title: title,
            originalTitle: original_title,
            overview: overview ?? "",
            posterPath: poster_path,
            backdropPath: backdrop_path,
            releaseDate: TMDbDate.parse(release_date),
            mediaType: .movie,
            genres: [],
            rating: vote_average,
            runtimeMinutes: nil
        )
    }
}

private struct TMDbShow: Decodable {
    let id: Int
    let name: String
    let original_name: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let first_air_date: String?
    let vote_average: Double?

    func asMediaItem() -> MediaItem {
        MediaItem(
            id: "tmdb:tv:\(id)",
            tmdbId: id,
            imdbId: nil,
            title: name,
            originalTitle: original_name,
            overview: overview ?? "",
            posterPath: poster_path,
            backdropPath: backdrop_path,
            releaseDate: TMDbDate.parse(first_air_date),
            mediaType: .show,
            genres: [],
            rating: vote_average,
            runtimeMinutes: nil
        )
    }
}

private struct TMDbMulti: Decodable {
    let id: Int
    let media_type: String?
    let title: String?
    let name: String?
    let original_title: String?
    let original_name: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let release_date: String?
    let first_air_date: String?
    let vote_average: Double?

    func asMediaItem() -> MediaItem? {
        switch media_type {
        case "movie":
            return MediaItem(
                id: "tmdb:movie:\(id)",
                tmdbId: id,
                imdbId: nil,
                title: title ?? "",
                originalTitle: original_title,
                overview: overview ?? "",
                posterPath: poster_path,
                backdropPath: backdrop_path,
                releaseDate: TMDbDate.parse(release_date),
                mediaType: .movie,
                genres: [],
                rating: vote_average,
                runtimeMinutes: nil
            )
        case "tv":
            return MediaItem(
                id: "tmdb:tv:\(id)",
                tmdbId: id,
                imdbId: nil,
                title: name ?? "",
                originalTitle: original_name,
                overview: overview ?? "",
                posterPath: poster_path,
                backdropPath: backdrop_path,
                releaseDate: TMDbDate.parse(first_air_date),
                mediaType: .show,
                genres: [],
                rating: vote_average,
                runtimeMinutes: nil
            )
        default:
            return nil // skip persons, collections
        }
    }
}

private struct TMDbMovieDetails: Decodable {
    let id: Int
    let title: String
    let original_title: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let release_date: String?
    let vote_average: Double?
    let runtime: Int?
    let imdb_id: String?
    let genres: [TMDbGenre]?

    func asMediaItem() -> MediaItem {
        MediaItem(
            id: "tmdb:movie:\(id)",
            tmdbId: id,
            imdbId: imdb_id,
            title: title,
            originalTitle: original_title,
            overview: overview ?? "",
            posterPath: poster_path,
            backdropPath: backdrop_path,
            releaseDate: TMDbDate.parse(release_date),
            mediaType: .movie,
            genres: genres?.map(\.name) ?? [],
            rating: vote_average,
            runtimeMinutes: runtime
        )
    }
}

private struct TMDbShowDetails: Decodable {
    let id: Int
    let name: String
    let original_name: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let first_air_date: String?
    let vote_average: Double?
    let genres: [TMDbGenre]?
    let seasons: [TMDbSeason]?

    func asMediaItem() -> MediaItem {
        MediaItem(
            id: "tmdb:tv:\(id)",
            tmdbId: id,
            imdbId: nil,
            title: name,
            originalTitle: original_name,
            overview: overview ?? "",
            posterPath: poster_path,
            backdropPath: backdrop_path,
            releaseDate: TMDbDate.parse(first_air_date),
            mediaType: .show,
            genres: genres?.map(\.name) ?? [],
            rating: vote_average,
            runtimeMinutes: nil
        )
    }
}

private struct TMDbSeason: Decodable {
    let season_number: Int
    let name: String?
    let episode_count: Int?
    let poster_path: String?
}

private struct TMDbSeasonDetails: Decodable {
    let episodes: [TMDbEpisode]
}

private struct TMDbEpisode: Decodable {
    let episode_number: Int
    let name: String?
    let overview: String?
    let still_path: String?
    let runtime: Int?
    let air_date: String?
}

private struct TMDbGenre: Decodable {
    let id: Int
    let name: String
}

private struct TMDbExternalIds: Decodable {
    let imdb_id: String?
}

private enum TMDbDate {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    static func parse(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        return formatter.date(from: s)
    }
}
