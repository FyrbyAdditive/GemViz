import Foundation
import simd

public enum GemParseError: Error, LocalizedError {
    case invalidData
    case unexpectedEndOfFile
    case noFacetsFound

    public var errorDescription: String? {
        switch self {
        case .invalidData: return "Invalid GemCAD file format"
        case .unexpectedEndOfFile: return "Unexpected end of file"
        case .noFacetsFound: return "No facets found in file"
        }
    }
}

public class GemParser {

    public static func parse(data: Data) throws -> GemFile {
        let reader = BinaryReader(data: data)
        var facets: [GemFacet] = []

        // Parse facets until we hit the trailer or EOF
        while reader.bytesRemaining > 32 {
            // Try to detect trailer - it starts with specific pattern
            if isTrailerStart(reader: reader) {
                break
            }

            guard let facet = parseFacet(reader: reader) else {
                // If we can't parse a facet, we've hit the trailer
                break
            }
            facets.append(facet)
        }

        guard !facets.isEmpty else {
            throw GemParseError.noFacetsFound
        }

        // Parse metadata from trailer
        let metadata = parseTrailer(reader: reader)

        // Apply symmetry if specified
        let symmetrizedFacets = applySymmetry(facets: facets, metadata: metadata)

        return GemFile(facets: symmetrizedFacets, metadata: metadata)
    }

    private static func isTrailerStart(reader: BinaryReader) -> Bool {
        // Save position
        let savedOffset = reader.offset

        // Trailer pattern: marker(0), non-zero value, symmetry folds (reasonable range), mirror flag (0/1)
        guard let marker = reader.readInt32(),
              let _ = reader.readInt32(),
              let folds = reader.readInt32(),
              let mirror = reader.readInt32() else {
            reader.seek(to: savedOffset)
            return false
        }

        // Restore position
        reader.seek(to: savedOffset)

        // Check if this looks like a trailer
        // Trailer starts with 0 marker, has reasonable symmetry folds (1-96), and mirror is 0 or 1
        return marker == 0 && folds >= 1 && folds <= 96 && (mirror == 0 || mirror == 1)
    }

    /// Searches for the trailer pattern starting from current position, checking each byte offset
    private static func findTrailerOffset(reader: BinaryReader) -> Int? {
        let startOffset = reader.offset

        // Search up to 32 bytes ahead for valid trailer pattern
        for offset in 0..<32 {
            reader.seek(to: startOffset + offset)

            guard reader.bytesRemaining >= 28 else { break }  // Need at least 28 bytes for trailer header

            guard let marker = reader.readInt32(),
                  let _ = reader.readInt32(),
                  let folds = reader.readInt32(),
                  let mirror = reader.readInt32(),
                  let _ = reader.readInt32(),  // gear
                  let ri = reader.readDouble() else {
                continue
            }

            // Check if this is a valid trailer
            // marker=0, folds 1-96, mirror 0/1, RI between 1.0 and 3.0 (typical for gems)
            if marker == 0 && folds >= 1 && folds <= 96 && (mirror == 0 || mirror == 1) && ri >= 1.0 && ri <= 3.0 {
                reader.seek(to: startOffset + offset)
                return startOffset + offset
            }
        }

        reader.seek(to: startOffset)
        return nil
    }

