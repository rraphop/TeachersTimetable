import Combine
import Foundation
import UserNotifications

@MainActor
final class TimetableStore: ObservableObject {
    @Published var timetable: [TimetableEntry]
    @Published var settings: TeacherSettings
    @Published private(set) var notificationAuthorization: UNAuthorizationStatus = .notDetermined
    @Published private(set) var scheduledNotificationCount = 0
    @Published private(set) var notificationFeedbackMessage: String?

    private static let storageKey = "TimetableTeacher.snapshot"
    private let notificationIdentifierKey = "TimetableTeacher.notificationIdentifiers"
    private var cancellables = Set<AnyCancellable>()
    private var suspendSideEffects = false

    init() {
        let snapshot = Self.loadSnapshot() ?? .sample
        self.timetable = snapshot.timetable.sorted(by: Self.sortEntries)
        self.settings = snapshot.settings
        bindState()
        refreshNotificationAuthorization()
        configureWatchSync()
        syncSnapshotToWatch()
    }

    var availablePeriods: [Int] {
        settings.availablePeriods
    }

    func entries(for day: Weekday) -> [TimetableEntry] {
        timetable
            .filter { $0.day == day }
            .sorted(by: Self.sortEntries)
    }

    func entry(for day: Weekday, period: Int) -> TimetableEntry? {
        timetable.first(where: { $0.day == day && $0.period == period })
    }

    func upsertEntry(
        editingID: UUID?,
        day: Weekday,
        period: Int,
        subject: String,
        className: String,
        classroom: String,
        color: TimetableColor
    ) {
        let cleanedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedSubject.isEmpty else { return }

        let cleanedClassName = className.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedRoom = classroom.trimmingCharacters(in: .whitespacesAndNewlines)
        var nextEntries = timetable.filter { !($0.day == day && $0.period == period && $0.id != editingID) }

        if let editingID, let index = nextEntries.firstIndex(where: { $0.id == editingID }) {
            nextEntries[index] = TimetableEntry(
                id: editingID,
                day: day,
                period: period,
                subject: cleanedSubject,
                className: cleanedClassName,
                classroom: cleanedRoom,
                color: color
            )
        } else {
            nextEntries.append(
                TimetableEntry(
                    day: day,
                    period: period,
                    subject: cleanedSubject,
                    className: cleanedClassName,
                    classroom: cleanedRoom,
                    color: color
                )
            )
        }

        timetable = nextEntries.sorted(by: Self.sortEntries)
    }

    func deleteEntry(id: UUID) {
        timetable.removeAll(where: { $0.id == id })
    }

    func resetToSampleData() {
        apply(snapshot: .sample)
    }

