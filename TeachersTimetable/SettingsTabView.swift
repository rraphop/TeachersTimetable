import SwiftUI

private enum AfterSchoolTimeField {
    case start
    case end
}

struct SettingsTabView: View {
    @EnvironmentObject private var store: TimetableStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var draftSubjectPreset = ""
    @State private var draftClassroomPreset = ""
    @State private var draftClassPreset = ""

    private var theme: AppThemePalette {
        store.settings.appTheme
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                classTimeCard
                inputPresetCard
                lunchAndAfterSchoolCard
                alarmCard
                themeCard
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
                settingsSectionHeader("수업 기본값")

                Stepper(
                    value: settingsBinding(\.classDuration),
                    in: TeacherSettings.classDurationRange,
                    step: TeacherSettings.classDurationStep
                ) {
                    settingRow(title: "수업 시간", value: "\(store.settings.classDuration)분")
                }

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

                ForEach(classTimeWarnings, id: \.self) { warning in
                    settingsFootnote(warning)
                }

                Stepper(value: settingsBinding(\.highestPeriod), in: 1...12) {
                    settingRow(title: "마지막 교시", value: "\(store.settings.highestPeriod)교시")
                }
            }
        }
    }

    private var inputPresetCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                settingsSectionHeader("입력 선택지")

                textPresetEditor(
                    title: "과목 설정",
                    placeholder: "과목",
                    draft: $draftSubjectPreset,
                    values: store.settings.availableSubjectPresets,
                    limit: TeacherSettings.maxSubjectPresetCount,
                    addAction: addSubjectPreset,
                    removeAction: removeSubjectPreset
                )

                classPresetEditor

                textPresetEditor(
                    title: "교실 설정",
                    placeholder: "교실",
                    draft: $draftClassroomPreset,
                    values: store.settings.availableClassroomPresets,
                    limit: TeacherSettings.maxClassroomPresetCount,
                    addAction: addClassroomPreset,
                    removeAction: removeClassroomPreset
                )
            }
        }
    }

    private func textPresetEditor(
        title: String,
        placeholder: String,
        draft: Binding<String>,
        values: [String],
        limit: Int,
        addAction: @escaping () -> Void,
        removeAction: @escaping (String) -> Void
    ) -> some View {
        let cleanedDraft = TeacherSettings.normalizedPresetText(draft.wrappedValue)
        let canAdd = !cleanedDraft.isEmpty && values.count < limit && !values.contains(cleanedDraft)

        return VStack(alignment: .leading, spacing: 10) {
            presetHeader(title: title, limit: limit)

            HStack(spacing: 8) {
                TextField(placeholder, text: draft)
                    .textFieldStyle(.roundedBorder)

                Button(action: addAction) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .disabled(!canAdd)
                .accessibilityLabel("\(title) 추가")
            }

            ForEach(values, id: \.self) { value in
                presetValueRow(title: value) {
                    removeAction(value)
                }
            }
        }
    }

    private var classPresetEditor: some View {
        let values = store.settings.availableClassPresets
        let cleanedDraft = TeacherSettings.normalizedPresetText(draftClassPreset)
        let canAdd = !cleanedDraft.isEmpty && !values.contains(cleanedDraft)

        return VStack(alignment: .leading, spacing: 10) {
            Text("학급 설정")
                .font(.body)
                .fontWeight(.regular)

            HStack(spacing: 8) {
                TextField("학급", text: $draftClassPreset)
                    .textFieldStyle(.roundedBorder)

                Button(action: addClassPreset) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .disabled(!canAdd)
                .accessibilityLabel("학급 추가")
            }

            ForEach(values, id: \.self) { value in
                presetValueRow(title: value) {
                    removeClassPreset(value)
                }
            }
        }
    }

    private func presetHeader(title: String, limit: Int) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .fontWeight(.regular)
            Spacer()
            Text("최대 \(limit)개")
                .font(.caption)
                .foregroundStyle(theme.tertiaryText)
        }
    }

    private func presetValueRow(title: String, removeAction: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline)

            Spacer()

            Button(role: .destructive, action: removeAction) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.panelFill)
        )
    }

    private var lunchAndAfterSchoolCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                settingsSectionHeader("점심 · 방과후")

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

                if !lunchTimeIsValid {
                    settingsFootnote("점심 종료 시간이 시작 시간보다 늦어야 시간표에 점심 시간이 표시됩니다.")
                }

                Toggle("방과후 시간 사용", isOn: settingsBinding(\.afterSchoolEnabled))

                if store.settings.afterSchoolEnabled {
                    afterSchoolDaySelector

                    if store.settings.sortedAfterSchoolSchedules.isEmpty {
                        Text("방과후 시간을 사용할 요일을 선택해 주세요.")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    } else {
                        ForEach(store.settings.sortedAfterSchoolSchedules) { schedule in
                            afterSchoolScheduleEditor(for: schedule.day)
                        }
                    }
                }
            }
        }
    }

    private var afterSchoolDaySelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("방과후 요일")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(afterSchoolSelectionSummary)
                    .font(.caption)
                    .foregroundStyle(theme.tertiaryText)
            }

            HStack(spacing: 8) {
                ForEach(Weekday.allCases) { day in
                    afterSchoolDayButton(for: day)
                }
            }

            HStack(spacing: 8) {
                Button("매일") {
                    selectAllAfterSchoolDays()
                }
                .buttonStyle(.bordered)

                Button("전체 해제") {
                    clearAfterSchoolDays()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func afterSchoolDayButton(for day: Weekday) -> some View {
        let selected = isAfterSchoolDaySelected(day)

        return Button {
            toggleAfterSchoolDay(day)
        } label: {
            Text(day.shortTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.white : theme.primaryText)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? theme.accentTint : theme.panelFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(selected ? theme.accentTint.opacity(0.25) : theme.cardStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.fullTitle) 방과후")
        .accessibilityValue(selected ? "선택됨" : "선택 안 됨")
    }

    private func afterSchoolScheduleEditor(for day: Weekday) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(day.fullTitle)
                .font(.subheadline.weight(.semibold))

            DatePicker(
                "시작",
                selection: afterSchoolDateBinding(for: day, field: .start),
                displayedComponents: .hourAndMinute
            )

            DatePicker(
                "종료",
                selection: afterSchoolDateBinding(for: day, field: .end),
                displayedComponents: .hourAndMinute
            )

            if let schedule = store.settings.afterSchoolSchedule(for: day), !schedule.isValid {
                Text("종료 시간이 시작 시간보다 늦어야 일정에 표시됩니다.")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.panelFill)
        )
    }

    private var alarmCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                settingsSectionHeader("알림")

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

                if store.hasActiveWeeklyOverride {
                    settingsFootnote("이번 주 임시 변경은 화면에만 적용되며 반복 알림은 원래 시간표 기준으로 예약됩니다.")
                }

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

    private var themeCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                settingsSectionHeader("테마")

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

    private func settingsSectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(settingsSectionHeaderFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.cardStroke, lineWidth: 1)
        )
    }

    private var settingsSectionHeaderFill: Color {
        if colorScheme == .dark {
            return Color(red: 0.22, green: 0.23, blue: 0.26).opacity(0.92)
        }

        return Color(red: 0.99, green: 0.96, blue: 0.90).opacity(0.95)
    }

    private func settingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(theme.secondaryText)
        }
    }

    private func settingsFootnote(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(theme.secondaryText)
    }

    private func addSubjectPreset() {
        let value = TeacherSettings.normalizedPresetText(draftSubjectPreset)
        guard !value.isEmpty else { return }

        updateSettings { settings in
            var presets = settings.availableSubjectPresets
            guard presets.count < TeacherSettings.maxSubjectPresetCount, !presets.contains(value) else { return }
            presets.append(value)
            settings.subjectPresets = presets
        }

        draftSubjectPreset = ""
    }

    private func removeSubjectPreset(_ value: String) {
        updateSettings { settings in
            settings.subjectPresets = settings.availableSubjectPresets.filter { $0 != value }
        }
    }

    private func addClassPreset() {
        let value = TeacherSettings.normalizedPresetText(draftClassPreset)
        guard !value.isEmpty else { return }

        updateSettings { settings in
            var presets = settings.availableClassPresets
            guard !presets.contains(value) else { return }
            presets.append(value)
            settings.classPresets = TeacherSettings.normalizedClassPresets(presets)
        }

        draftClassPreset = ""
    }

    private func removeClassPreset(_ value: String) {
        updateSettings { settings in
            settings.classPresets = settings.availableClassPresets.filter { $0 != value }
        }
    }

    private func addClassroomPreset() {
        let value = TeacherSettings.normalizedPresetText(draftClassroomPreset)
        guard !value.isEmpty else { return }

        updateSettings { settings in
            var presets = settings.availableClassroomPresets
            guard presets.count < TeacherSettings.maxClassroomPresetCount, !presets.contains(value) else { return }
            presets.append(value)
            settings.classroomPresets = presets
        }

        draftClassroomPreset = ""
    }

    private func removeClassroomPreset(_ value: String) {
        updateSettings { settings in
            settings.classroomPresets = settings.availableClassroomPresets.filter { $0 != value }
        }
    }

    private var afterSchoolSelectionSummary: String {
        let selectedDays = store.settings.sortedAfterSchoolSchedules.map(\.day)

        if selectedDays.count == Weekday.allCases.count {
            return "매일"
        }

        if selectedDays.isEmpty {
            return "선택 없음"
        }

        return selectedDays.map(\.shortTitle).joined(separator: " · ")
    }

    private func isAfterSchoolDaySelected(_ day: Weekday) -> Bool {
        store.settings.afterSchoolSchedule(for: day) != nil
    }

    private func toggleAfterSchoolDay(_ day: Weekday) {
        updateSettings { settings in
            if settings.afterSchoolSchedule(for: day) != nil {
                settings.removeAfterSchoolSchedule(for: day)
            } else {
                let referenceSchedule = settings.sortedAfterSchoolSchedules.first
                settings.setAfterSchoolSchedule(
                    AfterSchoolDaySchedule(
                        day: day,
                        startMinutes: referenceSchedule?.startMinutes ?? settings.afterSchoolStartMinutes,
                        endMinutes: referenceSchedule?.endMinutes ?? settings.afterSchoolEndMinutes
                    )
                )
            }
        }
    }

    private func selectAllAfterSchoolDays() {
        updateSettings { settings in
            let referenceSchedule = settings.sortedAfterSchoolSchedules.first
            let startMinutes = referenceSchedule?.startMinutes ?? settings.afterSchoolStartMinutes
            let endMinutes = referenceSchedule?.endMinutes ?? settings.afterSchoolEndMinutes

            for day in Weekday.allCases where settings.afterSchoolSchedule(for: day) == nil {
                settings.setAfterSchoolSchedule(
                    AfterSchoolDaySchedule(
                        day: day,
                        startMinutes: startMinutes,
                        endMinutes: endMinutes
                    )
                )
            }
        }
    }

    private func clearAfterSchoolDays() {
        updateSettings { settings in
            settings.afterSchoolSchedules = []
        }
    }

    private var classTimeWarnings: [String] {
        var warnings: [String] = []

        if store.settings.zeroPeriodEnabled &&
            store.settings.zeroPeriodStartMinutes >= store.settings.firstPeriodStartMinutes {
            warnings.append("0교시 시작이 1교시보다 늦거나 같습니다. 시간표가 의도와 다르게 보일 수 있습니다.")
        }

        if lunchTimeIsValid {
            let firstPeriodEndMinutes = store.settings.firstPeriodStartMinutes + store.settings.classDuration
            if store.settings.firstPeriodStartMinutes < store.settings.lunchEndMinutes &&
                firstPeriodEndMinutes > store.settings.lunchStartMinutes {
                warnings.append("1교시 시간이 점심과 겹치면 해당 교시는 점심 종료 뒤로 배치됩니다.")
            } else if store.settings.firstPeriodStartMinutes >= store.settings.lunchEndMinutes {
                warnings.append("1교시 시작이 점심 이후입니다. 오전 교시가 의도와 다르게 배치될 수 있습니다.")
            }
        }

        return warnings
    }

    private var lunchTimeIsValid: Bool {
        store.settings.lunchEndMinutes > store.settings.lunchStartMinutes
    }

    private func updateSettings(_ update: (inout TeacherSettings) -> Void) {
        var copy = store.settings
        update(&copy)
        store.settings = copy
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

    private func afterSchoolDateBinding(for day: Weekday, field: AfterSchoolTimeField) -> Binding<Date> {
        Binding {
            let schedule = store.settings.afterSchoolSchedule(for: day)
            let minutes: Int

            switch field {
            case .start:
                minutes = schedule?.startMinutes ?? store.settings.afterSchoolStartMinutes
            case .end:
                minutes = schedule?.endMinutes ?? store.settings.afterSchoolEndMinutes
            }

            return dateFromMinutes(minutes)
        } set: { newValue in
            var copy = store.settings
            var schedule = copy.afterSchoolSchedule(for: day) ?? AfterSchoolDaySchedule(
                day: day,
                startMinutes: copy.afterSchoolStartMinutes,
                endMinutes: copy.afterSchoolEndMinutes
            )
            let minutes = minutesFromDate(newValue)

            switch field {
            case .start:
                schedule.startMinutes = minutes
                copy.afterSchoolStartMinutes = minutes
            case .end:
                schedule.endMinutes = minutes
                copy.afterSchoolEndMinutes = minutes
            }

            copy.setAfterSchoolSchedule(schedule)
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
