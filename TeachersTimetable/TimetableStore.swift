import Combine
import Foundation
import UserNotifications

private struct ClassNotificationSchedule: Sendable {
    let entry: TimetableEntry
    let slot: PeriodSlot
}

@MainActor
final class TimetableStore: ObservableObject {
    @Published var timetable: [TimetableEntry]
    @Published var settings: TeacherSettings
    @Published private var weeklyOverride: WeeklyTimetableOverride?
    @Published private(set) var notificationAuthorization: UNAuthorizationStatus = .notDetermined
    @Published private(set) var scheduledNotificationCount = 0
    @Published private(set) var notificationFeedbackMessage: String?

    private static let storageKey = "TimetableTeacher.snapshot"
    private static let weeklyOverrideStorageKey = "TimetableTeacher.weeklyOverride"
    private static let maxPendingClassNotifications = 64
    private static let notificationSchedulingFeedbackPrefix = "알림 예약:"
    private let notificationIdentifierKey = "TimetableTeacher.notificationIdentifiers"
    private let testNotificationDelay: TimeInterval = 10
    private var cancellables = Set<AnyCancellable>()
    private var notificationRescheduleGeneration = 0
    private var notificationRescheduleTask: Task<Void, Never>?
    private var suspendSideEffects = false

    init() {
        let snapshot = Self.loadSnapshot() ?? .sample
        self.timetable = snapshot.timetable.sorted(by: Self.sortEntries)
        self.settings = snapshot.settings
        self.weeklyOverride = Self.loadWeeklyOverride()
        expireWeeklyOverrideIfNeeded(referenceDate: Date())
        bindState()
        refreshNotificationAuthorization()
    }

    var availablePeriods: [Int] {
        settings.availablePeriods
    }

    var hasActiveWeeklyOverride: Bool {
        weeklyOverride?.weekIdentifier == Self.weekIdentifier(for: Date())
    }

    func entries(for day: Weekday) -> [TimetableEntry] {
        timetable
            .filter { $0.day == day }
            .sorted(by: Self.sortEntries)
    }

    func entry(for day: Weekday, period: Int) -> TimetableEntry? {
        timetable.first(where: { $0.day == day && $0.period == period })
    }

    func activeTimetable(for date: Date = Date()) -> [TimetableEntry] {
        guard let weeklyOverride, weeklyOverride.weekIdentifier == Self.weekIdentifier(for: date) else {
            return timetable
        }

        return weeklyOverride.timetable.sorted(by: Self.sortEntries)
    }

    func activeEntry(for day: Weekday, period: Int, on date: Date = Date()) -> TimetableEntry? {
        activeTimetable(for: date).first(where: { $0.day == day && $0.period == period })
    }

    func isTemporaryPlacement(for entry: TimetableEntry, on date: Date = Date()) -> Bool {
        guard weeklyOverride?.weekIdentifier == Self.weekIdentifier(for: date) else {
            return false
        }

        guard let baseEntry = timetable.first(where: { $0.id == entry.id }) else {
            return false
        }

        return baseEntry.day != entry.day || baseEntry.period != entry.period
    }

    @discardableResult
    func moveEntryTemporarily(id: UUID, to day: Weekday, period: Int, referenceDate: Date = Date()) -> Bool {
        guard settings.availablePeriods.contains(period) else { return false }

        var nextEntries = activeTimetable(for: referenceDate)
        guard let sourceIndex = nextEntries.firstIndex(where: { $0.id == id }) else { return false }

        let sourceDay = nextEntries[sourceIndex].day
        let sourcePeriod = nextEntries[sourceIndex].period
        guard sourceDay != day || sourcePeriod != period else { return false }

        if let targetIndex = nextEntries.firstIndex(where: { $0.day == day && $0.period == period }) {
            nextEntries[targetIndex].day = sourceDay
            nextEntries[targetIndex].period = sourcePeriod
        }

        nextEntries[sourceIndex].day = day
        nextEntries[sourceIndex].period = period

        weeklyOverride = WeeklyTimetableOverride(
            weekIdentifier: Self.weekIdentifier(for: referenceDate),
            timetable: nextEntries.sorted(by: Self.sortEntries)
        )
        return true
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
        clearWeeklyOverride()

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
        clearWeeklyOverride()
        timetable.removeAll(where: { $0.id == id })
    }

