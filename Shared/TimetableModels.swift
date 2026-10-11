import Foundation

enum Weekday: Int, CaseIterable, Codable, Identifiable, Comparable, Sendable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6

    var id: Int { rawValue }

    var shortTitle: String {
        switch self {
        case .monday: return "월"
        case .tuesday: return "화"
        case .wednesday: return "수"
        case .thursday: return "목"
        case .friday: return "금"
        }
    }

    var fullTitle: String {
        switch self {
        case .monday: return "월요일"
        case .tuesday: return "화요일"
        case .wednesday: return "수요일"
        case .thursday: return "목요일"
        case .friday: return "금요일"
        }
    }

    var calendarWeekday: Int { rawValue }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func from(date: Date, calendar: Calendar = .current) -> Weekday? {
        let weekday = calendar.component(.weekday, from: date)
        return allCases.first(where: { $0.calendarWeekday == weekday })
    }
}

enum TimetableColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case coral
    case amber
    case mint
    case sky
    case indigo
    case rose
    case sage
    case slate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coral: return "코랄"
        case .amber: return "앰버"
        case .mint: return "민트"
        case .sky: return "스카이"
        case .indigo: return "인디고"
        case .rose: return "로즈"
        case .sage: return "세이지"
        case .slate: return "슬레이트"
        }
    }

    var rgb: (Double, Double, Double) {
        switch self {
        case .coral: return (0.95, 0.46, 0.41)
        case .amber: return (0.95, 0.72, 0.25)
        case .mint: return (0.34, 0.76, 0.61)
        case .sky: return (0.35, 0.64, 0.95)
        case .indigo: return (0.41, 0.44, 0.88)
        case .rose: return (0.90, 0.46, 0.63)
        case .sage: return (0.57, 0.70, 0.47)
        case .slate: return (0.42, 0.47, 0.55)
        }
    }
}

enum AppThemeMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case light
    case dark
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "라이트모드"
        case .dark: return "다크모드"
        case .custom: return "커스텀"
        }
    }
}

struct ThemeColorData: Codable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double = 1

    static let defaultCustomBackground = ThemeColorData(red: 0.92, green: 0.95, blue: 0.99, opacity: 1)
    static let defaultCustomText = ThemeColorData(red: 0.14, green: 0.18, blue: 0.26, opacity: 1)
}

