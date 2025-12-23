import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL

    private let githubURL = URL(string: "https://github.com/FyrbyAdditive/GemViz")!

    var body: some View {
        VStack(spacing: 0) {
            // Top gradient header with logo
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.15),
                        Color(red: 0.05, green: 0.05, blue: 0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 16) {
                    // App icon
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 96, height: 96)
                        .shadow(color: .black.opacity(0.5), radius: 10, y: 5)

                    // App name with gradient text
                    Text("GemViz")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(white: 0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Version
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text("Version \(version) (\(build))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(white: 0.6))
                    }
                }
                .padding(.vertical, 30)
            }
            .frame(height: 200)

            // Main content
            VStack(spacing: 20) {
                // Description
                Text("3D visualization for GemCAD design files")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Divider()
                    .padding(.horizontal, 40)

                // FAME Logo and company info
                VStack(spacing: 12) {
                    Image("FAMELogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 40)

                    Text("Fyrby Additive Manufacturing & Engineering")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                // GitHub link button
                Button(action: {
                    openURL(githubURL)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 12))
                        Text("View on GitHub")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }

                Spacer()

                // Copyright
                Text("Copyright \u{00A9} 2025 Timothy Ellis")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.5))

                Text("Fyrby Additive Manufacturing & Engineering")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.5))
                    .padding(.bottom, 16)
            }
            .padding(.top, 20)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 320, height: 480)
    }
}

#Preview {
    AboutView()
}
