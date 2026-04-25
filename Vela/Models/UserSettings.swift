import Foundation
import SwiftData

@Model
final class UserSettings {
    @Attribute(.unique) var id: String
    var subtitleEnabled: Bool
    var preferredSubtitleLanguage: String
    var autoplayNextEpisode: Bool
    var preferredQualityRaw: String?
    var hideUncached: Bool

    init(
        id: String = "default",
        subtitleEnabled: Bool = true,
        preferredSubtitleLanguage: String = "en",
        autoplayNextEpisode: Bool = false,
        preferredQualityRaw: String? = nil,
        hideUncached: Bool = false
    ) {
        self.id = id
        self.subtitleEnabled = subtitleEnabled
        self.preferredSubtitleLanguage = preferredSubtitleLanguage
        self.autoplayNextEpisode = autoplayNextEpisode
        self.preferredQualityRaw = preferredQualityRaw
        self.hideUncached = hideUncached
    }
}
