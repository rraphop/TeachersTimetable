import SwiftUI
import UniformTypeIdentifiers

private enum TimetableGridRow: Hashable {
    case period(PeriodSlot)
    case lunch
}

private struct TimetableEntryDragPayload: Codable, Transferable {
    let entryID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .timetableEntryDragPayload)
    }
}

private struct TimetableDropTarget: Hashable {
    let day: Weekday
    let period: Int
}

private extension UTType {
    static let timetableEntryDragPayload = UTType(exportedAs: "com.chail.TeachersTimetable.timetable-entry")
}

private struct AnalogClockTile: View {
    @Environment(\.colorScheme) private var colorScheme

    let theme: AppThemePalette

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var cardFill: Color {
        isDarkMode ? Color(red: 0.095, green: 0.098, blue: 0.102) : Color(red: 0.982, green: 0.982, blue: 0.972)
    }

    private var borderColor: Color {
        isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.10)
    }

    private var hourMarkerColor: Color {
        isDarkMode ? Color.white.opacity(0.50) : Color.black.opacity(0.58)
    }

    private var handColor: Color {
        isDarkMode ? Color(red: 0.76, green: 0.77, blue: 0.78) : Color(red: 0.13, green: 0.13, blue: 0.13)
    }

    private var hubColor: Color {
        isDarkMode ? Color(red: 0.69, green: 0.70, blue: 0.71) : Color(red: 0.22, green: 0.22, blue: 0.22)
    }

    private var hubHighlightColor: Color {
        isDarkMode ? Color(red: 0.86, green: 0.87, blue: 0.88) : Color(red: 0.36, green: 0.36, blue: 0.36)
    }

    private var hubLowlightColor: Color {
        isDarkMode ? Color(red: 0.42, green: 0.43, blue: 0.44) : Color(red: 0.09, green: 0.09, blue: 0.09)
    }

    private var hubInnerColor: Color {
        isDarkMode ? Color(red: 0.18, green: 0.19, blue: 0.20) : Color(red: 0.72, green: 0.72, blue: 0.70)
    }

    private var handHighlightColor: Color {
        isDarkMode ? Color.white.opacity(0.84) : Color.white.opacity(0.26)
    }

    private var handLowlightColor: Color {
        isDarkMode ? Color.black.opacity(0.32) : Color.black.opacity(0.36)
    }

    private var secondHandColor: Color {
        Color(red: 1.0, green: 0.32, blue: 0.08)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            AnalogClockFace(
                date: context.date,
                cardFill: cardFill,
                borderColor: borderColor,
                markerColor: hourMarkerColor,
                handColor: handColor,
                handHighlightColor: handHighlightColor,
                handLowlightColor: handLowlightColor,
                secondHandColor: secondHandColor,
                hubColor: hubColor,
                hubHighlightColor: hubHighlightColor,
                hubLowlightColor: hubLowlightColor,
                hubInnerColor: hubInnerColor,
                edgeHighlightColor: isDarkMode ? Color.white.opacity(0.09) : Color.white.opacity(0.88),
                lowerEdgeColor: isDarkMode ? Color.black.opacity(0.62) : Color.black.opacity(0.13),
                shadowColor: isDarkMode ? Color.black.opacity(0.50) : Color.black.opacity(0.18)
            )
            .aspectRatio(1, contentMode: .fit)
            .accessibilityLabel("아날로그 시계")
            .accessibilityValue(accessibilityTimeText(for: context.date))
        }
    }

    private func accessibilityTimeText(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return "\(components.hour ?? 0)시 \(components.minute ?? 0)분 \(components.second ?? 0)초"
    }
}

private struct AnalogClockFace: View {
    let date: Date
    let cardFill: Color
    let borderColor: Color
    let markerColor: Color
    let handColor: Color
    let handHighlightColor: Color
    let handLowlightColor: Color
    let secondHandColor: Color
    let hubColor: Color
    let hubHighlightColor: Color
    let hubLowlightColor: Color
    let hubInnerColor: Color
    let edgeHighlightColor: Color
    let lowerEdgeColor: Color
    let shadowColor: Color

    private var angles: (hour: Double, minute: Double, second: Double) {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double((components.hour ?? 0) % 12)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)

