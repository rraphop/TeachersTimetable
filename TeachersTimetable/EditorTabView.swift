import SwiftUI

struct EditorTabView: View {
    @EnvironmentObject private var store: TimetableStore

    @State private var selectedDay: Weekday = .monday
    @State private var selectedPeriod: Int = 1
    @State private var subject = ""
    @State private var className = ""
    @State private var classroom = ""
    @State private var selectedColor: TimetableColor = .coral
    @State private var editingID: UUID?
    @State private var isShowingResetConfirmation = false
    @State private var quickEditingEntry: TimetableEntry?

    private var theme: AppThemePalette {
        store.settings.appTheme
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 18) {
                    inputCard
                        .id(EditorScrollTarget.inputForm)
                    timetableListCard(scrollProxy: scrollProxy)
                }
                .padding(16)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("시간표 입력")
        .sheet(item: $quickEditingEntry) { entry in
            QuickLessonEditSheet(entry: entry) { values in
                saveQuickEdit(entry: entry, values: values)
            }
        }
        .onAppear {
            alignFormWithSettings()
        }
        .onChange(of: store.availablePeriods) {
            alignPeriodWithSettings()
        }
        .onChange(of: store.settings.availableSubjectPresets) {
            alignInputSelectionsWithSettings()
        }
        .onChange(of: store.settings.availableClassPresets) {
            alignInputSelectionsWithSettings()
        }
        .onChange(of: store.settings.availableClassroomPresets) {
            alignInputSelectionsWithSettings()
        }
        .alert("초기화", isPresented: $isShowingResetConfirmation) {
            Button("아니오", role: .cancel) {}
            Button("예", role: .destructive) {
                store.clearTimetable()
                clearForm()
            }
        } message: {
            Text("모든 시간표가 삭제 됩니다.\n실행 하시겠습니까")
        }
    }

    private var inputCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(editingID == nil ? "새 수업 입력" : "수업 수정")
                    .font(.headline)

                Picker("요일", selection: $selectedDay) {
                    ForEach(Weekday.allCases) { day in
                        Text(day.shortTitle).tag(day)
                    }
                }
                .pickerStyle(.segmented)

                Picker("교시", selection: $selectedPeriod) {
                    ForEach(store.availablePeriods, id: \.self) { period in
                        Text("\(period)교시").tag(period)
                    }
                }

                presetPicker(
                    title: "과목",
                    selection: $subject,
                    options: store.settings.availableSubjectPresets,
                    placeholder: "설정된 과목 없음"
                )

                presetPicker(
                    title: "학급",
                    selection: $className,
                    options: store.settings.availableClassPresets,
                    placeholder: "설정된 학급 없음"
                )

                presetPicker(
                    title: "교실",
                    selection: $classroom,
                    options: store.settings.availableClassroomPresets,
                    placeholder: "설정된 교실 없음"
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("색상")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                    ColorSwatchPicker(selectedColor: $selectedColor)
                }

                HStack(spacing: 12) {
                    Button(action: saveEntry) {
                        Text(editingID == nil ? "시간표 추가" : "수정 저장")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if editingID != nil {
                        Button("취소") {
                            clearForm()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func presetPicker(
        title: String,
        selection: Binding<String>,
        options: [String],
        placeholder: String,
        display: @MainActor @escaping (String) -> String = { $0 }
    ) -> some View {
        let currentValue = selection.wrappedValue

        return VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)

            Picker(title, selection: selection) {
                if options.isEmpty && currentValue.isEmpty {
                    Text(placeholder).tag("")
                }

                ForEach(options, id: \.self) { option in
                    Text(display(option)).tag(option)
                }

                if !currentValue.isEmpty && !options.contains(currentValue) {
                    Text(display(currentValue)).tag(currentValue)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(options.isEmpty && currentValue.isEmpty)
        }
    }

    private func timetableListCard(scrollProxy: ScrollViewProxy) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("등록된 시간표")
                            .font(.headline)
                        Text("수업을 길게 눌러 바로 수정할 수 있습니다.")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                    Spacer()
                    Button("초기화", role: .destructive) {
                        isShowingResetConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }

                ForEach(Weekday.allCases) { day in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(day.fullTitle)
                            .font(.subheadline.weight(.semibold))

                        let dayEntries = store.entries(for: day)
                        if dayEntries.isEmpty {
                            Text("아직 입력된 수업이 없습니다.")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        } else {
                            ForEach(dayEntries) { entry in
                                timetableRow(entry, scrollProxy: scrollProxy)
                            }
                        }
                    }
                }
            }
        }
    }

    private func timetableRow(_ entry: TimetableEntry, scrollProxy: ScrollViewProxy) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(entry.color.tintGradient)
                .frame(width: 12, height: 42)

            Button {
                load(entry)
                withAnimation(.easeInOut) {
                    scrollProxy.scrollTo(EditorScrollTarget.inputForm, anchor: .top)
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.periodLabel) · \(entry.subject)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                    Text("\(entry.classDisplayText) · \(entry.classroomDisplayText)")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                deleteEntry(entry)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.panelFill)
        )
        .contentShape(Rectangle())
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in
                    quickEditingEntry = entry
                }
        )
        .accessibilityAction(named: "수정") {
            quickEditingEntry = entry
        }
    }

    private func saveEntry() {
        store.upsertEntry(
            editingID: editingID,
            day: selectedDay,
            period: selectedPeriod,
            subject: subject,
            className: className,
            classroom: classroom,
            color: selectedColor
        )
        clearForm(keepingInputSelections: true)
    }

    private func saveQuickEdit(entry: TimetableEntry, values: QuickLessonEditValues) {
        store.upsertEntry(
            editingID: entry.id,
            day: entry.day,
            period: values.period,
            subject: values.subject,
            className: values.className,
            classroom: values.classroom,
            color: values.color
        )

        if editingID == entry.id {
            selectedDay = entry.day
            selectedPeriod = values.period
            subject = values.subject
            className = values.className
            classroom = values.classroom
            selectedColor = values.color
        }

        quickEditingEntry = nil
    }

    private func deleteEntry(_ entry: TimetableEntry) {
        store.deleteEntry(id: entry.id)
        if editingID == entry.id {
            clearForm()
        }
        if quickEditingEntry?.id == entry.id {
            quickEditingEntry = nil
        }
    }

    private func load(_ entry: TimetableEntry) {
        editingID = entry.id
        selectedDay = entry.day
        selectedPeriod = entry.period
        subject = entry.subject
        className = entry.className
        classroom = entry.classroom
        selectedColor = entry.color
    }

    private func clearForm(keepingInputSelections: Bool = false) {
        editingID = nil
        if !keepingInputSelections {
            subject = ""
            className = ""
            classroom = ""
            alignInputSelectionsWithSettings()
        }
        selectedColor = .coral
        alignPeriodWithSettings()
    }

    private func alignFormWithSettings() {
        alignPeriodWithSettings()
        alignInputSelectionsWithSettings()
    }

    private func alignPeriodWithSettings() {
        selectedPeriod = store.availablePeriods.contains(selectedPeriod) ? selectedPeriod : (store.availablePeriods.first ?? 1)
    }

    private func alignInputSelectionsWithSettings() {
        guard editingID == nil else { return }

        subject = alignedSelection(subject, options: store.settings.availableSubjectPresets)
        className = alignedSelection(className, options: store.settings.availableClassPresets)
        classroom = alignedSelection(classroom, options: store.settings.availableClassroomPresets)
    }

    private func alignedSelection(_ value: String, options: [String]) -> String {
        options.contains(value) ? value : (options.first ?? "")
    }

    private var backgroundGradient: LinearGradient {
        theme.backgroundGradient
    }
}

