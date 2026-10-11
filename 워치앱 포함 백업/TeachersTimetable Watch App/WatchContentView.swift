import SwiftUI
import UserNotifications

struct WatchContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: WatchTimetableStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let day = Weekday.from(date: context.date) {
                        currentPeriodCard(day: day, date: context.date)
                        todaySection(day: day)
                    } else {
                        weekendCard
                    }

                    notificationCard
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
        }
        .task {
            store.refreshFromPhone()
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            store.refreshFromPhone()
        }
    }

    // MARK: - 현재 교시 카드

    private func currentPeriodCard(day: Weekday, date: Date) -> some View {
        let status = SchedulePlanner.status(
            for: day,
            at: date,
            entries: store.timetable,
            settings: store.settings
        )
        let active = store.currentEntry(for: day, at: date)

        return VStack(alignment: .leading, spacing: 0) {
            // 상단 레이블 행
            HStack(spacing: 0) {
                Text(status.currentPeriodLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                Spacer()
                Text(day.shortTitle + "요일")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 5)

            // 과목명
            Text(active?.entry.subject ?? status.headline)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .lineLimit(1)
                .padding(.bottom, 6)

            // 구분선
            Rectangle()
                .fill(Color.orange.opacity(0.25))
                .frame(height: 1)
                .padding(.bottom, 6)

            // 정보 행
            VStack(alignment: .leading, spacing: 4) {
                WatchInfoRow(
                    icon: "person.2.fill",
                    title: "학급",
                    value: active?.entry.classDisplayText ?? "-"
                )
                WatchInfoRow(
                    icon: "mappin.circle.fill",
                    title: "교실",
                    value: active?.entry.classroomDisplayText ?? status.detail
                )
                if let activeEntry = active {
                    WatchInfoRow(
                        icon: "clock.fill",
                        title: "시간",
                        value: SchedulePlanner.timeRangeText(
                            start: activeEntry.slot.startMinutes,
                            end: activeEntry.slot.endMinutes
                        )
                    )
                }
            }

            // 다음 수업
            if let nextLine = status.nextLine {
                Rectangle()
                    .fill(Color.orange.opacity(0.20))
                    .frame(height: 1)
                    .padding(.top, 6)
                    .padding(.bottom, 4)

                Text(nextLine)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.orange.opacity(0.30), lineWidth: 1)
                )
        )
    }

    // MARK: - 오늘 일정 섹션

    private func todaySection(day: Weekday) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("오늘 일정")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(store.entries(for: day)) { entry in
                    HStack(alignment: .center, spacing: 8) {
                        // 교시 뱃지
                        ZStack {
                            Circle()
                                .fill(entry.color.swiftUIColor.opacity(0.85))
                                .frame(width: 22, height: 22)
                            Text("\(entry.period)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }

                        // 과목 및 정보
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.subject)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            Text("\(entry.classDisplayText) · \(entry.classroomDisplayText)")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(entry.color.swiftUIColor.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(entry.color.swiftUIColor.opacity(0.22), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    // MARK: - 주말 카드

    private var weekendCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("오늘 수업 없음")
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Text("평일 시간표는 iPhone 앱에서 수정하면 자동으로 동기화됩니다.")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.gray.opacity(0.22), lineWidth: 1)
                )
        )
    }

    // MARK: - 알림 카드

    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                Text("알림 \(notificationStatusText)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if store.settings.alarmEnabled {
                Text("예약된 알림 \(store.scheduledNotificationCount)개")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if store.notificationAuthorization == .notDetermined {
                Button {
                    store.requestNotificationPermission()
                } label: {
                    Text("알림 권한 요청")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }

            if store.notificationAuthorization == .denied {
                Text("Watch 설정 > 알림에서 수업알리미 알림을 켜면 교시마다 진동 알림을 받을 수 있습니다.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.gray.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private var notificationStatusText: String {
        switch store.notificationAuthorization {
        case .authorized: return "허용됨"
        case .denied: return "꺼짐"
        case .notDetermined: return "확인 중"
        case .provisional: return "잠정 허용"
        @unknown default: return "확인 필요"
        }
    }
}

// MARK: - 정보 행 컴포넌트

private struct WatchInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.orange.opacity(0.80))
                .frame(width: 12)

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .leading)

            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 11, weight: .regular))
                .lineLimit(1)
        }
    }
}
