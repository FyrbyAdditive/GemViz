import Foundation
import simd

public struct GemFile {
    public let facets: [GemFacet]
    public let metadata: GemMetadata
    public let uniqueVertices: [SIMD3<Float>]

    public init(facets: [GemFacet], metadata: GemMetadata) {
        self.facets = facets
        self.metadata = metadata
        self.uniqueVertices = Self.extractUniqueVertices(from: facets)
    }

    private static func extractUniqueVertices(from facets: [GemFacet]) -> [SIMD3<Float>] {
        var seen = Set<VertexKey>()
        var unique: [SIMD3<Float>] = []

        for facet in facets {
            for vertex in facet.vertices {
                let key = VertexKey(vertex)
                if !seen.contains(key) {
                    seen.insert(key)
                    unique.append(vertex)
                }
            }
        }

        return unique
    }

    // Hashable wrapper for SIMD3<Float> with tolerance
    private struct VertexKey: Hashable {
        let x: Int
        let y: Int
        let z: Int

        init(_ v: SIMD3<Float>) {
            // Quantize to 4 decimal places for deduplication
            // Handle NaN/Inf by clamping to reasonable range
            func safeInt(_ f: Float) -> Int {
                guard f.isFinite else { return 0 }
                let clamped = max(-1e6, min(1e6, f))
                return Int((clamped * 10000).rounded())
            }
            x = safeInt(v.x)
            y = safeInt(v.y)
            z = safeInt(v.z)
        }
    }
}

public struct GemFacet {
    public let normal: SIMD3<Float>
    public let label: String
    public let instruction: String
    public let vertices: [SIMD3<Float>]

    public init(normal: SIMD3<Float>, label: String, instruction: String, vertices: [SIMD3<Float>]) {
        self.normal = normal
        self.label = label
        self.instruction = instruction
        self.vertices = vertices
    }

    public enum FacetType: String {
        case pavilion = "P"
        case girdle = "G"
        case crown = "C"
        case table = "T"
    }

    public var facetType: FacetType? {
        guard let first = label.first else { return nil }
        return FacetType(rawValue: String(first))
    }
}

public struct GemMetadata {
    public let symmetryFolds: Int
    public let symmetryMirror: Bool
    public let refractiveIndex: Double
    public let gearLocationAngle: Double
    public let title: String
    public let author: String
    public let description: String

    public init(
        symmetryFolds: Int = 1,
        symmetryMirror: Bool = false,
        refractiveIndex: Double = 1.54,
        gearLocationAngle: Double = 0,
        title: String = "",
        author: String = "",
        description: String = ""
    ) {
        self.symmetryFolds = symmetryFolds
        self.symmetryMirror = symmetryMirror
        self.refractiveIndex = refractiveIndex
        self.gearLocationAngle = gearLocationAngle
        self.title = title
        self.author = author
        self.description = description
    }
}
