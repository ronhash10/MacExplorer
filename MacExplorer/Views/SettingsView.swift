import SwiftUI

/// App preferences / settings view.
struct SettingsView: View {
    @AppStorage("showHiddenFiles") private var showHiddenFiles = false
    @AppStorage("showPreview") private var showPreview = true

    var body: some View {
        Form {
            Toggle("Show Hidden Files", isOn: $showHiddenFiles)
                .onChange(of: showHiddenFiles) {
                    NotificationCenter.default.post(name: .settingsChanged, object: nil)
                }
            Toggle("Show Preview Pane", isOn: $showPreview)
                .onChange(of: showPreview) {
                    NotificationCenter.default.post(name: .settingsChanged, object: nil)
                }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 150)
        .navigationTitle("Settings")
    }
}
