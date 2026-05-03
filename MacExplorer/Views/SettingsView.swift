import SwiftUI

/// App preferences / settings view.
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Toggle("Show Hidden Files", isOn: Binding(
                get: { appState.showHiddenFiles },
                set: {
                    appState.showHiddenFiles = $0
                    appState.refreshCurrentTab()
                }
            ))

            Toggle("Show Preview Pane", isOn: Binding(
                get: { appState.showPreview },
                set: { appState.showPreview = $0 }
            ))
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 150)
        .navigationTitle("Settings")
    }
}
