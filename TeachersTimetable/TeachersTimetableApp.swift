import SwiftUI
import AudioToolbox
import UserNotifications

@main
struct TeachersTimetableApp: App {
    @StateObject private var store = TimetableStore()

    init() {
        NotificationPresentationDelegate.install()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}

private final class NotificationPresentationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresentationDelegate()

    static func install() {
        UNUserNotificationCenter.current().delegate = shared
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.identifier.hasPrefix("timetable.ios.") {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        completionHandler([.banner, .list, .sound, .badge])
    }
}
