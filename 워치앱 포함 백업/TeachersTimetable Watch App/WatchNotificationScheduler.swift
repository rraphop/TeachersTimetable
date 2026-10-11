import Foundation
@preconcurrency import UserNotifications

private nonisolated final class ScheduledIdentifierCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var identifiers: [String] = []

    func append(_ identifier: String) {
        lock.lock()
        identifiers.append(identifier)
        lock.unlock()
    }

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return identifiers
    }
}

enum WatchNotificationScheduler {
    private static let identifierKey = "TimetableTeacherWatch.notificationIdentifiers"

    static func requestAuthorization(completion: @escaping @Sendable (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else {
                completion(settings.authorizationStatus)
                return
            }

            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
                UNUserNotificationCenter.current().getNotificationSettings { updatedSettings in
                    completion(updatedSettings.authorizationStatus)
                }
            }
        }
    }

    static func reschedule(
        snapshot: TimetableSnapshot,
        authorizationStatus: UNAuthorizationStatus,
        completion: @escaping @Sendable (Int) -> Void = { _ in }
    ) {
        let center = UNUserNotificationCenter.current()
        let previousIdentifiers = UserDefaults.standard.stringArray(forKey: identifierKey) ?? []
        if !previousIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: previousIdentifiers)
        }

        guard snapshot.settings.alarmEnabled else {
            UserDefaults.standard.set([], forKey: identifierKey)
            completion(0)
            return
        }

        let allowedStatuses: Set<UNAuthorizationStatus> = [.authorized, .provisional]
        guard allowedStatuses.contains(authorizationStatus) else {
            UserDefaults.standard.set([], forKey: identifierKey)
            completion(0)
            return
        }

        let slots = Dictionary(
            uniqueKeysWithValues: SchedulePlanner.periodSlots(settings: snapshot.settings).map { ($0.period, $0) }
        )
        let scheduledIdentifiers = ScheduledIdentifierCollector()
        let group = DispatchGroup()

        for entry in snapshot.timetable {
            guard let slot = slots[entry.period] else { continue }

            let triggerMinutes = max(slot.startMinutes - snapshot.settings.alarmLeadMinutes, 0)
            var components = DateComponents()
            components.weekday = entry.day.calendarWeekday
            components.hour = triggerMinutes / 60
            components.minute = triggerMinutes % 60

            let content = UNMutableNotificationContent()
            content.title = "\(entry.periodLabel) \(entry.subject)"
            content.body = SchedulePlanner.notificationBody(for: entry, slot: slot)

            if !snapshot.settings.vibrationOnly {
                content.sound = .default
            }

            let identifier = "timetable.watch.\(entry.id.uuidString)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )

            group.enter()
            center.add(request) { error in
                if error == nil {
                    scheduledIdentifiers.append(identifier)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let identifiers = scheduledIdentifiers.values
            UserDefaults.standard.set(identifiers, forKey: identifierKey)
            completion(identifiers.count)
        }
    }
}
