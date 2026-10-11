import SwiftUI

private enum TimetableGridRow: Hashable {
    case period(PeriodSlot)
    case lunch
}

struct OverviewTabView: View {
    @EnvironmentObject private var store: TimetableStore

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

                weeklyGridSection

                TimelineView(.periodic(from: .now, by: 60)) { context in
                    todayScheduleSection(for: context.date)
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
                let status = SchedulePlanner.status(
                    for: day,
                    at: date,
                    entries: store.timetable,
                    settings: store.settings
                )

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(day.fullTitle)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                        Text(status.currentPeriodLabel)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(status.headline)
                            .font(.headline)
                        Text(status.detail)
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                    }

                    Spacer(minLength: 12)
                }

                if let nextLine = status.nextLine {
                    Divider()
                    Text(nextLine)
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryText)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("오늘은 수업이 없는 날")
                        .font(.headline)
                    Text("주말에는 다음 평일 시간표를 그대로 빠르게 확인할 수 있습니다.")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
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

                        ForEach(todayScheduleBands(for: day)) { band in
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

    private func todayScheduleBands(for day: Weekday) -> [DayBand] {
        let scheduledPeriods = Set(store.timetable.filter { $0.day == day }.map(\.period))

        return SchedulePlanner.dailyBands(for: day, entries: store.timetable, settings: store.settings)
            .filter { band in
                switch band.kind {
                case .period(let period):
                    return scheduledPeriods.contains(period)
                case .lunch, .afterSchool:
                    return true
                }
            }
    }

    private var weeklyGridSection: some View {
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
                                        PeriodGridCell(
                                            entry: store.entry(for: day, period: slot.period),
                                            width: layout.dayWidth
                                        )
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
            }
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
