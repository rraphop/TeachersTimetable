import Foundation
import SwiftUI

extension TimetableColor {
    var swiftUIColor: Color {
        let values = rgb
        return Color(red: values.0, green: values.1, blue: values.2)
    }

    var tintGradient: LinearGradient {
        LinearGradient(
            colors: [
                swiftUIColor.opacity(0.95),
                swiftUIColor.opacity(0.72)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct PeriodSlot: Identifiable, Hashable, Sendable {
    let period: Int
    let startMinutes: Int
    let endMinutes: Int

    var id: Int { period }
    var label: String { "\(period)교시" }
}

struct DayBand: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case period(Int)
        case lunch
        case afterSchool
    }

    let title: String
    let subtitle: String
    let startMinutes: Int
    let endMinutes: Int
    let kind: Kind

    var id: String {
        "\(title)-\(startMinutes)-\(endMinutes)"
    }
}

struct CurrentPeriodState: Hashable, Sendable {
    var headline: String
    var detail: String
    var currentPeriodLabel: String
    var nextLine: String?
}

enum SchedulePlanner {
    static func periodSlots(settings: TeacherSettings) -> [PeriodSlot] {
        var slots: [PeriodSlot] = []
        let lunchStart = settings.lunchStartMinutes
        let lunchEnd = settings.lunchEndMinutes

        if settings.zeroPeriodEnabled {
            let zeroStart = settings.zeroPeriodStartMinutes
            slots.append(
                PeriodSlot(
                    period: 0,
                    startMinutes: zeroStart,
                    endMinutes: zeroStart + settings.classDuration
                )
            )
        }

        var cursor = settings.firstPeriodStartMinutes
        for period in 1...max(settings.highestPeriod, 1) {
            cursor = startAvoidingLunchOverlap(
                from: cursor,
                duration: settings.classDuration,
                lunchStart: lunchStart,
                lunchEnd: lunchEnd
            )

            let end = cursor + settings.classDuration
            slots.append(
                PeriodSlot(
                    period: period,
                    startMinutes: cursor,
                    endMinutes: end
                )
            )

            cursor = end + settings.breakDuration
        }

        return slots.filter { settings.availablePeriods.contains($0.period) }
    }

    static func dailyBands(for day: Weekday, entries: [TimetableEntry], settings: TeacherSettings) -> [DayBand] {
        let entryMap = Dictionary(uniqueKeysWithValues: entries.filter { $0.day == day }.map { ($0.period, $0) })
        var bands = periodSlots(settings: settings).map { slot in
            let entry = entryMap[slot.period]
            return DayBand(
                title: entry?.periodLabel ?? slot.label,
                subtitle: entry.map {
                    [$0.subject, $0.locationSummary]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")
                } ?? "등록된 수업 없음",
                startMinutes: slot.startMinutes,
                endMinutes: slot.endMinutes,
                kind: .period(slot.period)
            )
        }

        if settings.lunchEndMinutes > settings.lunchStartMinutes {
            bands.append(
                DayBand(
                    title: "점심시간",
                    subtitle: "",
                    startMinutes: settings.lunchStartMinutes,
                    endMinutes: settings.lunchEndMinutes,
                    kind: .lunch
                )
            )
        }

        if
            settings.afterSchoolEnabled,
            let afterSchoolSchedule = settings.afterSchoolSchedule(for: day),
            afterSchoolSchedule.isValid {
            bands.append(
                DayBand(
                    title: "방과후",
                    subtitle: "방과후 수업 가능 시간",
                    startMinutes: afterSchoolSchedule.startMinutes,
                    endMinutes: afterSchoolSchedule.endMinutes,
                    kind: .afterSchool
                )
            )
        }

        return bands.sorted { lhs, rhs in
            if lhs.startMinutes == rhs.startMinutes {
                return lhs.endMinutes < rhs.endMinutes
            }
            return lhs.startMinutes < rhs.startMinutes
        }
    }

    static func status(
        for day: Weekday,
        at date: Date,
        entries: [TimetableEntry],
        settings: TeacherSettings,
        calendar: Calendar = .current
    ) -> CurrentPeriodState {
        let minutes = minutesSinceMidnight(date: date, calendar: calendar)
        let dayEntries = entries.filter { $0.day == day }
        let slotMap = Dictionary(uniqueKeysWithValues: periodSlots(settings: settings).map { ($0.period, $0) })
        let scheduledEntries = dayEntries
            .compactMap { entry in
                slotMap[entry.period].map { (entry, $0) }
            }
            .sorted { $0.1.startMinutes < $1.1.startMinutes }

        if isDuringLunch(minutes: minutes, settings: settings) {
            let nextEntry = scheduledEntries.first(where: { $0.1.startMinutes >= settings.lunchEndMinutes })
            return CurrentPeriodState(
                headline: "점심시간",
                detail: timeRangeText(start: settings.lunchStartMinutes, end: settings.lunchEndMinutes),
                currentPeriodLabel: "점심",
                nextLine: nextEntry.map {
                    "다음: \($0.0.periodLabel) \($0.0.subject) \(timeRangeText(start: $0.1.startMinutes, end: $0.1.endMinutes))"
                }
            )
        }

        if let active = scheduledEntries.first(where: { minutes >= $0.1.startMinutes && minutes < $0.1.endMinutes }) {
            let nextEntry = scheduledEntries.first(where: { $0.1.startMinutes >= active.1.endMinutes })
            return CurrentPeriodState(
                headline: active.0.subject,
                detail: detailText(for: active.0, slot: active.1),
                currentPeriodLabel: active.0.periodLabel,
                nextLine: nextEntry.map {
                    "다음: \($0.0.periodLabel) \($0.0.subject) \(timeRangeText(start: $0.1.startMinutes, end: $0.1.endMinutes))"
                }
            )
        }

        if
            settings.afterSchoolEnabled,
            let afterSchoolSchedule = settings.afterSchoolSchedule(for: day),
            afterSchoolSchedule.isValid,
            minutes >= afterSchoolSchedule.startMinutes,
            minutes < afterSchoolSchedule.endMinutes {
            return CurrentPeriodState(
                headline: "방과후 시간",
                detail: timeRangeText(start: afterSchoolSchedule.startMinutes, end: afterSchoolSchedule.endMinutes),
                currentPeriodLabel: "방과후",
                nextLine: nil
            )
        }

        if let nextEntry = scheduledEntries.first(where: { $0.1.startMinutes > minutes }) {
            return CurrentPeriodState(
                headline: "다음 수업 대기",
                detail: [
                    "\(nextEntry.0.periodLabel) \(nextEntry.0.subject)",
                    nextEntry.0.locationSummary
                ]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · "),
                currentPeriodLabel: "공강",
                nextLine: "시작: \(timeRangeText(start: nextEntry.1.startMinutes, end: nextEntry.1.endMinutes))"
            )
        }

        return CurrentPeriodState(
            headline: "오늘 수업 종료",
            detail: "남은 수업이 없습니다.",
            currentPeriodLabel: "종료",
            nextLine: nil
        )
    }

    static func timeRangeText(start: Int, end: Int) -> String {
        "\(clockText(minutes: start)) - \(clockText(minutes: end))"
    }

    static func clockText(minutes: Int) -> String {
        let hour = max(minutes, 0) / 60
        let minute = max(minutes, 0) % 60
        return String(format: "%02d:%02d", hour, minute)
    }

    static func minutesSinceMidnight(date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static func notificationBody(for entry: TimetableEntry, slot: PeriodSlot) -> String {
        [
            entry.className.isEmpty ? nil : "학급 \(entry.className)",
            entry.classroom.isEmpty ? nil : "교실 \(entry.classroom)",
            timeRangeText(start: slot.startMinutes, end: slot.endMinutes)
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private static func detailText(for entry: TimetableEntry, slot: PeriodSlot) -> String {
        [
            entry.locationSummary,
            timeRangeText(start: slot.startMinutes, end: slot.endMinutes)
        ]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private static func startAvoidingLunchOverlap(
        from startMinutes: Int,
        duration: Int,
        lunchStart: Int,
        lunchEnd: Int
    ) -> Int {
        guard lunchEnd > lunchStart else { return startMinutes }

        let endMinutes = startMinutes + duration
        if startMinutes < lunchEnd && endMinutes > lunchStart {
            return lunchEnd
        }

        return startMinutes
    }

    private static func isDuringLunch(minutes: Int, settings: TeacherSettings) -> Bool {
        settings.lunchEndMinutes > settings.lunchStartMinutes &&
            minutes >= settings.lunchStartMinutes &&
            minutes < settings.lunchEndMinutes
    }
}
