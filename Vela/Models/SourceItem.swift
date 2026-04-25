import Foundation

struct SourceItem: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let resolution: Resolution
    let sizeBytes: Int64?
    let codec: String?
    let hdrType: HDRType?
    let audio: String?
    let language: String?
    let providerName: String
    let cachedStatus: CachedStatus
    let sourceLink: String
    let fileIndex: Int?
    let rankScore: Double

    enum Resolution: String, Hashable, Sendable, Comparable {
        case uhd2160p = "4K"
        case hd1080p = "1080p"
        case hd720p = "720p"
        case sd480p = "480p"
        case unknown = "SD"

        private var order: Int {
            switch self {
            case .uhd2160p: 4
            case .hd1080p: 3
            case .hd720p: 2
            case .sd480p: 1
            case .unknown: 0
            }
        }

        static func < (lhs: Resolution, rhs: Resolution) -> Bool {
            lhs.order < rhs.order
        }
    }

    enum HDRType: String, Hashable, Sendable {
        case hdr10 = "HDR"
        case hdr10Plus = "HDR10+"
        case dolbyVision = "DV"
    }

    enum CachedStatus: Hashable, Sendable {
        case cached
        case uncached
        case unknown
    }

    var formattedSize: String? {
        guard let sizeBytes else { return nil }
        return ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}
