import SwiftUI
import UniformTypeIdentifiers
import GemVizCore

struct ContentView: View {
    @State private var gemFile: GemFile?
    @State private var isDropTargeted = false
    @State private var errorMessage: String?
    @State private var refreshTrigger = UUID()

    var body: some View {
        HSplitView {
            // Left sidebar with controls
            SidebarView(
                gemFile: gemFile,
                onSettingsChanged: { refreshTrigger = UUID() }
            )
            .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)

            // Main content area
            ZStack {
                if let gemFile = gemFile {
                    GemViewer(gemFile: gemFile, refreshTrigger: refreshTrigger)
                        .ignoresSafeArea()

                    // Title overlay
                    VStack {
                        HStack {
                            if !gemFile.metadata.title.isEmpty {
                                Text(gemFile.metadata.title)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            }
                            Spacer()
                        }
                        .padding()

                        Spacer()
                    }
                } else {
                    DropZoneView(isTargeted: isDropTargeted)
                }

                if let error = errorMessage {
                    VStack {
                        Spacer()
                        Text(error)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                            .padding()
                    }
                }
            }
            .frame(minWidth: 400)
            .background(Color(white: 0.12))
        }
        .frame(minWidth: 700, minHeight: 450)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFile)) { _ in
            openFileDialog()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFileURL)) { notification in
            if let url = notification.object as? URL {
                loadGemFile(from: url)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension.lowercased() == "gem" else {
                DispatchQueue.main.async {
                    errorMessage = "Please drop a .gem file"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        errorMessage = nil
                    }
                }
                return
            }

            DispatchQueue.main.async {
                loadGemFile(from: url)
            }
        }

        return true
    }

    private func loadGemFile(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let parsed = try GemParser.parse(data: data)
            gemFile = parsed
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                errorMessage = nil
            }
        }
    }

    private func openFileDialog() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "gem") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            loadGemFile(from: url)
        }
    }
}

struct SidebarView: View {
    let gemFile: GemFile?
    var onSettingsChanged: () -> Void

    @State private var surfaceOpacity: Double
    @State private var surfaceColor: Color
    @State private var surfaceReflectivity: Double

    init(gemFile: GemFile?, onSettingsChanged: @escaping () -> Void) {
        self.gemFile = gemFile
        self.onSettingsChanged = onSettingsChanged
        let settings = GemSettings.shared
        _surfaceOpacity = State(initialValue: settings.surfaceOpacity)
        _surfaceColor = State(initialValue: Color(settings.surfaceColor))
        _surfaceReflectivity = State(initialValue: settings.surfaceReflectivity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Display Settings")
                .font(.headline)
                .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Surface section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Surface")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Opacity")
                                Spacer()
                                Text("\(Int(surfaceOpacity * 100))%")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            .font(.callout)

                            Slider(value: $surfaceOpacity, in: 0.05...1.0)
                                .onChange(of: surfaceOpacity) { _, newValue in
                                    GemSettings.shared.surfaceOpacity = newValue
                                    onSettingsChanged()
                                }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Reflectivity")
                                Spacer()
                                Text("\(Int(surfaceReflectivity * 100))%")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            .font(.callout)

                            Slider(value: $surfaceReflectivity, in: 0.0...1.0)
                                .onChange(of: surfaceReflectivity) { _, newValue in
                                    GemSettings.shared.surfaceReflectivity = newValue
                                    onSettingsChanged()
                                }
                        }

                        ColorPicker("Color", selection: $surfaceColor, supportsOpacity: false)
                            .font(.callout)
                            .onChange(of: surfaceColor) { _, newValue in
                                GemSettings.shared.surfaceColor = NSColor(newValue)
                                onSettingsChanged()
                            }
                    }

                    Divider()

                    // Info section (when file loaded)
                    if let gemFile = gemFile {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Info")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                if !gemFile.metadata.title.isEmpty {
                                    LabeledContent("Title", value: gemFile.metadata.title)
                                }
                                LabeledContent("Facets", value: "\(gemFile.facets.count)")
                                LabeledContent("Vertices", value: "\(gemFile.uniqueVertices.count)")
                                LabeledContent("Symmetry", value: "\(gemFile.metadata.symmetryFolds)-fold\(gemFile.metadata.symmetryMirror ? " + mirror" : "")")
                                LabeledContent("RI", value: String(format: "%.2f", gemFile.metadata.refractiveIndex))
                            }
                            .font(.callout)
                        }

                        Divider()
                    }

                    // Reset button
                    Button(action: resetToDefaults) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Defaults")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .font(.callout)
                }
                .padding()
            }

            Spacer()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func resetToDefaults() {
        GemSettings.shared.resetToDefaults()
        surfaceOpacity = GemSettings.shared.surfaceOpacity
        surfaceColor = Color(GemSettings.shared.surfaceColor)
        surfaceReflectivity = GemSettings.shared.surfaceReflectivity
        onSettingsChanged()
    }
}

struct DropZoneView: View {
    let isTargeted: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 80))
                .foregroundColor(.gray)

            Text("Drop a .gem file here")
                .font(.title2)
                .foregroundColor(.gray)

            Text("or press ⌘O to open")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    isTargeted ? Color.blue : Color.gray.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [10])
                )
                .padding(40)
        )
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
    }
}

#Preview {
    ContentView()
}
