import Foundation

/// Binary packet framing for the Macroid Eco Companion Protocol.
///
/// Header Layout (12 bytes fixed):
/// ```
/// +---------------------------------------------------------------+
/// | 0..3: Magic ('MECO' = 0x4D45434F)                             |
/// +---------------+---------------+-------------------------------+
/// | 4: Version(1) | 5: Type (1)   | 6..7: Flags (2, Big-Endian)   |
/// +---------------+---------------+-------------------------------+
/// | 8..11: Payload Length (4 bytes, Big-Endian UInt32)             |
/// +---------------------------------------------------------------+
/// | 12..N: Payload Bytes (UTF-8 JSON string or binary)             |
/// +---------------------------------------------------------------+
/// ```
public struct CompanionPacket: Sendable, Equatable {
    public static let magicBytes: [UInt8] = [0x4D, 0x45, 0x43, 0x4F] // "MECO"
    public static let currentVersion: UInt8 = 0x01
    public static let headerSize: Int = 12
    public static let maxPayloadSize: Int = 16 * 1024 * 1024 // 16 MB safety limit

    public let version: UInt8
    public let type: CompanionMessageType
    public let flags: UInt16
    public let payload: Data

    public init(
        type: CompanionMessageType,
        flags: UInt16 = 0,
        payload: Data = Data(),
        version: UInt8 = CompanionPacket.currentVersion
    ) {
        self.version = version
        self.type = type
        self.flags = flags
        self.payload = payload
    }

    /// Convenience initializer with an encodable payload converted to JSON Data
    public init<T: Encodable>(
        type: CompanionMessageType,
        payloadModel: T,
        flags: UInt16 = 0,
        version: UInt8 = CompanionPacket.currentVersion
    ) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(payloadModel)
        self.init(type: type, flags: flags, payload: data, version: version)
    }

    /// Serializes the packet into continuous binary wire bytes
    public func serialize() -> Data {
        var data = Data(capacity: CompanionPacket.headerSize + payload.count)
        data.append(contentsOf: CompanionPacket.magicBytes)
        data.append(version)
        data.append(type.rawValue)
        
        var beFlags = flags.bigEndian
        data.append(Data(bytes: &beFlags, count: MemoryLayout<UInt16>.size))
        
        var beLength = UInt32(payload.count).bigEndian
        data.append(Data(bytes: &beLength, count: MemoryLayout<UInt32>.size))
        
        data.append(payload)
        return data
    }

    /// Attempts to parse a packet from an incoming stream buffer.
    ///
    /// - Returns: `(packet, bytesConsumed)` if a complete packet is decoded, or `nil` if more bytes are needed.
    public static func parse(from buffer: Data) throws -> (packet: CompanionPacket, bytesConsumed: Int)? {
        guard buffer.count >= headerSize else {
            return nil
        }

        // Validate Magic Bytes
        for i in 0..<4 {
            guard buffer[buffer.startIndex + i] == magicBytes[i] else {
                throw CompanionProtocolError.invalidMagicBytes
            }
        }

        let version = buffer[buffer.startIndex + 4]
        guard version == currentVersion else {
            throw CompanionProtocolError.unsupportedVersion(version)
        }

        let rawType = buffer[buffer.startIndex + 5]
        guard let type = CompanionMessageType(rawValue: rawType) else {
            throw CompanionProtocolError.unknownMessageType(rawType)
        }

        let flagsStartIndex = buffer.startIndex + 6
        let flags = buffer.subdata(in: flagsStartIndex..<(flagsStartIndex + 2)).withUnsafeBytes {
            $0.load(as: UInt16.self).bigEndian
        }

        let lengthStartIndex = buffer.startIndex + 8
        let payloadLength = buffer.subdata(in: lengthStartIndex..<(lengthStartIndex + 4)).withUnsafeBytes {
            Int($0.load(as: UInt32.self).bigEndian)
        }

        guard payloadLength <= maxPayloadSize else {
            throw CompanionProtocolError.payloadTooLarge(payloadLength)
        }

        let totalPacketSize = headerSize + payloadLength
        guard buffer.count >= totalPacketSize else {
            return nil // Incomplete packet, await more bytes
        }

        let payloadData = buffer.subdata(in: (buffer.startIndex + headerSize)..<(buffer.startIndex + totalPacketSize))
        let packet = CompanionPacket(type: type, flags: flags, payload: payloadData, version: version)
        return (packet, totalPacketSize)
    }

    /// Decodes the packet's payload into a strongly typed Codable model
    public func decodePayload<T: Decodable>(as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(type, from: payload)
    }
}

/// Errors raised during protocol parsing and framing
public enum CompanionProtocolError: Error, LocalizedError, Equatable {
    case invalidMagicBytes
    case unsupportedVersion(UInt8)
    case unknownMessageType(UInt8)
    case payloadTooLarge(Int)
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidMagicBytes:
            return "Corrupted packet: magic bytes did not match 'MECO'."
        case .unsupportedVersion(let v):
            return "Unsupported protocol version: \(v)."
        case .unknownMessageType(let t):
            return "Unknown protocol message type: \(t)."
        case .payloadTooLarge(let size):
            return "Payload exceeds maximum safety limit (\(size) bytes > \(CompanionPacket.maxPayloadSize))."
        case .decodingFailed(let msg):
            return "Failed to decode packet payload: \(msg)"
        }
    }
}