        return (
            hour: ((hour + (minute / 60) + (second / 3600)) * 30),
            minute: ((minute + (second / 60)) * 6),
            second: second * 6
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let cornerRadius = size * 0.255
            let handShadow = Color.black.opacity(size > 80 ? 0.30 : 0.18)

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(cardFill)
                    .shadow(color: shadowColor, radius: size * 0.105, x: 0, y: size * 0.052)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: max(size * 0.010, 0.9))

                RoundedRectangle(cornerRadius: cornerRadius * 0.92, style: .continuous)
                    .stroke(edgeHighlightColor, lineWidth: max(size * 0.006, 0.5))
                    .padding(size * 0.020)

                RoundedRectangle(cornerRadius: cornerRadius * 0.96, style: .continuous)
                    .stroke(lowerEdgeColor, lineWidth: max(size * 0.006, 0.5))
                    .padding(.top, size * 0.012)
                    .padding(.horizontal, size * 0.016)
                    .padding(.bottom, size * 0.008)
                    .opacity(0.72)

                ForEach(AnalogClockMarkerSpec.all) { marker in
                    let markerOffset = CGSize(width: marker.x * size, height: marker.y * size)

                    AnalogClockMarker(
                        angle: marker.angle,
                        offset: markerOffset,
                        length: size * (marker.isQuarter ? 0.092 : 0.067),
                        width: max(size * (marker.isQuarter ? 0.008 : 0.005), 0.5),
                        color: markerColor.opacity(marker.isQuarter ? 0.96 : 0.66)
                    )
                }

                AnalogClockHand(
                    angle: angles.hour,
                    length: size * 0.330,
                    width: max(size * 0.043, 3.0),
                    color: handColor,
                    highlightColor: handHighlightColor,
                    lowlightColor: handLowlightColor,
                    shadowColor: handShadow
                )
                AnalogClockHand(
                    angle: angles.minute,
                    length: size * 0.438,
                    width: max(size * 0.036, 2.7),
                    color: handColor.opacity(0.96),
                    highlightColor: handHighlightColor,
                    lowlightColor: handLowlightColor,
                    shadowColor: handShadow
                )
                AnalogClockSecondHand(angle: angles.second, length: size * 0.405, width: max(size * 0.0065, 0.55), color: secondHandColor)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                hubHighlightColor,
                                hubColor,
                                hubLowlightColor
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: size * 0.052
                        )
                    )
                    .frame(width: size * 0.086, height: size * 0.086)
                    .shadow(color: Color.black.opacity(0.20), radius: size * 0.012, x: 0, y: size * 0.008)

                Circle()
                    .fill(hubInnerColor)
                    .frame(width: size * 0.030, height: size * 0.030)
                    .overlay(
                        Circle()
                            .stroke(handLowlightColor.opacity(0.40), lineWidth: max(size * 0.004, 0.4))
                    )
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}

private struct AnalogClockMarkerSpec: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let angle: Double

    var isQuarter: Bool {
        id % 3 == 0
    }

    static let all: [AnalogClockMarkerSpec] = [
        AnalogClockMarkerSpec(id: 0, x: 0.000, y: -0.392, angle: 0),
        AnalogClockMarkerSpec(id: 1, x: 0.205, y: -0.360, angle: 30),
        AnalogClockMarkerSpec(id: 2, x: 0.360, y: -0.220, angle: 60),
        AnalogClockMarkerSpec(id: 3, x: 0.392, y: 0.000, angle: 90),
        AnalogClockMarkerSpec(id: 4, x: 0.360, y: 0.220, angle: 120),
        AnalogClockMarkerSpec(id: 5, x: 0.205, y: 0.360, angle: 150),
        AnalogClockMarkerSpec(id: 6, x: 0.000, y: 0.392, angle: 180),
        AnalogClockMarkerSpec(id: 7, x: -0.205, y: 0.360, angle: 210),
        AnalogClockMarkerSpec(id: 8, x: -0.360, y: 0.220, angle: 240),
        AnalogClockMarkerSpec(id: 9, x: -0.392, y: 0.000, angle: 270),
        AnalogClockMarkerSpec(id: 10, x: -0.360, y: -0.220, angle: 300),
        AnalogClockMarkerSpec(id: 11, x: -0.205, y: -0.360, angle: 330)
    ]
}

