import Foundation

protocol SourceService: Sendable {
    func sources(forMovie imdbId: String) async throws -> [SourceItem]
    func sources(forShow imdbId: String, season: Int, episode: Int) async throws -> [SourceItem]
}

enum SourceError: Error, LocalizedError {
    case badResponse(Int)
    case noSources
    case decoding

    var errorDescription: String? {
        switch self {
        case .badResponse(let code): "Torrentio returned HTTP \(code)"
        case .noSources: "No sources found for this title"
        case .decoding: "Couldn't parse source response"
        }
    }
}

struct TorrentioSourceService: SourceService {
    let baseURL: URL
    let session: URLSession

    init(
        baseURL: URL = URL(string: "https://torrentio.strem.fun")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func sources(forMovie imdbId: String) async throws -> [SourceItem] {
        let url = baseURL.appendingPathComponent("stream/movie/\(imdbId).json")
        return try await fetch(url: url)
    }

    func sources(forShow imdbId: String, season: Int, episode: Int) async throws -> [SourceItem] {
        let url = baseURL.appendingPathComponent("stream/series/\(imdbId):\(season):\(episode).json")
        return try await fetch(url: url)
    }

    private func fetch(url: URL) async throws -> [SourceItem] {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SourceError.badResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded: TorrentioResponse
        do {
            decoded = try JSONDecoder().decode(TorrentioResponse.self, from: data)
        } catch {
            throw SourceError.decoding
        }
        let items = decoded.streams.compactMap { TorrentioParser.parse($0) }
        return items.sorted { $0.rankScore > $1.rankScore }
    }
}

private struct TorrentioResponse: Decodable {
    let streams: [TorrentioStream]
}

private struct TorrentioStream: Decodable {
    let name: String?
    let title: String?
    let infoHash: String?
    let fileIdx: Int?
    let url: String?
}

private enum TorrentioParser {
    static func parse(_ stream: TorrentioStream) -> SourceItem? {
        guard let infoHash = stream.infoHash else { return nil }
        let title = stream.title ?? ""
        let name = stream.name ?? ""
        let haystack = "\(name) \(title)"

        let resolution = extractResolution(from: haystack)
        let size = extractSize(from: title)
        let hdr = extractHDR(from: haystack)
        let codec = extractCodec(from: haystack)

        let cached: SourceItem.CachedStatus = {
            if name.contains("RD+") || title.contains("RD+") {
                return .cached
            }
            return .unknown
        }()

        let displayName = title.components(separatedBy: "\n").first
            ?? name.components(separatedBy: "\n").first
            ?? "Unknown source"

        let magnet = makeMagnet(infoHash: infoHash, displayName: displayName)

        return SourceItem(
            id: "\(infoHash):\(stream.fileIdx ?? 0)",
            displayName: displayName,
            resolution: resolution,
            sizeBytes: size,
            codec: codec,
            hdrType: hdr,
            audio: nil,
            language: nil,
            providerName: "Torrentio",
            cachedStatus: cached,
            sourceLink: magnet,
            fileIndex: stream.fileIdx,
            rankScore: score(resolution: resolution, cached: cached, size: size)
        )
    }

    private static func extractResolution(from s: String) -> SourceItem.Resolution {
        let u = s.uppercased()
        if u.contains("2160P") || u.contains("4K") || u.contains("UHD") { return .uhd2160p }
        if u.contains("1080P") || u.contains("FHD") { return .hd1080p }
        if u.contains("720P") { return .hd720p }
        if u.contains("480P") { return .sd480p }
        return .unknown
    }

    private static func extractSize(from s: String) -> Int64? {
        let pattern = #"(\d+(?:\.\d+)?)\s*(GB|MB)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = s as NSString
        guard let match = regex.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges >= 3,
              let value = Double(ns.substring(with: match.range(at: 1))) else { return nil }
        let unit = ns.substring(with: match.range(at: 2)).uppercased()
        let multiplier: Double = unit == "GB" ? 1_073_741_824 : 1_048_576
        return Int64(value * multiplier)
    }

    private static func extractHDR(from s: String) -> SourceItem.HDRType? {
        let u = s.uppercased()
        if u.contains("DOLBY VISION") || u.contains(" DV ") || u.contains(".DV.") { return .dolbyVision }
        if u.contains("HDR10+") { return .hdr10Plus }
        if u.contains("HDR") { return .hdr10 }
        return nil
    }

    private static func extractCodec(from s: String) -> String? {
        let u = s.uppercased()
        if u.contains("X265") || u.contains("HEVC") || u.contains("H.265") { return "HEVC" }
        if u.contains("X264") || u.contains("H.264") || u.contains("AVC") { return "H.264" }
        if u.contains("AV1") { return "AV1" }
        return nil
    }

    private static func score(resolution: SourceItem.Resolution, cached: SourceItem.CachedStatus, size: Int64?) -> Double {
        var s: Double = 0
        if cached == .cached { s += 10_000 }
        switch resolution {
        case .uhd2160p: s += 400
        case .hd1080p: s += 300
        case .hd720p: s += 200
        case .sd480p: s += 100
        case .unknown: break
        }
        if let size { s += Double(size) / 1_073_741_824 }
        return s
    }

    private static func makeMagnet(infoHash: String, displayName: String) -> String {
        let trackers = [
            "udp://tracker.opentrackr.org:1337/announce",
            "udp://tracker.openbittorrent.com:6969/announce",
            "udp://tracker.torrent.eu.org:451/announce",
            "udp://open.stealth.si:80/announce",
            "udp://tracker.coppersurfer.tk:6969/announce"
        ]
        let encoded = displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let trackerParams = trackers
            .compactMap { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) }
            .map { "tr=\($0)" }
            .joined(separator: "&")
        return "magnet:?xt=urn:btih:\(infoHash)&dn=\(encoded)&\(trackerParams)"
    }
}
