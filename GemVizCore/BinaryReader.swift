import Foundation

public class BinaryReader {
    private let data: Data
    private(set) var offset: Int = 0

    public init(data: Data) {
        self.data = data
    }

    public var bytesRemaining: Int {
        return data.count - offset
    }

    public var isAtEnd: Bool {
        return offset >= data.count
    }

    public func peek<T>(_ type: T.Type) -> T? where T: FixedWidthInteger {
        guard offset + MemoryLayout<T>.size <= data.count else { return nil }
        return data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: offset, as: T.self)
        }
    }

    public func readUInt8() -> UInt8? {
        guard offset < data.count else { return nil }
        let value = data[offset]
        offset += 1
        return value
    }

    public func readInt32() -> Int32? {
        guard offset + 4 <= data.count else { return nil }
        let value = data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: offset, as: Int32.self)
        }
        offset += 4
        return Int32(littleEndian: value)
    }

    public func readUInt32() -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        let value = data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
        }
        offset += 4
        return UInt32(littleEndian: value)
    }

    public func readDouble() -> Double? {
        guard offset + 8 <= data.count else { return nil }
        let bits = data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: offset, as: UInt64.self)
        }
        offset += 8
        return Double(bitPattern: UInt64(littleEndian: bits))
    }

    public func readFloat() -> Float? {
        guard offset + 4 <= data.count else { return nil }
        let bits = data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
        }
        offset += 4
        return Float(bitPattern: UInt32(littleEndian: bits))
    }

    public func readBytes(count: Int) -> Data? {
        guard offset + count <= data.count else { return nil }
        let result = data[offset..<offset + count]
        offset += count
        return Data(result)
    }

    public func readString(length: Int) -> String? {
        guard let bytes = readBytes(count: length) else { return nil }
        return String(data: bytes, encoding: .ascii)?.trimmingCharacters(in: .controlCharacters)
    }

    public func skip(_ count: Int) {
        offset = min(offset + count, data.count)
    }

    public func seek(to position: Int) {
        offset = max(0, min(position, data.count))
    }
}