    func clearTimetable() {
        clearWeeklyOverride()
        timetable.removeAll()
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
            let notificationSettings = await center.notificationSettings()
            notificationAuthorization = notificationSettings.authorizationStatus

            guard notificationAuthorization.allowsLocalNotifications else {
                notificationFeedbackMessage = "알림 권한을 먼저 허용해 주세요."
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "수업 알림 테스트"
            content.body = "테스트 알림입니다. iPhone을 잠그면 Apple Watch 미러링도 확인할 수 있습니다."
            content.sound = self.settings.preferredNotificationSound

            let request = UNNotificationRequest(
                identifier: "timetable.ios.test.\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: testNotificationDelay, repeats: false)
            )

            do {
                try await center.add(request)
                let soundWarning = notificationSettings.soundSetting == .disabled
                    ? " 알림 사운드 권한이 꺼져 있어 진동이 울리지 않을 수 있습니다."
                    : ""
                notificationFeedbackMessage = "10초 후 테스트 알림을 보냅니다. 워치 확인은 iPhone 화면을 끄고 기다려 주세요.\(soundWarning)"
            } catch {
                notificationFeedbackMessage = "테스트 알림 예약 실패: \(error.localizedDescription)"
            }
        }
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

        $weeklyOverride
            .dropFirst()
            .sink { [weak self] _ in
                self?.persistWeeklyOverride()
            }
            .store(in: &cancellables)
    }

    private func persist() {
        guard !suspendSideEffects else { return }
        let snapshot = TimetableSnapshot(timetable: timetable, settings: settings)
        saveSnapshot(snapshot)
        rescheduleNotifications()
    }

    private func apply(snapshot: TimetableSnapshot) {
        suspendSideEffects = true
        timetable = snapshot.timetable.sorted(by: Self.sortEntries)
        settings = snapshot.settings
        weeklyOverride = nil
        suspendSideEffects = false
        saveSnapshot(snapshot)
        persistWeeklyOverride()
        rescheduleNotifications()
    }

    private func saveSnapshot(_ snapshot: TimetableSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static func loadSnapshot() -> TimetableSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(TimetableSnapshot.self, from: data)
    }

    private func clearWeeklyOverride() {
        weeklyOverride = nil
    }

    private func expireWeeklyOverrideIfNeeded(referenceDate: Date) {
        guard let weeklyOverride, weeklyOverride.weekIdentifier != Self.weekIdentifier(for: referenceDate) else {
            return
        }

        self.weeklyOverride = nil
        persistWeeklyOverride()
    }

    private func persistWeeklyOverride() {
        guard let weeklyOverride else {
            UserDefaults.standard.removeObject(forKey: Self.weeklyOverrideStorageKey)
            return
        }

        guard let data = try? JSONEncoder().encode(weeklyOverride) else { return }
        UserDefaults.standard.set(data, forKey: Self.weeklyOverrideStorageKey)
    }

    private static func loadWeeklyOverride() -> WeeklyTimetableOverride? {
        guard let data = UserDefaults.standard.data(forKey: weeklyOverrideStorageKey) else { return nil }
        return try? JSONDecoder().decode(WeeklyTimetableOverride.self, from: data)
    }

    private static func weekIdentifier(for date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = components.yearForWeekOfYear ?? calendar.component(.year, from: date)
        let week = components.weekOfYear ?? 0
        return "\(year)-W\(week)"
    }