private enum EditorScrollTarget: Hashable {
    case inputForm
}

private struct QuickLessonEditValues {
    var period: Int
    var subject: String
    var className: String
    var classroom: String
    var color: TimetableColor
}

private struct QuickLessonEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TimetableStore

    let entry: TimetableEntry
    let onSave: (QuickLessonEditValues) -> Void

    @State private var selectedPeriod: Int
    @State private var subject: String
    @State private var className: String
    @State private var classroom: String
    @State private var selectedColor: TimetableColor

    private var theme: AppThemePalette {
        store.settings.appTheme
    }

    private var canSave: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(entry: TimetableEntry, onSave: @escaping (QuickLessonEditValues) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _selectedPeriod = State(initialValue: entry.period)
        _subject = State(initialValue: entry.subject)
        _className = State(initialValue: entry.className)
        _classroom = State(initialValue: entry.classroom)
        _selectedColor = State(initialValue: entry.color)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("수업") {
                    Text(entry.day.fullTitle)
                        .foregroundStyle(theme.secondaryText)

                    Picker("교시", selection: $selectedPeriod) {
                        ForEach(store.availablePeriods, id: \.self) { period in
                            Text("\(period)교시").tag(period)
                        }
                    }

                    presetPicker(
                        title: "과목",
                        selection: $subject,
                        options: store.settings.availableSubjectPresets,
                        placeholder: "설정된 과목 없음"
                    )

                    presetPicker(
                        title: "학급",
                        selection: $className,
                        options: store.settings.availableClassPresets,
                        placeholder: "설정된 학급 없음"
                    )

                    presetPicker(
                        title: "교실",
                        selection: $classroom,
                        options: store.settings.availableClassroomPresets,
                        placeholder: "설정된 교실 없음"
                    )
                }

                Section("색상") {
                    ColorSwatchPicker(selectedColor: $selectedColor)
                        .padding(.vertical, 4)
                }
            }
            .navigationTitle("수업 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(
                            QuickLessonEditValues(
                                period: selectedPeriod,
                                subject: subject,
                                className: className,
                                classroom: classroom,
                                color: selectedColor
                            )
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                alignPeriodWithSettings()
            }
            .onChange(of: store.availablePeriods) {
                alignPeriodWithSettings()
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func presetPicker(
        title: String,
        selection: Binding<String>,
        options: [String],
        placeholder: String
    ) -> some View {
        let currentValue = selection.wrappedValue

        return Picker(title, selection: selection) {
            if options.isEmpty && currentValue.isEmpty {
                Text(placeholder).tag("")
            }

            ForEach(options, id: \.self) { option in
                Text(option).tag(option)
            }

            if !currentValue.isEmpty && !options.contains(currentValue) {
                Text(currentValue).tag(currentValue)
            }
        }
        .disabled(options.isEmpty && currentValue.isEmpty)
    }

    private func alignPeriodWithSettings() {
        selectedPeriod = store.availablePeriods.contains(selectedPeriod) ? selectedPeriod : (store.availablePeriods.first ?? entry.period)
    }
}
