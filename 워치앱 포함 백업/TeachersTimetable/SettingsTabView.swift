import SwiftUI

struct SettingsTabView: View {
    @EnvironmentObject private var store: TimetableStore
    @State private var isSyncingToWatch = false
    @State private var watchSyncMessage: String?

    private var theme: AppThemePalette {
        store.settings.appTheme
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                classTimeCard
                lunchAndAfterSchoolCard
                alarmCard
                themeCard
                watchNoticeCard
            }
            .padding(16)
        }
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("기본 설정")
        .onAppear {
            store.refreshNotificationState()
        }
    }

    private var classTimeCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("수업 기본값")
                    .font(.headline)

                Picker("수업 시간", selection: settingsBinding(\.classDuration)) {
                    Text("40분").tag(40)
                    Text("45분").tag(45)
                    Text("50분").tag(50)
                }
                .pickerStyle(.segmented)

                Stepper(value: settingsBinding(\.breakDuration), in: 5...30, step: 5) {
                    settingRow(title: "쉬는 시간", value: "\(store.settings.breakDuration)분")
                }

                DatePicker(
                    "1교시 시작",
                    selection: dateBinding(for: \.firstPeriodStartMinutes),
                    displayedComponents: .hourAndMinute
                )

                Toggle("0교시 사용", isOn: settingsBinding(\.zeroPeriodEnabled))

                if store.settings.zeroPeriodEnabled {
                    DatePicker(
                        "0교시 시작",
                        selection: dateBinding(for: \.zeroPeriodStartMinutes),
                        displayedComponents: .hourAndMinute
                    )
                }

                Stepper(value: settingsBinding(\.highestPeriod), in: 1...12) {
                    settingRow(title: "마지막 교시", value: "\(store.settings.highestPeriod)교시")
                }
            }
        }
    }

    private var lunchAndAfterSchoolCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("점심 · 방과후")
                    .font(.headline)

                DatePicker(
                    "점심 시작",
                    selection: dateBinding(for: \.lunchStartMinutes),
                    displayedComponents: .hourAndMinute
                )

                DatePicker(
                    "점심 종료",
                    selection: dateBinding(for: \.lunchEndMinutes),
                    displayedComponents: .hourAndMinute
                )

                Toggle("방과후 시간 사용", isOn: settingsBinding(\.afterSchoolEnabled))

                if store.settings.afterSchoolEnabled {
                    DatePicker(
                        "방과후 시작",
                        selection: dateBinding(for: \.afterSchoolStartMinutes),
                        displayedComponents: .hourAndMinute
                    )

                    DatePicker(
                        "방과후 종료",
                        selection: dateBinding(for: \.afterSchoolEndMinutes),
                        displayedComponents: .hourAndMinute
                    )
                }
            }
        }
    }

    private var alarmCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("알림")
                    .font(.headline)

                Toggle("수업 알람 사용", isOn: settingsBinding(\.alarmEnabled))

                Stepper(value: settingsBinding(\.alarmLeadMinutes), in: 0...5, step: 1) {
                    settingRow(
                        title: "알람 리드 타임",
                        value: store.settings.alarmLeadMinutes == 0 ? "정시" : "\(store.settings.alarmLeadMinutes)분 전"
                    )
                }

                Toggle("기본 진동 우선", isOn: settingsBinding(\.vibrationOnly))

                settingRow(title: "알림 권한", value: notificationStatusText)
                settingRow(title: "예약된 수업 알림", value: "\(store.scheduledNotificationCount)개")

                Button("알림 권한 요청") {
                    store.requestNotificationPermission()
                }
                .buttonStyle(.borderedProminent)

                Button {
                    store.sendTestNotification()
                } label: {
                    Label("테스트 알림 보내기", systemImage: "bell.badge")
                }
                .buttonStyle(.bordered)

                if let message = store.notificationFeedbackMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
            }
        }
    }

    private var watchNoticeCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Apple Watch 연동")
                    .font(.headline)
                Text("시간표를 저장하면 연결된 Apple Watch 앱으로 자동 동기화됩니다.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                Text("수업 알람을 켜면 iPhone과 Apple Watch 양쪽에서 교시 알림을 예약합니다.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)

                Button {
                    syncTimetableToWatch()
                } label: {
                    Label(
                        isSyncingToWatch ? "동기화 중" : "Apple Watch로 지금 동기화",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSyncingToWatch)
                .padding(.top, 4)

                if let watchSyncMessage {
                    Text(watchSyncMessage)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
            }
        }
    }

    private var themeCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("테마")
                    .font(.headline)

                Picker("화면 모드", selection: settingsBinding(\.themeMode)) {
                    ForEach(AppThemeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if store.settings.themeMode == .custom {
                    ColorPicker("배경색", selection: customColorBinding(for: \.customBackgroundColor))
                    ColorPicker("글자색", selection: customColorBinding(for: \.customTextColor))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("커스텀 미리보기")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(store.settings.customBackgroundColor.swiftUIColor)
                            .frame(height: 90)
                            .overlay(
                                VStack(spacing: 6) {
                                    Text("시간표 미리보기")
                                        .font(.headline)
                                    Text("배경색과 글자색이 앱 전체에 적용됩니다.")
                                        .font(.caption)
                                }
                                .foregroundStyle(store.settings.customTextColor.swiftUIColor)
                            )
                    }
                }
            }
        }
    }

    private func settingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(theme.secondaryText)
        }
    }

    private func settingsBinding<Value>(_ keyPath: WritableKeyPath<TeacherSettings, Value>) -> Binding<Value> {
        Binding {
            store.settings[keyPath: keyPath]
        } set: { newValue in
            var copy = store.settings
            copy[keyPath: keyPath] = newValue
            store.settings = copy
        }
    }

    private func dateBinding(for keyPath: WritableKeyPath<TeacherSettings, Int>) -> Binding<Date> {
        Binding {
            dateFromMinutes(store.settings[keyPath: keyPath])
        } set: { newValue in
            var copy = store.settings
            copy[keyPath: keyPath] = minutesFromDate(newValue)
            store.settings = copy
        }
    }

    private func customColorBinding(for keyPath: WritableKeyPath<TeacherSettings, ThemeColorData>) -> Binding<Color> {
        Binding {
            store.settings[keyPath: keyPath].swiftUIColor
        } set: { newValue in
            var copy = store.settings
            copy[keyPath: keyPath] = ThemeColorData(color: newValue)
            store.settings = copy
        }
    }

    private func syncTimetableToWatch() {
        isSyncingToWatch = true
        watchSyncMessage = "Apple Watch로 시간표를 보내는 중입니다."

        store.syncTimetableToWatch { result in
            isSyncingToWatch = false
            watchSyncMessage = watchSyncMessage(for: result)
        }
    }

    private func watchSyncMessage(for result: WatchSyncResult) -> String {
        switch result {
        case .sent:
            return "Apple Watch에 시간표를 보냈습니다. Watch 알림은 Watch 앱의 알림 권한이 허용되어야 예약됩니다."
        case .queued:
            return "Apple Watch로 전송을 예약했습니다. Watch 앱을 열면 시간표와 알림 예약 상태가 갱신됩니다."
        case .activating:
            return "Apple Watch 연동을 준비 중입니다. 활성화되면 자동 전송됩니다."
        case .watchNotPaired:
            return "이 iPhone에 페어링된 Apple Watch를 찾지 못했습니다."
        case .watchAppNotInstalled:
            return "Apple Watch에 시간표 앱이 설치되어 있지 않습니다. iPhone의 Watch 앱에서 설치를 확인해 주세요."
        case .unsupported:
            return "Apple Watch 동기화는 iPhone에서 사용할 수 있습니다."
        case .failed:
            return "시간표 데이터를 준비하지 못했습니다. 앱을 다시 열고 시도해 주세요."
        }
    }

    private func dateFromMinutes(_ minutes: Int) -> Date {
        Calendar.current.date(
            bySettingHour: max(minutes, 0) / 60,
            minute: max(minutes, 0) % 60,
            second: 0,
            of: .now
        ) ?? .now
    }

    private func minutesFromDate(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private var notificationStatusText: String {
        switch store.notificationAuthorization {
        case .authorized: return "허용됨"
        case .denied: return "거부됨"
        case .ephemeral: return "임시 허용"
        case .notDetermined: return "미확인"
        case .provisional: return "잠정 허용"
        @unknown default: return "확인 필요"
        }
    }

    private var backgroundGradient: LinearGradient {
        theme.backgroundGradient
    }
}
