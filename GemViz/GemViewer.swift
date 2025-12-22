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
        // Rebuild scene when refresh is triggered (settings changed)
        scnView.scene = GemSceneBuilder.build(from: gemFile)

        // Restore camera point of view
        if let cameraNode = scnView.scene?.rootNode.childNodes.first(where: { $0.camera != nil }) {
            scnView.pointOfView = cameraNode
        }
    }
}
