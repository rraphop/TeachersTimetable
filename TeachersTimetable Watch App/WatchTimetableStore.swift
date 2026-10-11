import Foundation
import Combine
import UserNotifications
import WatchConnectivity

@MainActor
final class WatchTimetableStore: NSObject, ObservableObject {
    @Published private(set) var snapshot: TimetableSnapshot
    @Published private(set) var notificationAuthorization: UNAuthorizationStatus = .notDetermined
    @Published private(set) var scheduledNotificationCount = 0

    private static let storageKey = "TimetableTeacherWatch.snapshot"

    override init() {
        snapshot = Self.loadSnapshot() ?? .sample
        super.init()
        configureConnectivity()
        requestNotificationPermission()
    }

    var timetable: [TimetableEntry] {
        snapshot.timetable
    }

    var settings: TeacherSettings {
        snapshot.settings
    }

    func entries(for day: Weekday) -> [TimetableEntry] {
        timetable
            .filter { $0.day == day }
            .sorted {
                if $0.period == $1.period {
                    return $0.subject < $1.subject
                }
                return $0.period < $1.period
            }
    }

    func refreshFromPhone() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        if session.activationState != .activated {
            session.activate()
            return
        }

        guard session.isReachable else {
            if let snapshot = Self.decodeSnapshot(from: session.receivedApplicationContext) {
                apply(snapshot: snapshot)
            }
            return
        }

        session.sendMessage(["requestSnapshot": true]) { reply in
            guard let data = reply["snapshot"] as? Data else { return }

            Task { @MainActor [weak self, data] in
                guard let snapshot = Self.decodeSnapshot(from: data) else { return }
                self?.apply(snapshot: snapshot)
            }
        } errorHandler: { _ in }
    }

    func requestNotificationPermission() {
        WatchNotificationScheduler.requestAuthorization { status in
            Task { @MainActor [weak self, status] in
                guard let self else { return }
                self.notificationAuthorization = status
                self.rescheduleNotifications(for: self.snapshot)
            }
        }
    }

    func currentEntry(for day: Weekday, at date: Date) -> (entry: TimetableEntry, slot: PeriodSlot)? {
        let minutes = SchedulePlanner.minutesSinceMidnight(date: date)
        let slots = Dictionary(uniqueKeysWithValues: SchedulePlanner.periodSlots(settings: settings).map { ($0.period, $0) })

        return entries(for: day)
            .compactMap { entry -> (TimetableEntry, PeriodSlot)? in
                guard let slot = slots[entry.period] else { return nil }
                return (entry, slot)
            }
            .first { minutes >= $0.1.startMinutes && minutes < $0.1.endMinutes }
    }

    private func configureConnectivity() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()

        if let snapshot = Self.decodeSnapshot(from: session.receivedApplicationContext) {
            apply(snapshot: snapshot)
        }
    }

    private func apply(snapshot: TimetableSnapshot) {
        self.snapshot = snapshot
        saveSnapshot(snapshot)
        rescheduleNotifications(for: snapshot)
    }

    private func saveSnapshot(_ snapshot: TimetableSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static func loadSnapshot() -> TimetableSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(TimetableSnapshot.self, from: data)
    }

    private static func decodeSnapshot(from payload: [String: Any]) -> TimetableSnapshot? {
        guard let data = payload["snapshot"] as? Data else { return nil }
        return decodeSnapshot(from: data)
    }

    private static func decodeSnapshot(from data: Data) -> TimetableSnapshot? {
        return try? JSONDecoder().decode(TimetableSnapshot.self, from: data)
    }

    private func rescheduleNotifications(for snapshot: TimetableSnapshot) {
        WatchNotificationScheduler.reschedule(
            snapshot: snapshot,
            authorizationStatus: notificationAuthorization
        ) { count in
            Task { @MainActor [weak self, count] in
                self?.scheduledNotificationCount = count
            }
        }
    }
}

extension WatchTimetableStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        let snapshotData = session.receivedApplicationContext["snapshot"] as? Data
        Task { @MainActor [weak self, snapshotData] in
            guard let self else { return }
            if let snapshotData, let snapshot = Self.decodeSnapshot(from: snapshotData) {
                self.apply(snapshot: snapshot)
            }
            self.refreshFromPhone()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor [weak self] in
            self?.refreshFromPhone()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let snapshotData = applicationContext["snapshot"] as? Data
        Task { @MainActor [weak self, snapshotData] in
            guard let snapshotData, let snapshot = Self.decodeSnapshot(from: snapshotData) else { return }
            self?.apply(snapshot: snapshot)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let snapshotData = userInfo["snapshot"] as? Data
        Task { @MainActor [weak self, snapshotData] in
            guard let snapshotData, let snapshot = Self.decodeSnapshot(from: snapshotData) else { return }
            self?.apply(snapshot: snapshot)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let snapshotData = message["snapshot"] as? Data
        Task { @MainActor [weak self, snapshotData] in
            guard let snapshotData, let snapshot = Self.decodeSnapshot(from: snapshotData) else { return }
            self?.apply(snapshot: snapshot)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let snapshotData = message["snapshot"] as? Data else {
            replyHandler([:])
            return
        }

        Task { @MainActor [weak self, snapshotData] in
            guard let snapshot = Self.decodeSnapshot(from: snapshotData) else { return }
            self?.apply(snapshot: snapshot)
        }
        replyHandler(["received": true])
    }
}
