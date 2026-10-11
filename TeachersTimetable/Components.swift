import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension ThemeColorData {
    static let white = ThemeColorData(red: 1, green: 1, blue: 1, opacity: 1)
    static let black = ThemeColorData(red: 0, green: 0, blue: 0, opacity: 1)
    static let lunchAccent = ThemeColorData(red: 1.0, green: 0.76, blue: 0.31, opacity: 1)

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    var brightness: Double {
        (0.299 * red) + (0.587 * green) + (0.114 * blue)
    }

    var isDark: Bool {
        brightness < 0.55
    }

    func mixed(with other: ThemeColorData, amount: Double) -> ThemeColorData {
        let clampedAmount = min(max(amount, 0), 1)
        return ThemeColorData(
            red: red + ((other.red - red) * clampedAmount),
            green: green + ((other.green - green) * clampedAmount),
            blue: blue + ((other.blue - blue) * clampedAmount),
            opacity: opacity + ((other.opacity - opacity) * clampedAmount)
        )
    }

#if canImport(UIKit)
    init(color: Color) {
        let uiColor = UIColor(color)
        var redValue: CGFloat = 0
        var greenValue: CGFloat = 0
        var blueValue: CGFloat = 0
        var alphaValue: CGFloat = 0
        uiColor.getRed(&redValue, green: &greenValue, blue: &blueValue, alpha: &alphaValue)
        self.init(
            red: Double(redValue),
            green: Double(greenValue),
            blue: Double(blueValue),
            opacity: Double(alphaValue)
        )
    }
#endif
}

struct AppThemePalette {
    let backgroundGradient: LinearGradient
    let cardBackground: Color
    let cardStroke: Color
    let panelFill: Color
    let headerFill: Color
    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color
    let shadowColor: Color
    let lunchFill: Color
    let lunchBannerFill: Color
    let lunchBorder: Color
    let accentTint: Color
}

private func adaptiveThemeColor(light: ThemeColorData, dark: ThemeColorData) -> Color {
#if canImport(UIKit)
    Color(uiColor: UIColor { traits in
        let color = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(
            red: CGFloat(color.red),
            green: CGFloat(color.green),
            blue: CGFloat(color.blue),
            alpha: CGFloat(color.opacity)
        )
    })
#else
    light.swiftUIColor
#endif
}

private func adaptiveOrange(lightOpacity: Double, darkOpacity: Double) -> Color {
#if canImport(UIKit)
    Color(uiColor: UIColor { traits in
        UIColor.systemOrange
            .resolvedColor(with: traits)
            .withAlphaComponent(CGFloat(traits.userInterfaceStyle == .dark ? darkOpacity : lightOpacity))
    })
#else
    Color.orange.opacity(lightOpacity)
#endif
}