    private func refreshNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let authorizationStatus = settings.authorizationStatus
            Task { @MainActor [weak self, authorizationStatus] in
                guard let self else { return }
                self.notificationAuthorization = authorizationStatus
                self.rescheduleNotifications()
            }
        }
    }

    private func rescheduleNotifications() {
        notificationRescheduleGeneration += 1
        let generation = notificationRescheduleGeneration
        notificationRescheduleTask?.cancel()

        let center = UNUserNotificationCenter.current()
        let previousIdentifiers = UserDefaults.standard.stringArray(forKey: notificationIdentifierKey) ?? []
        if !previousIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: previousIdentifiers)
        }
        UserDefaults.standard.set([], forKey: notificationIdentifierKey)
        scheduledNotificationCount = 0

        guard settings.alarmEnabled else {
            return
        }

        guard notificationAuthorization.allowsLocalNotifications else {
            return
        }

        let slots = Dictionary(uniqueKeysWithValues: SchedulePlanner.periodSlots(settings: settings).map { ($0.period, $0) })
        let schedules = timetable
            .sorted(by: Self.sortEntries)
            .compactMap { entry -> ClassNotificationSchedule? in
                guard let slot = slots[entry.period] else { return nil }
                return ClassNotificationSchedule(entry: entry, slot: slot)
            }
        let schedulesToAdd = Array(schedules.prefix(Self.maxPendingClassNotifications))
        let skippedCount = max(schedules.count - schedulesToAdd.count, 0)

        guard !schedulesToAdd.isEmpty else {
            return
        }

        let scheduleToken = UUID().uuidString
        let settingsSnapshot = settings
        notificationRescheduleTask = Task { @MainActor [weak self, generation, schedulesToAdd, scheduleToken, settingsSnapshot, skippedCount] in
            guard let self, generation == self.notificationRescheduleGeneration else { return }

            let center = UNUserNotificationCenter.current()
            var successfulIdentifiers: [String] = []
            var failureCount = 0
            var firstErrorDescription: String?

            for schedule in schedulesToAdd {
                guard !Task.isCancelled, generation == self.notificationRescheduleGeneration else { break }

                let requestData = self.notificationRequest(
                    for: schedule,
                    settings: settingsSnapshot,
                    scheduleToken: scheduleToken
                )

                do {
                    try await center.add(requestData.request)
                    successfulIdentifiers.append(requestData.identifier)
                } catch {
                    failureCount += 1
                    firstErrorDescription = firstErrorDescription ?? error.localizedDescription
                }
            }

            guard !Task.isCancelled, generation == self.notificationRescheduleGeneration else {
                center.removePendingNotificationRequests(withIdentifiers: successfulIdentifiers)
                return
            }

            UserDefaults.standard.set(successfulIdentifiers, forKey: self.notificationIdentifierKey)
            self.scheduledNotificationCount = successfulIdentifiers.count
            self.updateNotificationFeedbackAfterScheduling(
                skippedCount: skippedCount,
                failureCount: failureCount,
                firstErrorDescription: firstErrorDescription
            )
            self.refreshPendingNotificationCount()
        }
    }

    private func notificationRequest(
        for schedule: ClassNotificationSchedule,
        settings: TeacherSettings,
        scheduleToken: String
    ) -> (identifier: String, request: UNNotificationRequest) {
        let triggerMinutes = max(schedule.slot.startMinutes - settings.alarmLeadMinutes, 0)
        var components = DateComponents()
        components.weekday = schedule.entry.day.calendarWeekday
        components.hour = triggerMinutes / 60
        components.minute = triggerMinutes % 60

        let content = UNMutableNotificationContent()
        content.title = "\(schedule.entry.periodLabel) \(schedule.entry.subject)"
        content.body = SchedulePlanner.notificationBody(for: schedule.entry, slot: schedule.slot)
        content.sound = settings.preferredNotificationSound

        let identifier = "timetable.ios.\(scheduleToken).\(schedule.entry.id.uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )

        return (identifier, request)
    }

    private func updateNotificationFeedbackAfterScheduling(
        skippedCount: Int,
        failureCount: Int,
        firstErrorDescription: String?
    ) {
        var messages: [String] = []

        if skippedCount > 0 {
            messages.append("iOS 제한으로 수업 알림은 최대 \(Self.maxPendingClassNotifications)개까지만 예약됩니다. \(skippedCount)개는 예약하지 못했습니다.")
        }

        if failureCount > 0 {
            let detail = firstErrorDescription.map { ": \($0)" } ?? ""
            messages.append("수업 알림 \(failureCount)개 예약에 실패했습니다\(detail)")
        }

        if messages.isEmpty {
            if notificationFeedbackMessage?.hasPrefix(Self.notificationSchedulingFeedbackPrefix) == true {
                notificationFeedbackMessage = nil
            }
        } else {
            notificationFeedbackMessage = "\(Self.notificationSchedulingFeedbackPrefix) \(messages.joined(separator: " "))"
        }
    }

    private func refreshPendingNotificationCount() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
            let classNotificationCount = requests.filter {
                $0.identifier.hasPrefix("timetable.ios.") &&
                    !$0.identifier.hasPrefix("timetable.ios.test.")
            }.count

            Task { @MainActor [weak self, classNotificationCount] in
                self?.scheduledNotificationCount = classNotificationCount
            }
        }
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

private enum NotificationSoundResource {
    static let vibrationOnly = UNNotificationSoundName("NotificationHaptic.caf")
}

private extension TeacherSettings {
    var preferredNotificationSound: UNNotificationSound {
        // iOS/watchOS notifications without a sound are silent, including haptics.
        vibrationOnly ? UNNotificationSound(named: NotificationSoundResource.vibrationOnly) : .default
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
