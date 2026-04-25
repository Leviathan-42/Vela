import SwiftUI
import SwiftData

@main
struct VelaApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: LibraryItem.self, PlaybackProgress.self, UserSettings.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(AppDependencies(modelContainer: container))
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