    private static func parseFacet(reader: BinaryReader) -> GemFacet? {
        let startOffset = reader.offset

        // Read facet normal (3 doubles = 24 bytes)
        guard let nx = reader.readDouble(),
              let ny = reader.readDouble(),
              let nz = reader.readDouble(),
              nx.isFinite, ny.isFinite, nz.isFinite else {
            reader.seek(to: startOffset)
            return nil
        }

        // Check if values look reasonable for a normal vector (magnitude should be ~1 for normalized)
        let normalMag = sqrt(nx*nx + ny*ny + nz*nz)
        guard normalMag > 0.01 && normalMag < 100 else {
            reader.seek(to: startOffset)
            return nil
        }

        let normal = SIMD3<Float>(Float(nx), Float(ny), Float(nz))

        // Read first marker (Int32) - appears before string
        guard let firstMarker = reader.readInt32(), firstMarker != 0 else {
            reader.seek(to: startOffset)
            return nil
        }

        // Read instruction length (1 byte)
        guard let instrLen = reader.readUInt8(), instrLen > 0, instrLen < 200 else {
            reader.seek(to: startOffset)
            return nil
        }

        // Read instruction string
        guard let instrString = reader.readString(length: Int(instrLen)) else {
            reader.seek(to: startOffset)
            return nil
        }

        // Parse label and instruction from the string
        // Format is typically "LABEL\tInstruction" or just "Instruction"
        let (label, instruction) = parseInstructionString(instrString)

        // Read vertices until we hit a zero marker
        var vertices: [SIMD3<Float>] = []

        while true {
            // Read vertex marker
            guard let marker = reader.readInt32() else {
                break
            }

            if marker == 0 {
                // End of vertices for this facet
                break
            }

            // Read vertex coordinates
            guard let x = reader.readDouble(),
                  let y = reader.readDouble(),
                  let z = reader.readDouble(),
                  x.isFinite, y.isFinite, z.isFinite else {
                reader.seek(to: startOffset)
                return nil
            }

            // Validate vertex values are in reasonable range
            guard abs(x) < 1e6 && abs(y) < 1e6 && abs(z) < 1e6 else {
                reader.seek(to: startOffset)
                return nil
            }

            vertices.append(SIMD3<Float>(Float(x), Float(y), Float(z)))
        }

        // A valid facet should have at least 3 vertices
        guard vertices.count >= 3 else {
            reader.seek(to: startOffset)
            return nil
        }

        return GemFacet(normal: normal, label: label, instruction: instruction, vertices: vertices)
    }

    private static func parseInstructionString(_ str: String) -> (label: String, instruction: String) {
        // Check for tab separator between label and instruction
        if let tabIndex = str.firstIndex(of: "\t") {
            let label = String(str[..<tabIndex])
            let instruction = String(str[str.index(after: tabIndex)...])
            return (label, instruction)
        }

        // Check for common label patterns at start (P1, G2, C3, T, etc.)
        let patterns = ["P", "G", "C", "T"]
        for pattern in patterns {
            if str.hasPrefix(pattern) {
                // Find where the number ends
                var labelEnd = str.startIndex
                for (i, char) in str.enumerated() {
                    if i == 0 { continue }
                    if char.isNumber {
                        labelEnd = str.index(str.startIndex, offsetBy: i + 1)
                    } else {
                        break
                    }
                }
                if labelEnd > str.startIndex {
                    let label = String(str[..<labelEnd])
                    let rest = String(str[labelEnd...]).trimmingCharacters(in: .whitespaces)
                    return (label, rest)
                }
            }
        }

        return ("", str)
    }

    private static func parseTrailer(reader: BinaryReader) -> GemMetadata {
        // Search for valid trailer pattern (may be at non-aligned offset)
        guard let _ = findTrailerOffset(reader: reader) else {
            return GemMetadata()
        }

        // Try to parse trailer metadata
        guard let _ = reader.readInt32(),  // marker (0)
              let _ = reader.readInt32(),  // unknown
              let folds = reader.readInt32(),
              let mirror = reader.readInt32() else {
            return GemMetadata()
        }

        // Read gear and angles
        let gear = reader.readInt32() ?? 0
        let refractiveIndex = reader.readDouble() ?? 1.54
        let gearAngle = reader.readDouble() ?? 0

        // Try to read title and description strings from remaining data
        var title = ""
        var author = ""
        var description = ""

        // Read remaining bytes as potential text
        if reader.bytesRemaining > 0 {
            if let textData = reader.readBytes(count: reader.bytesRemaining) {
                let text = String(data: textData, encoding: .ascii) ?? ""
                // Parse the text sections
                let lines = text.components(separatedBy: CharacterSet.newlines)
                    .map { $0.trimmingCharacters(in: .controlCharacters) }
                    .filter { !$0.isEmpty }

                if lines.count > 0 {
                    title = lines[0]
                }
                if lines.count > 1 {
                    author = lines[1]
                }
                if lines.count > 2 {
                    description = lines[2...].joined(separator: " ")
                }
            }
        }

        return GemMetadata(
            symmetryFolds: max(1, Int(folds)),
            symmetryMirror: mirror != 0,
            refractiveIndex: refractiveIndex,
            gearLocationAngle: gearAngle,
            title: title,
            author: author,
            description: description
        )
    }