private struct AnalogClockMarker: View {
    let angle: Double
    let offset: CGSize
    let length: CGFloat
    let width: CGFloat
    let color: Color

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length)
            .rotationEffect(.degrees(angle))
            .offset(offset)
    }
}

private struct AnalogClockHand: View {
    let angle: Double
    let length: CGFloat
    let width: CGFloat
    let color: Color
    let highlightColor: Color
    let lowlightColor: Color
    let shadowColor: Color

    var body: some View {
        ZStack {
            AnalogClockHandShape()
                .fill(
                    LinearGradient(
                        colors: [
                            lowlightColor.opacity(0.72),
                            color,
                            highlightColor.opacity(0.78)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            AnalogClockHandRidgeShape()
                .fill(highlightColor.opacity(0.50))
        }
        .frame(width: width, height: length)
        .offset(y: -(length / 2))
        .rotationEffect(.degrees(angle))
        .shadow(color: shadowColor, radius: 1.4, x: 0, y: 1)
    }
}

private struct AnalogClockSecondHand: View {
    let angle: Double
    let length: CGFloat
    let width: CGFloat
    let color: Color

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -(length / 2))
            .rotationEffect(.degrees(angle))
    }
}

private struct AnalogClockHandShape: Shape {
    func path(in rect: CGRect) -> Path {
        let centerX = rect.midX
        let tipShoulder = rect.height * 0.085
        let shoulderY = rect.height * 0.865
        let lowerControlY = rect.height * 0.990
        let tipInset = rect.width * 0.40

        var path = Path()
        path.move(to: CGPoint(x: centerX, y: 0))
        path.addLine(to: CGPoint(x: centerX + tipInset, y: tipShoulder))
        path.addLine(to: CGPoint(x: rect.maxX, y: shoulderY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: shoulderY),
            control: CGPoint(x: centerX, y: lowerControlY)
        )
        path.addLine(to: CGPoint(x: centerX - tipInset, y: tipShoulder))
        path.closeSubpath()
        return path
    }
}

private struct AnalogClockHandRidgeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let centerX = rect.midX
        var ridge = Path()
        ridge.move(to: CGPoint(x: centerX + rect.width * 0.11, y: rect.height * 0.125))
        ridge.addLine(to: CGPoint(x: centerX + rect.width * 0.28, y: rect.height * 0.850))

