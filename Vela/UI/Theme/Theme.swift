import SwiftUI

enum Theme {
    static let accent = Color.accentColor
    static let background = Color.black
    static let surface = Color(white: 0.08)
    static let subtle = Color.white.opacity(0.6)

    enum Radius {
        static let card: CGFloat = 14
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let rowGap: CGFloat = 20
        static let cardGap: CGFloat = 12
    }
}