extension TeacherSettings {
    var preferredThemeColorScheme: ColorScheme? {
        switch themeMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        case .custom:
            return customBackgroundColor.isDark ? .dark : .light
        }
    }

    var appTheme: AppThemePalette {
        switch themeMode {
        case .system:
            return AppThemePalette(
                backgroundGradient: LinearGradient(
                    colors: [
                        adaptiveThemeColor(
                            light: ThemeColorData(red: 0.98, green: 0.95, blue: 0.91, opacity: 1),
                            dark: ThemeColorData(red: 0.12, green: 0.14, blue: 0.19, opacity: 1)
                        ),
                        adaptiveThemeColor(
                            light: ThemeColorData(red: 0.91, green: 0.95, blue: 0.99, opacity: 1),
                            dark: ThemeColorData(red: 0.18, green: 0.22, blue: 0.29, opacity: 1)
                        )
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                cardBackground: adaptiveThemeColor(
                    light: ThemeColorData(red: 1, green: 1, blue: 1, opacity: 0.9),
                    dark: ThemeColorData(red: 1, green: 1, blue: 1, opacity: 0.10)
                ),
                cardStroke: adaptiveThemeColor(
                    light: ThemeColorData(red: 0, green: 0, blue: 0, opacity: 0.06),
                    dark: ThemeColorData(red: 1, green: 1, blue: 1, opacity: 0.09)
                ),
                panelFill: adaptiveThemeColor(
                    light: ThemeColorData(red: 0.95, green: 0.96, blue: 0.98, opacity: 1),
                    dark: ThemeColorData(red: 1, green: 1, blue: 1, opacity: 0.08)
                ),
                headerFill: adaptiveThemeColor(
                    light: ThemeColorData(red: 1, green: 1, blue: 1, opacity: 0.7),
                    dark: ThemeColorData(red: 1, green: 1, blue: 1, opacity: 0.12)
                ),
                primaryText: adaptiveThemeColor(
                    light: ThemeColorData(red: 0.11, green: 0.13, blue: 0.18, opacity: 1),
                    dark: ThemeColorData(red: 1, green: 1, blue: 1, opacity: 0.96)
                ),
                secondaryText: adaptiveThemeColor(
                    light: ThemeColorData(red: 0.11, green: 0.13, blue: 0.18, opacity: 0.65),
                    dark: ThemeColorData(red: 1, green: 1, blue: 1, opacity: 0.72)
                ),
                tertiaryText: adaptiveThemeColor(
                    light: ThemeColorData(red: 0.11, green: 0.13, blue: 0.18, opacity: 0.45),
                    dark: ThemeColorData(red: 1, green: 1, blue: 1, opacity: 0.50)
                ),
                shadowColor: adaptiveThemeColor(
                    light: ThemeColorData(red: 0, green: 0, blue: 0, opacity: 0.06),
                    dark: ThemeColorData(red: 0, green: 0, blue: 0, opacity: 0.28)
                ),
                lunchFill: adaptiveThemeColor(
                    light: ThemeColorData(red: 0.99, green: 0.95, blue: 0.83, opacity: 1),
                    dark: ThemeColorData(red: 0.33, green: 0.28, blue: 0.17, opacity: 1)
                ),
                lunchBannerFill: adaptiveThemeColor(
                    light: ThemeColorData(red: 0.99, green: 0.96, blue: 0.87, opacity: 1),
                    dark: ThemeColorData(red: 0.40, green: 0.32, blue: 0.18, opacity: 1)
                ),
                lunchBorder: adaptiveOrange(lightOpacity: 0.18, darkOpacity: 0.28),
                accentTint: Color.orange
            )
        case .light:
            return AppThemePalette(
                backgroundGradient: LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.95, blue: 0.91),
                        Color(red: 0.91, green: 0.95, blue: 0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                cardBackground: Color.white.opacity(0.9),
                cardStroke: Color.black.opacity(0.06),
                panelFill: Color(red: 0.95, green: 0.96, blue: 0.98),
                headerFill: Color.white.opacity(0.7),
                primaryText: Color(red: 0.11, green: 0.13, blue: 0.18),
                secondaryText: Color(red: 0.11, green: 0.13, blue: 0.18).opacity(0.65),
                tertiaryText: Color(red: 0.11, green: 0.13, blue: 0.18).opacity(0.45),
                shadowColor: Color.black.opacity(0.06),
                lunchFill: Color(red: 0.99, green: 0.95, blue: 0.83),
                lunchBannerFill: Color(red: 0.99, green: 0.96, blue: 0.87),
                lunchBorder: Color.orange.opacity(0.18),
                accentTint: Color.orange
            )
        case .dark:
            return AppThemePalette(
                backgroundGradient: LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.14, blue: 0.19),
                        Color(red: 0.18, green: 0.22, blue: 0.29)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                cardBackground: Color.white.opacity(0.10),
                cardStroke: Color.white.opacity(0.09),
                panelFill: Color.white.opacity(0.08),
                headerFill: Color.white.opacity(0.12),
                primaryText: Color.white.opacity(0.96),
                secondaryText: Color.white.opacity(0.72),
                tertiaryText: Color.white.opacity(0.50),
                shadowColor: Color.black.opacity(0.28),
                lunchFill: Color(red: 0.33, green: 0.28, blue: 0.17),
                lunchBannerFill: Color(red: 0.40, green: 0.32, blue: 0.18),
                lunchBorder: Color.orange.opacity(0.28),
                accentTint: Color.orange
            )
        case .custom:
            let background = customBackgroundColor
            let text = customTextColor
            let contrastBase = background.isDark ? ThemeColorData.white : ThemeColorData.black
            let card = background.mixed(with: contrastBase, amount: background.isDark ? 0.12 : 0.06)
            let panel = background.mixed(with: contrastBase, amount: background.isDark ? 0.18 : 0.10)
            let header = background.mixed(with: contrastBase, amount: background.isDark ? 0.24 : 0.14)
            let lunch = background.mixed(with: .lunchAccent, amount: 0.20)
            let lunchBanner = background.mixed(with: .lunchAccent, amount: 0.28)

            return AppThemePalette(
                backgroundGradient: LinearGradient(
                    colors: [
                        background.mixed(with: contrastBase, amount: background.isDark ? 0.05 : 0.02).swiftUIColor,
                        background.mixed(with: contrastBase, amount: background.isDark ? 0.14 : 0.08).swiftUIColor
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                cardBackground: card.swiftUIColor.opacity(0.94),
                cardStroke: text.swiftUIColor.opacity(0.16),
                panelFill: panel.swiftUIColor.opacity(0.95),
                headerFill: header.swiftUIColor.opacity(0.95),
                primaryText: text.swiftUIColor,
                secondaryText: text.swiftUIColor.opacity(0.72),
                tertiaryText: text.swiftUIColor.opacity(0.52),
                shadowColor: Color.black.opacity(background.isDark ? 0.24 : 0.10),
                lunchFill: lunch.swiftUIColor.opacity(0.95),
                lunchBannerFill: lunchBanner.swiftUIColor.opacity(0.95),
                lunchBorder: text.swiftUIColor.opacity(0.20),
                accentTint: text.swiftUIColor
            )
        }
    }
}

struct AppCard<Content: View>: View {
    @EnvironmentObject private var store: TimetableStore
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let theme = store.settings.appTheme

        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(theme.primaryText)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(theme.cardBackground)
                    .shadow(color: theme.shadowColor, radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(theme.cardStroke, lineWidth: 1)
            )
    }
}

struct ColorSwatchPicker: View {
    @EnvironmentObject private var store: TimetableStore
    @Binding var selectedColor: TimetableColor

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        let theme = store.settings.appTheme

        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(TimetableColor.allCases) { color in
                Button {
                    selectedColor = color
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(color.tintGradient)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? theme.primaryText : Color.clear, lineWidth: 2)
                            )

                        Text(color.title)
                            .font(.caption)
                            .foregroundStyle(theme.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedColor == color ? color.swiftUIColor.opacity(0.18) : theme.panelFill)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PeriodGridCell: View {
    @EnvironmentObject private var store: TimetableStore
    let entry: TimetableEntry?
    let width: CGFloat
    var isTemporary = false
    var isDropTargeted = false
    var themeOverride: AppThemePalette?

    var body: some View {
        let theme = themeOverride ?? store.settings.appTheme

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cellFill(theme: theme))

            VStack(alignment: .leading, spacing: 6) {
                if let entry {
                    Text(entry.subject)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(2)
                    Text(entry.className.isEmpty ? entry.classroomDisplayText : entry.className)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(10)

            if isTemporary {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(entry?.color.swiftUIColor ?? theme.accentTint)
                    .padding(7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .accessibilityLabel("임시 변경된 수업")
            }
        }
        .frame(width: width, height: 80)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cellStroke(theme: theme), lineWidth: isDropTargeted ? 2 : 1)
        )
        .scaleEffect(isDropTargeted ? 1.02 : 1)
        .animation(.easeInOut(duration: 0.16), value: isDropTargeted)
        .accessibilityHint(entry == nil ? "수업을 이 칸으로 끌어놓아 임시 이동합니다." : "수업을 다른 칸으로 끌어 임시 이동할 수 있습니다.")
    }

    private func cellFill(theme: AppThemePalette) -> Color {
        if isDropTargeted {
            return theme.accentTint.opacity(0.16)
        }

        return entry?.color.swiftUIColor.opacity(0.18) ?? theme.panelFill
    }

    private func cellStroke(theme: AppThemePalette) -> Color {
        if isDropTargeted {
            return theme.accentTint.opacity(0.82)
        }

        return entry?.color.swiftUIColor.opacity(0.35) ?? theme.cardStroke
    }
}