    func requestNotificationPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
            let settings = await center.notificationSettings()
            notificationAuthorization = settings.authorizationStatus
            notificationFeedbackMessage = notificationAuthorization.allowsLocalNotifications
                ? "알림 권한이 허용되었습니다."
                : "알림 권한이 꺼져 있습니다."
            rescheduleNotifications()
        }
    }

    func refreshNotificationState() {
        refreshNotificationAuthorization()
        refreshPendingNotificationCount()
    }

    func sendTestNotification() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            notificationAuthorization = settings.authorizationStatus

            guard notificationAuthorization.allowsLocalNotifications else {
                notificationFeedbackMessage = "알림 권한을 먼저 허용해 주세요."
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "수업 알림 테스트"
            content.body = "테스트 알림입니다. 실제 수업 알림도 같은 방식으로 표시됩니다."

            if !self.settings.vibrationOnly {
                content.sound = .default
            }

            let request = UNNotificationRequest(
                identifier: "timetable.ios.test.\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            )

            do {
                try await center.add(request)
                notificationFeedbackMessage = "5초 후 테스트 알림을 보냅니다."
            } catch {
                notificationFeedbackMessage = "테스트 알림 예약 실패: \(error.localizedDescription)"
            }
        }
    }

    func syncTimetableToWatch(completion: @escaping (WatchSyncResult) -> Void) {
        let snapshot = TimetableSnapshot(timetable: timetable, settings: settings)
        WatchConnectivityBridge.shared.send(snapshot: snapshot, completion: completion)
    }

    private func bindState() {
        $timetable
            .dropFirst()
            .sink { [weak self] _ in
                self?.persist()
            }
            .store(in: &cancellables)

        $settings
            .dropFirst()
            .sink { [weak self] _ in
                self?.persist()
            }
            .store(in: &cancellables)
    }

    private func persist() {
        guard !suspendSideEffects else { return }
        let snapshot = TimetableSnapshot(timetable: timetable, settings: settings)
        saveSnapshot(snapshot)
        rescheduleNotifications()
        syncSnapshotToWatch(snapshot)
    }

    private func apply(snapshot: TimetableSnapshot) {
        suspendSideEffects = true
        timetable = snapshot.timetable.sorted(by: Self.sortEntries)
        settings = snapshot.settings
        suspendSideEffects = false
        saveSnapshot(snapshot)
        rescheduleNotifications()
        syncSnapshotToWatch(snapshot)
    }

    private func saveSnapshot(_ snapshot: TimetableSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static func loadSnapshot() -> TimetableSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(TimetableSnapshot.self, from: data)
    }

    private func refreshNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let authorizationStatus = settings.authorizationStatus
            Task { @MainActor [weak self, authorizationStatus] in
                guard let self else { return }
                self.notificationAuthorization = authorizationStatus
                self.rescheduleNotifications()
            }
        }
    }

    private func rescheduleNotifications() {
        let center = UNUserNotificationCenter.current()
        let previousIdentifiers = UserDefaults.standard.stringArray(forKey: notificationIdentifierKey) ?? []
        if !previousIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: previousIdentifiers)
        }

        guard settings.alarmEnabled else {
            UserDefaults.standard.set([], forKey: notificationIdentifierKey)
            scheduledNotificationCount = 0
            return
        }

        guard notificationAuthorization.allowsLocalNotifications else {
            UserDefaults.standard.set([], forKey: notificationIdentifierKey)
            scheduledNotificationCount = 0
            return
        }

        let slots = Dictionary(uniqueKeysWithValues: SchedulePlanner.periodSlots(settings: settings).map { ($0.period, $0) })
        var scheduledIdentifiers: [String] = []

        for entry in timetable {
            guard let slot = slots[entry.period] else { continue }

            let triggerMinutes = max(slot.startMinutes - settings.alarmLeadMinutes, 0)
            var components = DateComponents()
            components.weekday = entry.day.calendarWeekday
            components.hour = triggerMinutes / 60
            components.minute = triggerMinutes % 60

            let content = UNMutableNotificationContent()
            content.title = "\(entry.periodLabel) \(entry.subject)"
            content.body = SchedulePlanner.notificationBody(for: entry, slot: slot)

            if !settings.vibrationOnly {
                content.sound = .default
            }

            let identifier = "timetable.ios.\(entry.id.uuidString)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )

            center.add(request)
            scheduledIdentifiers.append(identifier)
        }

        UserDefaults.standard.set(scheduledIdentifiers, forKey: notificationIdentifierKey)
        scheduledNotificationCount = scheduledIdentifiers.count
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self?.refreshPendingNotificationCount()
        }
    }

    private func refreshPendingNotificationCount() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let classNotificationCount = requests.filter {
                $0.identifier.hasPrefix("timetable.ios.") &&
                    !$0.identifier.hasPrefix("timetable.ios.test.")
            }.count

            Task { @MainActor [weak self, classNotificationCount] in
                self?.scheduledNotificationCount = classNotificationCount
            }
        }
    }

    private func configureWatchSync() {
        WatchConnectivityBridge.shared.configure { [weak self] in
            guard let self else { return .sample }
            return TimetableSnapshot(timetable: self.timetable, settings: self.settings)
        }
    }

    private func syncSnapshotToWatch(_ snapshot: TimetableSnapshot? = nil) {
        let currentSnapshot = snapshot ?? TimetableSnapshot(timetable: timetable, settings: settings)
        WatchConnectivityBridge.shared.send(snapshot: currentSnapshot)
    }

    private static func sortEntries(lhs: TimetableEntry, rhs: TimetableEntry) -> Bool {
        if lhs.day == rhs.day {
            if lhs.period == rhs.period {
                return lhs.subject < rhs.subject
            }
            return lhs.period < rhs.period
        }
        return lhs.day < rhs.day
    }
}

private extension UNAuthorizationStatus {
    var allowsLocalNotifications: Bool {
        switch self {
        case .authorized, .ephemeral, .provisional:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }
}