struct TimetableEntry: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var day: Weekday
    var period: Int
    var subject: String
    var className: String
    var classroom: String
    var color: TimetableColor

    init(
        id: UUID = UUID(),
        day: Weekday,
        period: Int,
        subject: String,
        className: String = "",
        classroom: String,
        color: TimetableColor
    ) {
        self.id = id
        self.day = day
        self.period = period
        self.subject = subject
        self.className = className
        self.classroom = classroom
        self.color = color
    }

    var periodLabel: String {
        "\(period)교시"
    }

    var classDisplayText: String {
        className.isEmpty ? "학급 미입력" : className
    }

    var classroomDisplayText: String {
        classroom.isEmpty ? "교실 미입력" : classroom
    }

    var locationSummary: String {
        [className, classroom]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

extension TimetableEntry {
    private enum CodingKeys: String, CodingKey {
        case id
        case day
        case period
        case subject
        case className
        case classroom
        case color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        day = try container.decode(Weekday.self, forKey: .day)
        period = try container.decode(Int.self, forKey: .period)
        subject = try container.decode(String.self, forKey: .subject)
        className = try container.decodeIfPresent(String.self, forKey: .className) ?? ""
        classroom = try container.decodeIfPresent(String.self, forKey: .classroom) ?? ""
        color = try container.decodeIfPresent(TimetableColor.self, forKey: .color) ?? .coral
    }
}

struct TeacherSettings: Codable, Hashable, Sendable {
    var classDuration: Int = 40
    var breakDuration: Int = 10
    var firstPeriodStartMinutes: Int = 9 * 60
    var zeroPeriodEnabled: Bool = false
    var zeroPeriodStartMinutes: Int = 8 * 60 + 10
    var highestPeriod: Int = 7
    var lunchStartMinutes: Int = 12 * 60 + 10
    var lunchEndMinutes: Int = 13 * 60
    var afterSchoolEnabled: Bool = false
    var afterSchoolStartMinutes: Int = 18 * 60
    var afterSchoolEndMinutes: Int = 19 * 60
    var alarmEnabled: Bool = false
    var alarmLeadMinutes: Int = 0
    var vibrationOnly: Bool = true
    var themeMode: AppThemeMode = .light
    var customBackgroundColor: ThemeColorData = .defaultCustomBackground
    var customTextColor: ThemeColorData = .defaultCustomText

    static let `default` = TeacherSettings()

    var availablePeriods: [Int] {
        let minimum = zeroPeriodEnabled ? 0 : 1
        guard highestPeriod >= minimum else { return [] }
        return Array(minimum...highestPeriod)
    }
}

extension TeacherSettings {
    private enum CodingKeys: String, CodingKey {
        case classDuration
        case breakDuration
        case firstPeriodStartMinutes
        case zeroPeriodEnabled
        case zeroPeriodStartMinutes
        case highestPeriod
        case lunchStartMinutes
        case lunchEndMinutes
        case afterSchoolEnabled
        case afterSchoolStartMinutes
        case afterSchoolEndMinutes
        case alarmEnabled
        case alarmLeadMinutes
        case vibrationOnly
        case themeMode
        case customBackgroundColor
        case customTextColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        classDuration = try container.decodeIfPresent(Int.self, forKey: .classDuration) ?? 40
        breakDuration = try container.decodeIfPresent(Int.self, forKey: .breakDuration) ?? 10
        firstPeriodStartMinutes = try container.decodeIfPresent(Int.self, forKey: .firstPeriodStartMinutes) ?? 9 * 60
        zeroPeriodEnabled = try container.decodeIfPresent(Bool.self, forKey: .zeroPeriodEnabled) ?? false
        zeroPeriodStartMinutes = try container.decodeIfPresent(Int.self, forKey: .zeroPeriodStartMinutes) ?? (8 * 60 + 10)
        highestPeriod = try container.decodeIfPresent(Int.self, forKey: .highestPeriod) ?? 7
        lunchStartMinutes = try container.decodeIfPresent(Int.self, forKey: .lunchStartMinutes) ?? (12 * 60 + 10)
        lunchEndMinutes = try container.decodeIfPresent(Int.self, forKey: .lunchEndMinutes) ?? (13 * 60)
        afterSchoolEnabled = try container.decodeIfPresent(Bool.self, forKey: .afterSchoolEnabled) ?? false
        afterSchoolStartMinutes = try container.decodeIfPresent(Int.self, forKey: .afterSchoolStartMinutes) ?? (18 * 60)
        afterSchoolEndMinutes = try container.decodeIfPresent(Int.self, forKey: .afterSchoolEndMinutes) ?? (19 * 60)
        alarmEnabled = try container.decodeIfPresent(Bool.self, forKey: .alarmEnabled) ?? false
        alarmLeadMinutes = try container.decodeIfPresent(Int.self, forKey: .alarmLeadMinutes) ?? 0
        vibrationOnly = try container.decodeIfPresent(Bool.self, forKey: .vibrationOnly) ?? true
        themeMode = try container.decodeIfPresent(AppThemeMode.self, forKey: .themeMode) ?? .light
        customBackgroundColor = try container.decodeIfPresent(ThemeColorData.self, forKey: .customBackgroundColor) ?? .defaultCustomBackground
        customTextColor = try container.decodeIfPresent(ThemeColorData.self, forKey: .customTextColor) ?? .defaultCustomText
    }
}

struct TimetableSnapshot: Codable, Hashable, Sendable {
    var timetable: [TimetableEntry]
    var settings: TeacherSettings

    static let sample = TimetableSnapshot(
        timetable: [
            TimetableEntry(day: .monday, period: 1, subject: "국어", className: "2-1", classroom: "본교실", color: .coral),
            TimetableEntry(day: .monday, period: 2, subject: "수학", className: "2-1", classroom: "본교실", color: .amber),
            TimetableEntry(day: .monday, period: 3, subject: "과학", className: "2-1", classroom: "과학실", color: .sky),
            TimetableEntry(day: .monday, period: 5, subject: "창체", className: "2-1", classroom: "시청각실", color: .mint),
            TimetableEntry(day: .tuesday, period: 1, subject: "영어", className: "2-1", classroom: "본교실", color: .indigo),
            TimetableEntry(day: .tuesday, period: 2, subject: "사회", className: "2-1", classroom: "본교실", color: .sage),
            TimetableEntry(day: .tuesday, period: 4, subject: "체육", className: "2-1", classroom: "체육관", color: .rose),
            TimetableEntry(day: .wednesday, period: 1, subject: "국어", className: "2-1", classroom: "본교실", color: .coral),
            TimetableEntry(day: .wednesday, period: 2, subject: "영어", className: "2-1", classroom: "본교실", color: .indigo),
            TimetableEntry(day: .wednesday, period: 5, subject: "미술", className: "2-1", classroom: "미술실", color: .rose),
            TimetableEntry(day: .thursday, period: 3, subject: "수학", className: "2-1", classroom: "본교실", color: .amber),
            TimetableEntry(day: .thursday, period: 4, subject: "실과", className: "2-1", classroom: "실과실", color: .sage),
            TimetableEntry(day: .friday, period: 1, subject: "과학", className: "2-1", classroom: "과학실", color: .sky),
            TimetableEntry(day: .friday, period: 2, subject: "음악", className: "2-1", classroom: "음악실", color: .mint),
            TimetableEntry(day: .friday, period: 6, subject: "학급활동", className: "2-1", classroom: "본교실", color: .slate)
        ],
        settings: .default
    )
}
