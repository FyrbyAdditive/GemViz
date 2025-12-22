import SwiftUI
import GemVizCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var surfaceOpacity: Double
    @State private var surfaceColor: Color

    var onSettingsChanged: () -> Void

    init(onSettingsChanged: @escaping () -> Void) {
        self.onSettingsChanged = onSettingsChanged
        let settings = GemSettings.shared
        _surfaceOpacity = State(initialValue: settings.surfaceOpacity)
        _surfaceColor = State(initialValue: Color(settings.surfaceColor))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(.ultraThinMaterial)

            Divider()

            // Settings form
            Form {
                Section("Surface") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Opacity")
                            Spacer()
                            Text("\(Int(surfaceOpacity * 100))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $surfaceOpacity, in: 0.05...1.0)
                            .onChange(of: surfaceOpacity) { newValue in
                                GemSettings.shared.surfaceOpacity = newValue
                                onSettingsChanged()
                            }
                    }

                    ColorPicker("Color", selection: $surfaceColor, supportsOpacity: false)
                        .onChange(of: surfaceColor) { newValue in
                            GemSettings.shared.surfaceColor = NSColor(newValue)
                            onSettingsChanged()
                        }
                }

                Section {
                    Button("Reset to Defaults") {
                        GemSettings.shared.resetToDefaults()
                        surfaceOpacity = GemSettings.shared.surfaceOpacity
                        surfaceColor = Color(GemSettings.shared.surfaceColor)
                        onSettingsChanged()
                    }
                    .foregroundColor(.red)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 320, height: 280)
    }
}

#Preview {
    SettingsView(onSettingsChanged: {})
}
