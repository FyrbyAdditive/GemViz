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
        updateEdgeVisibility(in: scnView.scene)
    }

    private func updateMaterials(in scene: SCNScene?) {
        guard let scene = scene else { return }

        let settings = GemSettings.shared
        let opacity = settings.surfaceOpacity
        let reflectivity = settings.surfaceReflectivity
        let baseColor = settings.surfaceColor

        // Update gem node materials
        if let gemNode = scene.rootNode.childNode(withName: "gemNode", recursively: false),
           let geometry = gemNode.geometry {
            for material in geometry.materials {
                let colorWithAlpha = baseColor.withAlphaComponent(CGFloat(opacity))
                material.diffuse.contents = colorWithAlpha
                material.shininess = CGFloat(reflectivity * 0.9 + 0.1)
                material.reflective.contents = NSColor(white: CGFloat(reflectivity * 0.5), alpha: 1.0)
                material.fresnelExponent = CGFloat(1.0 + reflectivity * 4.0)
            }
        }

        // Update edge node materials
        if let edgeNode = scene.rootNode.childNode(withName: "edgeNode", recursively: false) {
            let edgeColor = settings.edgeColor
            let edgeOpacity = settings.edgeOpacity

            edgeNode.enumerateChildNodes { node, _ in
                guard let geometry = node.geometry else { return }
                for material in geometry.materials {
                    let colorWithAlpha = edgeColor.withAlphaComponent(CGFloat(edgeOpacity))
                    material.diffuse.contents = colorWithAlpha
                    let emissionColor = edgeColor.withAlphaComponent(CGFloat(edgeOpacity * 0.3))
                    material.emission.contents = emissionColor
                }
            }
        }
    }

    private func updateEdgeVisibility(in scene: SCNScene?) {
        guard let scene = scene else { return }

        let settings = GemSettings.shared

        if let edgeNode = scene.rootNode.childNode(withName: "edgeNode", recursively: false) {
            edgeNode.isHidden = !settings.edgeEnabled
        }
    }
}
