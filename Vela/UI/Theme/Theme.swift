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
        #if os(tvOS)
        static let rowGap: CGFloat = 50
        static let cardGap: CGFloat = 30
        static let edge: CGFloat = 60
        #else
        static let rowGap: CGFloat = 20
        static let cardGap: CGFloat = 12
        static let edge: CGFloat = 16
        #endif
    }

    enum Size {
        #if os(tvOS)
        static let posterWidth: CGFloat = 240
        static let posterHeight: CGFloat = 360
        static let cwWidth: CGFloat = 380
        static let cwHeight: CGFloat = 215
        static let backdropHeight: CGFloat = 540
        static let libraryGridMin: CGFloat = 240
        static let episodeStillWidth: CGFloat = 280
        static let episodeStillHeight: CGFloat = 158
        #else
        static let posterWidth: CGFloat = 120
        static let posterHeight: CGFloat = 180
        static let cwWidth: CGFloat = 160
        static let cwHeight: CGFloat = 90
        static let backdropHeight: CGFloat = 220
        static let libraryGridMin: CGFloat = 110
        static let episodeStillWidth: CGFloat = 120
        static let episodeStillHeight: CGFloat = 68
        #endif
    }
}

extension View {
    /// On tvOS, wraps a NavigationLink/Button with the system "card" style — gives
    /// the focus-engine lift, parallax and scale-up that TV apps expect. On iOS,
    /// stays as `.plain` so existing layouts don't change.
    @ViewBuilder
    func tvFocusCard() -> some View {
        #if os(tvOS)
        self.buttonStyle(.card)
        #else
        self.buttonStyle(.plain)
        #endif
    }
}
