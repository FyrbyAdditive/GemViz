import Foundation
import SceneKit
import simd

public class GemSceneBuilder {

    public static func build(from gem: GemFile) -> SCNScene {
        let scene = SCNScene()

        // Create gem geometry node
        let gemNode = createGemNode(facets: gem.facets)
        scene.rootNode.addChildNode(gemNode)

        // Setup lighting
        addLighting(to: scene)

        // Add camera
        addCamera(to: scene)

        return scene
    }

    private static func createGemNode(facets: [GemFacet]) -> SCNNode {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [UInt32] = []

        for facet in facets {
            guard facet.vertices.count >= 3 else { continue }

            // Triangulate the facet (fan triangulation from first vertex)
            let baseIndex = UInt32(vertices.count)

            // Calculate face normal from vertices
            let v0 = facet.vertices[0]
            let v1 = facet.vertices[1]
            let v2 = facet.vertices[2]

            let edge1 = v1 - v0
            let edge2 = v2 - v0
            var faceNormal = simd_cross(edge1, edge2)
            let length = simd_length(faceNormal)
            if length > 0 {
                faceNormal /= length
            }

            // Add all vertices
            for vertex in facet.vertices {
                vertices.append(SCNVector3(vertex.x, vertex.y, vertex.z))
                normals.append(SCNVector3(faceNormal.x, faceNormal.y, faceNormal.z))
            }

            // Create triangles using fan triangulation
            for i in 1..<(facet.vertices.count - 1) {
                indices.append(baseIndex)
                indices.append(baseIndex + UInt32(i))
                indices.append(baseIndex + UInt32(i + 1))
            }
        }

        guard !vertices.isEmpty else {
            return SCNNode()
        }

        // Create geometry sources
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)

        // Create geometry element
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)

        // Create geometry
        let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
        geometry.materials = [createGemMaterial()]

        let node = SCNNode(geometry: geometry)
        return node
    }

    private static func createGemMaterial() -> SCNMaterial {
        let settings = GemSettings.shared
        let opacity = settings.surfaceOpacity
        let reflectivity = settings.surfaceReflectivity

        let material = SCNMaterial()

        // Use Blinn-Phong for better transparency support
        material.lightingModel = .blinn

        // Surface color with opacity baked in
        let baseColor = settings.surfaceColor
        let colorWithAlpha = baseColor.withAlphaComponent(CGFloat(opacity))
        material.diffuse.contents = colorWithAlpha

        // Specular highlights for reflective appearance
        // Higher reflectivity = brighter, sharper highlights
        material.specular.contents = NSColor.white
        material.shininess = CGFloat(reflectivity * 0.9 + 0.1)  // 0.1 to 1.0 range

        // Reflective property for environment reflections
        material.reflective.contents = NSColor(white: CGFloat(reflectivity * 0.5), alpha: 1.0)

        // Fresnel effect - makes edges more visible/reflective
        material.fresnelExponent = CGFloat(1.0 + reflectivity * 4.0)

        // Essential for transparent objects
        material.isDoubleSided = true

        // Use proper blending for transparency
        material.blendMode = .alpha
        material.transparencyMode = .dualLayer
        material.writesToDepthBuffer = true
        material.readsFromDepthBuffer = true

        return material
    }

    private static func addLighting(to scene: SCNScene) {
        // Ambient light for base illumination
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 500
        ambientLight.color = NSColor.white

        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        // Key light from above-front
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 800
        keyLight.castsShadow = false

        let keyNode = SCNNode()
        keyNode.light = keyLight
        keyNode.position = SCNVector3(2, 4, 3)
        keyNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyNode)

        // Fill light from opposite side
        let fillLight = SCNLight()
        fillLight.type = .directional
        fillLight.intensity = 400

        let fillNode = SCNNode()
        fillNode.light = fillLight
        fillNode.position = SCNVector3(-2, 2, -2)
        fillNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fillNode)
    }

    private static func addCamera(to scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 45
        cameraNode.camera?.automaticallyAdjustsZRange = true
        cameraNode.position = SCNVector3(0, 0.5, 2.5)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
    }
}
