import SwiftUI
import GemVizCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var surfaceOpacity: Double
    @State private var surfaceColor: Color
    @State private var surfaceReflectivity: Double

    var onSettingsChanged: () -> Void

    init(onSettingsChanged: @escaping () -> Void) {
        self.onSettingsChanged = onSettingsChanged
        let settings = GemSettings.shared
        _surfaceOpacity = State(initialValue: settings.surfaceOpacity)
        _surfaceColor = State(initialValue: Color(settings.surfaceColor))
        _surfaceReflectivity = State(initialValue: settings.surfaceReflectivity)
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
                            .onChange(of: surfaceOpacity) { _, newValue in
                                GemSettings.shared.surfaceOpacity = newValue
                                onSettingsChanged()
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Reflectivity")
                            Spacer()
                            Text("\(Int(surfaceReflectivity * 100))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $surfaceReflectivity, in: 0.0...1.0)
                            .onChange(of: surfaceReflectivity) { _, newValue in
                                GemSettings.shared.surfaceReflectivity = newValue
                                onSettingsChanged()
                            }
                    }

                    ColorPicker("Color", selection: $surfaceColor, supportsOpacity: false)
                        .onChange(of: surfaceColor) { _, newValue in
                            GemSettings.shared.surfaceColor = NSColor(newValue)
                            onSettingsChanged()
                        }
                }

                Section {
                    Button("Reset to Defaults") {
                        GemSettings.shared.resetToDefaults()
                        surfaceOpacity = GemSettings.shared.surfaceOpacity
                        surfaceColor = Color(GemSettings.shared.surfaceColor)
                        surfaceReflectivity = GemSettings.shared.surfaceReflectivity
                        onSettingsChanged()
                    }
                    .foregroundColor(.red)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 320, height: 300)
    }
}

#Preview {
    SettingsView(onSettingsChanged: {})
}
