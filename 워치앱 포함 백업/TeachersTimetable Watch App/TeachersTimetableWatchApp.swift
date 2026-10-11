import SwiftUI

@main
struct TeachersTimetableWatchApp: App {
    @StateObject private var store = WatchTimetableStore()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(store)
        }
    }
}
