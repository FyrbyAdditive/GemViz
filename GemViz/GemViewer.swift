import SwiftUI
import SceneKit
import GemVizCore

struct GemViewer: NSViewRepresentable {
    let gemFile: GemFile
    let refreshTrigger: UUID

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = GemSceneBuilder.build(from: gemFile)
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = NSColor(white: 0.12, alpha: 1.0)
        scnView.antialiasingMode = .multisampling4X

        // Set initial point of view
        if let cameraNode = scnView.scene?.rootNode.childNodes.first(where: { $0.camera != nil }) {
            scnView.pointOfView = cameraNode
        }

        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        // Only update material properties, don't rebuild the scene
        // This preserves the camera position when settings change
        updateMaterials(in: scnView.scene)
    }

    private func updateMaterials(in scene: SCNScene?) {
        guard let scene = scene else { return }

        let settings = GemSettings.shared
        let opacity = settings.surfaceOpacity
        let reflectivity = settings.surfaceReflectivity
        let baseColor = settings.surfaceColor

        // Find all geometry nodes and update their materials
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry,
                  node.light == nil,  // Skip light nodes
                  node.camera == nil  // Skip camera nodes
            else { return }

            for material in geometry.materials {
                // Update color with opacity
                let colorWithAlpha = baseColor.withAlphaComponent(CGFloat(opacity))
                material.diffuse.contents = colorWithAlpha

                // Update reflectivity
                material.shininess = CGFloat(reflectivity * 0.9 + 0.1)
                material.reflective.contents = NSColor(white: CGFloat(reflectivity * 0.5), alpha: 1.0)
                material.fresnelExponent = CGFloat(1.0 + reflectivity * 4.0)
            }
        }
    }
}
