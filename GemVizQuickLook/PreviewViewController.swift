import Cocoa
import QuickLookUI
import SceneKit
import GemVizCore

class PreviewViewController: NSViewController, QLPreviewingController {

    private var scnView: SCNView!

    override func loadView() {
        scnView = SCNView()
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = NSColor(white: 0.12, alpha: 1.0)
        scnView.antialiasingMode = .multisampling4X
        self.view = scnView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let data = try Data(contentsOf: url)
                let gem = try GemParser.parse(data: data)

                // GemSceneBuilder reads from GemSettings.shared (App Group)
                // Settings configured in main app are automatically used here
                let scene = GemSceneBuilder.build(from: gem)

                DispatchQueue.main.async {
                    guard let self = self else {
                        handler(nil)
                        return
                    }

                    self.scnView.scene = scene

                    // Set point of view to the camera in the scene
                    if let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }) {
                        self.scnView.pointOfView = cameraNode
                    }

                    handler(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    handler(error)
                }
            }
        }
    }
}