        return ridge.strokedPath(
            StrokeStyle(
                lineWidth: max(rect.width * 0.16, 0.45),
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
}

struct OverviewTabView: View {
    @EnvironmentObject private var store: TimetableStore
    @State private var targetedCell: TimetableDropTarget?

    private let rowHeight: CGFloat = 80
    private let lunchRowHeight: CGFloat = 58
    private let spacing: CGFloat = 6
    private let basePeriodColumnWidth: CGFloat = 52
    private let baseDayColumnWidth: CGFloat = 52

    private var theme: AppThemePalette {
        store.settings.appTheme
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 18) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    currentStatusCard(for: context.date)
                }

                TimelineView(.periodic(from: .now, by: 60)) { context in
                    todayScheduleSection(for: context.date)
                }

                TimelineView(.periodic(from: .now, by: 60)) { context in
                    weeklyGridSection(for: context.date)
                }
            }
            .padding(16)
        }
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("수업 알리미")
    }

    private func currentStatusCard(for date: Date) -> some View {
        AppCard {
            if let day = Weekday.from(date: date) {
                let entries = store.activeTimetable(for: date)
                let status = SchedulePlanner.status(
                    for: day,
                    at: date,
                    entries: entries,
                    settings: store.settings
                )

                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(schoolDateTitle(for: date))
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text(status.currentPeriodLabel)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(status.headline)
                            .font(.headline)
                        Text(status.detail)
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    AnalogClockTile(theme: theme)
                        .frame(width: 104, height: 104)
                }

                if let nextLine = status.nextLine {
                    Divider()
                    Text(nextLine)
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryText)
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(schoolDateTitle(for: date))
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text("오늘은 수업이 없는 날")
                            .font(.headline)
                        Text("주말에는 다음 평일 시간표를 그대로 빠르게 확인할 수 있습니다.")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    AnalogClockTile(theme: theme)
                        .frame(width: 104, height: 104)
                }
            }
        }
    }

    private func todayScheduleSection(for date: Date) -> some View {
        Group {
            if let day = Weekday.from(date: date) {
                AppCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("오늘 일정")
                                .font(.headline)
                        }

                        ForEach(todayScheduleBands(for: day, on: date)) { band in
                            HStack(alignment: band.kind == .lunch ? .center : .top, spacing: 12) {
                                Text(timeBlockText(for: band))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(theme.secondaryText)
                                    .frame(width: 88, alignment: .leading)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(band.title)
                                        .font(.subheadline.weight(.semibold))
                                    if !band.subtitle.isEmpty {
                                        Text(band.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                }

                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }

    private func todayScheduleBands(for day: Weekday, on date: Date) -> [DayBand] {
        let entries = store.activeTimetable(for: date)
        let scheduledPeriods = Set(entries.filter { $0.day == day }.map(\.period))

        return SchedulePlanner.dailyBands(for: day, entries: entries, settings: store.settings)
            .filter { band in
                switch band.kind {
                case .period(let period):
                    return scheduledPeriods.contains(period)
                case .lunch, .afterSchool:
                    return true
                }
            }
    }

    private func weeklyGridSection(for date: Date) -> some View {
        let rows = gridRows()

        return AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("주간 시간표")
                    .font(.headline)

                GeometryReader { proxy in
                    let layout = gridLayout(for: proxy.size.width)

                    VStack(spacing: spacing) {
                        HStack(spacing: spacing) {
                            headerBox(title: "교시", width: layout.periodWidth)
                            ForEach(Weekday.allCases) { day in
                                headerBox(title: day.shortTitle, width: layout.dayWidth)
                            }
                        }

                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            switch row {
                            case .period(let slot):
                                HStack(spacing: spacing) {
                                    periodLabel(slot, width: layout.periodWidth)
                                    ForEach(Weekday.allCases) { day in
                                        gridCell(day: day, period: slot.period, width: layout.dayWidth, date: date)
                                    }
                                }
                            case .lunch:
                                HStack(spacing: spacing) {
                                    lunchLabel(width: layout.periodWidth)
                                    lunchBanner(width: mergedDayWidth(dayWidth: layout.dayWidth))
                                }
                            }
                        }
                    }
                }
                .frame(height: gridHeight(for: rows))

                Text("길게 눌러 이번 주만 시간표를 바꾸고, 다음 주엔 기본 시간표로 돌아갑니다.")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
            }
        }
    }

    @ViewBuilder
    private func gridCell(day: Weekday, period: Int, width: CGFloat, date: Date) -> some View {
        let entry = store.activeEntry(for: day, period: period, on: date)
        let isTemporary = entry.map { store.isTemporaryPlacement(for: $0, on: date) } ?? false
        let cell = TimetableDropTarget(day: day, period: period)

        if let entry {
            dropEnabledCell(
                entry: entry,
                width: width,
                isTemporary: isTemporary,
                isDropTargeted: targetedCell == cell,
                target: cell,
                date: date
            )
            .draggable(TimetableEntryDragPayload(entryID: entry.id)) {
                PeriodGridCell(entry: entry, width: width, isTemporary: true, themeOverride: theme)
            }
        } else {
            dropEnabledCell(
                entry: nil,
                width: width,
                isTemporary: false,
                isDropTargeted: targetedCell == cell,
                target: cell,
                date: date
            )
        }
    }

    private func dropEnabledCell(
        entry: TimetableEntry?,
        width: CGFloat,
        isTemporary: Bool,
        isDropTargeted: Bool,
        target: TimetableDropTarget,
        date: Date
    ) -> some View {
        PeriodGridCell(
            entry: entry,
            width: width,
            isTemporary: isTemporary,
            isDropTargeted: isDropTargeted
        )
        .dropDestination(for: TimetableEntryDragPayload.self) { items, _ in
            guard let item = items.first else { return false }
            return store.moveEntryTemporarily(
                id: item.entryID,
                to: target.day,
                period: target.period,
                referenceDate: date
            )
        } isTargeted: { isTargeted in
            targetedCell = isTargeted ? target : nil
        }
    }

    private func headerBox(title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .frame(width: width, height: 42)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.headerFill)
            )
    }

    private func periodLabel(_ slot: PeriodSlot, width: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text("\(slot.period)교시")
                .font(.caption.weight(.semibold))
            Text(periodTimeText(for: slot))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .minimumScaleFactor(0.8)
        }
        .frame(width: width, height: rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.panelFill)
        )
    }

    private func lunchLabel(width: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text("점심")
                .font(.caption.weight(.semibold))
            Text(lunchTimeText)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .minimumScaleFactor(0.8)
        }
        .frame(width: width, height: lunchRowHeight)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.lunchFill)
        )
    }

    private func lunchBanner(width: CGFloat) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("점심시간")
                    .font(.subheadline.weight(.semibold))
                Text("\(SchedulePlanner.clockText(minutes: store.settings.lunchStartMinutes)) - \(SchedulePlanner.clockText(minutes: store.settings.lunchEndMinutes))")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(width: width, height: lunchRowHeight)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.lunchBannerFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.lunchBorder, lineWidth: 1)
        )
    }

    private func timeBlockText(for band: DayBand) -> String {
        "\(SchedulePlanner.clockText(minutes: band.startMinutes))\n\(SchedulePlanner.clockText(minutes: band.endMinutes))"
    }

    private func periodTimeText(for slot: PeriodSlot) -> String {
        "\(SchedulePlanner.clockText(minutes: slot.startMinutes))\n\(SchedulePlanner.clockText(minutes: slot.endMinutes))"
    }

    private func schoolDateTitle(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day,
            let weekday = components.weekday
        else {
            return ""
        }

        let schoolYear = month >= 3 ? year : year - 1
        return "\(schoolYear)학년도\n\(year)년 \(padded(month))월 \(padded(day))일 \(weekdayTitle(for: weekday))"
    }

    private func padded(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private func weekdayTitle(for calendarWeekday: Int) -> String {
        switch calendarWeekday {
        case 1: return "일요일"
        case 2: return "월요일"
        case 3: return "화요일"
        case 4: return "수요일"
        case 5: return "목요일"
        case 6: return "금요일"
        case 7: return "토요일"
        default: return ""
        }
    }

    private var lunchTimeText: String {
        "\(SchedulePlanner.clockText(minutes: store.settings.lunchStartMinutes))\n\(SchedulePlanner.clockText(minutes: store.settings.lunchEndMinutes))"
    }

    private func gridLayout(for availableWidth: CGFloat) -> (periodWidth: CGFloat, dayWidth: CGFloat) {
        let dayCount = CGFloat(Weekday.allCases.count)
        let totalColumns = dayCount + 1
        let totalSpacing = spacing * dayCount

        let naturalDayWidth = max(
            baseDayColumnWidth,
            (availableWidth - basePeriodColumnWidth - totalSpacing) / dayCount
        )
        let naturalTotalWidth = basePeriodColumnWidth + (naturalDayWidth * dayCount) + totalSpacing
        let overflow = max(0, naturalTotalWidth - availableWidth)
        let shrinkPerColumn = overflow / totalColumns

        return (
            periodWidth: max(40, basePeriodColumnWidth - shrinkPerColumn),
            dayWidth: max(40, naturalDayWidth - shrinkPerColumn)
        )
    }

    private func mergedDayWidth(dayWidth: CGFloat) -> CGFloat {
        let dayCount = CGFloat(Weekday.allCases.count)
        return (dayWidth * dayCount) + (spacing * max(dayCount - 1, 0))
    }

    private func gridRows() -> [TimetableGridRow] {
        let slots = SchedulePlanner.periodSlots(settings: store.settings)
        var rows = slots.map { TimetableGridRow.period($0) }

        guard store.settings.lunchEndMinutes > store.settings.lunchStartMinutes else {
            return rows
        }

        let insertIndex = slots.firstIndex(where: { $0.startMinutes >= store.settings.lunchEndMinutes }) ?? rows.count
        rows.insert(.lunch, at: insertIndex)
        return rows
    }

    private func gridRowHeight(for row: TimetableGridRow) -> CGFloat {
        switch row {
        case .period:
            return rowHeight
        case .lunch:
            return lunchRowHeight
        }
    }

    private func gridHeight(for rows: [TimetableGridRow]) -> CGFloat {
        let rowHeights = rows.reduce(CGFloat.zero) { partialResult, row in
            partialResult + gridRowHeight(for: row)
        }
        return 42 + spacing + rowHeights + max(CGFloat(rows.count - 1), 0) * spacing
    }

    private var backgroundGradient: LinearGradient {
        theme.backgroundGradient
    }
}
