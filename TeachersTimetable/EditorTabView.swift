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
    @FocusState private var focusedField: InputField?

    private var theme: AppThemePalette {
        store.settings.appTheme
    }

    private enum InputField {
        case subject
        case className
        case classroom
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                inputCard
                timetableListCard
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("시간표 입력")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("숨김") {
                    focusedField = nil
                }
            }
        }
        .onAppear {
            alignPeriodWithSettings()
        }
        .onChange(of: store.availablePeriods) {
            alignPeriodWithSettings()
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

                VStack(alignment: .leading, spacing: 10) {
                    Text("과목")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                    TextField("예: 국어", text: $subject)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .subject)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .className
                        }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("학급")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                    TextField("예: 2-1", text: $className)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .className)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .classroom
                        }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("교실")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                    TextField("예: 본교실 / 과학실", text: $classroom)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .classroom)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                        }
                }

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

                    if editingID != nil {
                        Button("취소", action: clearForm)
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var timetableListCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("등록된 시간표")
                            .font(.headline)
                        Text("요일별 목록에서 바로 수정할 수 있습니다.")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                    Spacer()
                    Button("샘플 복원") {
                        store.resetToSampleData()
                        clearForm()
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
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(entry.color.tintGradient)
                                        .frame(width: 12, height: 42)

                                    Button {
                                        load(entry)
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
                                        store.deleteEntry(id: entry.id)
                                        if editingID == entry.id {
                                            clearForm()
                                        }
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
                            }
                        }
                    }
                }
            }
        }
    }

    private func saveEntry() {
        focusedField = nil
        store.upsertEntry(
            editingID: editingID,
            day: selectedDay,
            period: selectedPeriod,
            subject: subject,
            className: className,
            classroom: classroom,
            color: selectedColor
        )
        clearForm()
    }

    private func load(_ entry: TimetableEntry) {
        focusedField = nil
        editingID = entry.id
        selectedDay = entry.day
        selectedPeriod = entry.period
        subject = entry.subject
        className = entry.className
        classroom = entry.classroom
        selectedColor = entry.color
    }

    private func clearForm() {
        focusedField = nil
        editingID = nil
        subject = ""
        className = ""
        classroom = ""
        selectedColor = .coral
        alignPeriodWithSettings()
    }

    private func alignPeriodWithSettings() {
        selectedPeriod = store.availablePeriods.contains(selectedPeriod) ? selectedPeriod : (store.availablePeriods.first ?? 1)
    }

    private var backgroundGradient: LinearGradient {
        theme.backgroundGradient
    }
}
