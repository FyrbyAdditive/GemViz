import Foundation
import SceneKit
import simd

public class GemSceneBuilder {

    public static func build(from gem: GemFile) -> SCNScene {
        let scene = SCNScene()

        // Create gem geometry node
        let gemNode = createGemNode(facets: gem.facets)
        gemNode.name = "gemNode"
        scene.rootNode.addChildNode(gemNode)

        // Create edge wireframe
        if GemSettings.shared.edgeEnabled {
            let edgeNode = createEdgeNode(facets: gem.facets)
            edgeNode.name = "edgeNode"
            scene.rootNode.addChildNode(edgeNode)
        }

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

    // MARK: - Edge Wireframe

    private static func createEdgeNode(facets: [GemFacet]) -> SCNNode {
        let containerNode = SCNNode()
        containerNode.name = "edgeNode"

        // Collect unique edges
        var edgeSet = Set<Edge>()
        for facet in facets {
            let vertices = facet.vertices
            guard vertices.count >= 2 else { continue }

            for i in 0..<vertices.count {
                let v1 = vertices[i]
                let v2 = vertices[(i + 1) % vertices.count]
                edgeSet.insert(Edge(v1: v1, v2: v2))
            }
        }

        // Create geometry for all edges as a single mesh for performance
        let baseRadius: CGFloat = 0.0006  // Fixed edge thickness

        var allVertices: [SCNVector3] = []
        var allNormals: [SCNVector3] = []
        var allIndices: [UInt32] = []
        let segments = 6

        for edge in edgeSet {
            let startX = CGFloat(edge.v1.x)
            let startY = CGFloat(edge.v1.y)
            let startZ = CGFloat(edge.v1.z)
            let endX = CGFloat(edge.v2.x)
            let endY = CGFloat(edge.v2.y)
            let endZ = CGFloat(edge.v2.z)

            // Calculate direction and length
            let dx = endX - startX
            let dy = endY - startY
            let dz = endZ - startZ
            let length = sqrt(dx*dx + dy*dy + dz*dz)

            guard length > 0.0001 else { continue }

            // Create basis vectors for the cylinder
            let dirX = dx/length
            let dirY = dy/length
            let dirZ = dz/length

            // Find a perpendicular vector
            var perpX: CGFloat
            var perpY: CGFloat
            var perpZ: CGFloat
            if abs(dirY) < 0.9 {
                perpX = -dirZ
                perpY = 0
                perpZ = dirX
            } else {
                perpX = 1
                perpY = 0
                perpZ = 0
            }
            let perpLen = sqrt(perpX*perpX + perpY*perpY + perpZ*perpZ)
            perpX /= perpLen
            perpY /= perpLen
            perpZ /= perpLen

            // Cross product for second perpendicular
            let perp2X = dirY * perpZ - dirZ * perpY
            let perp2Y = dirZ * perpX - dirX * perpZ
            let perp2Z = dirX * perpY - dirY * perpX

            let baseIndex = UInt32(allVertices.count)

            // Generate cylinder vertices
            for ring in 0...1 {
                let ringX = ring == 0 ? startX : endX
                let ringY = ring == 0 ? startY : endY
                let ringZ = ring == 0 ? startZ : endZ

                for seg in 0..<segments {
                    let angle = CGFloat(seg) / CGFloat(segments) * 2 * CGFloat.pi
                    let cosA = cos(angle)
                    let sinA = sin(angle)

                    let nx = perpX * cosA + perp2X * sinA
                    let ny = perpY * cosA + perp2Y * sinA
                    let nz = perpZ * cosA + perp2Z * sinA
                    let normal = SCNVector3(nx, ny, nz)

                    let vx = ringX + nx * baseRadius
                    let vy = ringY + ny * baseRadius
                    let vz = ringZ + nz * baseRadius
                    let vertex = SCNVector3(vx, vy, vz)

                    allVertices.append(vertex)
                    allNormals.append(normal)
                }
            }

            // Generate indices for cylinder
            for seg in 0..<segments {
                let nextSeg = (seg + 1) % segments
                let i0 = baseIndex + UInt32(seg)
                let i1 = baseIndex + UInt32(nextSeg)
                let i2 = baseIndex + UInt32(segments + seg)
                let i3 = baseIndex + UInt32(segments + nextSeg)

                allIndices.append(contentsOf: [i0, i2, i1])
                allIndices.append(contentsOf: [i1, i2, i3])
            }
        }

        guard !allVertices.isEmpty else {
            return containerNode
        }

        let vertexSource = SCNGeometrySource(vertices: allVertices)
        let normalSource = SCNGeometrySource(normals: allNormals)
        let element = SCNGeometryElement(indices: allIndices, primitiveType: .triangles)

        let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
        geometry.materials = [createEdgeMaterial()]

        let meshNode = SCNNode(geometry: geometry)
        meshNode.renderingOrder = 100  // Render after gem surfaces
        containerNode.addChildNode(meshNode)

        return containerNode
    }

    public static func createEdgeMaterial() -> SCNMaterial {
        let settings = GemSettings.shared
        let material = SCNMaterial()

        material.lightingModel = .blinn

        let baseColor = settings.edgeColor
        let colorWithAlpha = baseColor.withAlphaComponent(CGFloat(settings.edgeOpacity))
        material.diffuse.contents = colorWithAlpha

        // Subtle specular for a soft sheen
        material.specular.contents = NSColor(white: 0.3, alpha: 1.0)
        material.shininess = 0.3

        // Soft emission for a gentle glow effect
        let emissionColor = baseColor.withAlphaComponent(CGFloat(settings.edgeOpacity * 0.3))
        material.emission.contents = emissionColor

        material.isDoubleSided = true
        material.blendMode = .alpha
        material.transparencyMode = .singleLayer
        material.writesToDepthBuffer = true
        material.readsFromDepthBuffer = true

        return material
    }

    // Edge structure for deduplication
    private struct Edge: Hashable {
        let v1: SIMD3<Float>
        let v2: SIMD3<Float>

        init(v1: SIMD3<Float>, v2: SIMD3<Float>) {
            // Normalize edge direction for consistent hashing
            if v1.x < v2.x || (v1.x == v2.x && v1.y < v2.y) || (v1.x == v2.x && v1.y == v2.y && v1.z < v2.z) {
                self.v1 = v1
                self.v2 = v2
            } else {
                self.v1 = v2
                self.v2 = v1
            }
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(v1.x)
            hasher.combine(v1.y)
            hasher.combine(v1.z)
            hasher.combine(v2.x)
            hasher.combine(v2.y)
            hasher.combine(v2.z)
        }

        static func == (lhs: Edge, rhs: Edge) -> Bool {
            return lhs.v1 == rhs.v1 && lhs.v2 == rhs.v2
        }
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
