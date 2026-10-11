import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TimetableStore

    var body: some View {
        let theme = store.settings.appTheme

        TabView {
            NavigationStack {
                OverviewTabView()
            }
            .tabItem {
                Label("시간표", systemImage: "tablecells")
            }

            NavigationStack {
                EditorTabView()
            }
            .tabItem {
                Label("입력", systemImage: "square.and.pencil")
            }

            NavigationStack {
                SettingsTabView()
            }
            .tabItem {
                Label("설정", systemImage: "gearshape")
            }
        }
        .tint(theme.accentTint)
        .preferredColorScheme(store.settings.preferredThemeColorScheme)
    }
}