    private static func applySymmetry(facets: [GemFacet], metadata: GemMetadata) -> [GemFacet] {
        // DEBUG: Temporarily disable all symmetry to check raw facets
        return facets

        // If no symmetry operations needed, return original facets
        guard metadata.symmetryFolds > 1 || metadata.symmetryMirror else { return facets }

        // Check if facets already contain mirror symmetry by looking at centroid distribution
        // If facets exist on both +X and -X sides, mirror is already baked in
        let alreadyMirrored = facetsAlreadyMirrored(facets)

        var result: [GemFacet] = []
        let angleStep = (2.0 * .pi) / Float(metadata.symmetryFolds)

        // Generate all rotations
        for fold in 0..<metadata.symmetryFolds {
            let angle = Float(fold) * angleStep
            let cosA = cos(angle)
            let sinA = sin(angle)

            for facet in facets {
                // Rotate around Y axis
                let rotatedVertices = facet.vertices.map { v -> SIMD3<Float> in
                    SIMD3<Float>(
                        v.x * cosA + v.z * sinA,
                        v.y,
                        -v.x * sinA + v.z * cosA
                    )
                }

                let rotatedNormal = SIMD3<Float>(
                    facet.normal.x * cosA + facet.normal.z * sinA,
                    facet.normal.y,
                    -facet.normal.x * sinA + facet.normal.z * cosA
                )

                result.append(GemFacet(
                    normal: rotatedNormal,
                    label: facet.label,
                    instruction: facet.instruction,
                    vertices: rotatedVertices
                ))
            }
        }

        // Only apply mirror if metadata says so AND facets don't already contain mirrored geometry
        if metadata.symmetryMirror && !alreadyMirrored {
            let mirroredFacets = result.map { facet -> GemFacet in
                let mirroredVertices = facet.vertices.map { v -> SIMD3<Float> in
                    SIMD3<Float>(-v.x, v.y, v.z)
                }
                let mirroredNormal = SIMD3<Float>(-facet.normal.x, facet.normal.y, facet.normal.z)
                return GemFacet(
                    normal: mirroredNormal,
                    label: facet.label,
                    instruction: facet.instruction,
                    vertices: mirroredVertices
                )
            }
            result.append(contentsOf: mirroredFacets)
        }

        return result
    }

    /// Check if facets already contain mirror-symmetric geometry across X=0
    private static func facetsAlreadyMirrored(_ facets: [GemFacet]) -> Bool {
        // Calculate centroids for each facet
        var centroids: [(x: Float, y: Float, z: Float)] = []
        for facet in facets {
            guard !facet.vertices.isEmpty else { continue }
            let cx = facet.vertices.map { $0.x }.reduce(0, +) / Float(facet.vertices.count)
            let cy = facet.vertices.map { $0.y }.reduce(0, +) / Float(facet.vertices.count)
            let cz = facet.vertices.map { $0.z }.reduce(0, +) / Float(facet.vertices.count)
            centroids.append((cx, cy, cz))
        }

        // Count facets on each side of X=0
        let threshold: Float = 0.05
        let positiveX = centroids.filter { $0.x > threshold }.count
        let negativeX = centroids.filter { $0.x < -threshold }.count

        // If we have significant facets on both sides, check if they're mirror pairs
        guard positiveX > 2 && negativeX > 2 else { return false }

        // Check if +X facets have matching -X counterparts
        var matchedPairs = 0
        for c in centroids where c.x > threshold {
            let hasMirror = centroids.contains { other in
                abs(other.x + c.x) < 0.02 &&
                abs(other.y - c.y) < 0.02 &&
                abs(other.z - c.z) < 0.02
            }
            if hasMirror { matchedPairs += 1 }
        }

        // If most +X facets have -X mirrors, symmetry is already baked in
        return matchedPairs >= positiveX - 2
    }
}
