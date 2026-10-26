import Foundation
import CommonCrypto

/// Cryptographic primitives for pairing challenge-response and message authentication.
public enum CompanionSecurity {
    /// Generates a cryptographically random hex nonce string of given byte length
    public static func generateNonce(byteCount: Int = 16) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        if status == errSecSuccess {
            return bytes.map { String(format: "%02x", $0) }.joined()
        }
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    /// Derives a 6-digit Short Authentication String (SAS) from client and server nonces
    /// for visual confirmation on both the Mac and Android phone screens.
    public static func computeSAS(clientNonce: String, serverNonce: String, salt: String) -> String {
        let input = "\(clientNonce):\(serverNonce):\(salt)"
        guard let data = input.data(using: .utf8) else { return "000 000" }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }

        // Take 4 bytes and convert to a 6-digit integer 000000..999999
        let value = (UInt32(hash[0]) << 24) | (UInt32(hash[1]) << 16) | (UInt32(hash[2]) << 8) | UInt32(hash[3])
        let code = value % 1_000_000
        let codeString = String(format: "%06d", code)
        
        let index3 = codeString.index(codeString.startIndex, offsetBy: 3)
        return "\(codeString[..<index3]) \(codeString[index3...])"
    }

    /// Computes an HMAC-SHA256 signature
    public static func computeHMAC(message: String, key: String) -> String {
        guard let keyData = key.data(using: .utf8),
              let messageData = message.data(using: .utf8) else {
            return ""
        }

        var mac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        keyData.withUnsafeBytes { keyBytes in
            messageData.withUnsafeBytes { msgBytes in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
                    keyBytes.baseAddress,
                    keyData.count,
                    msgBytes.baseAddress,
                    messageData.count,
                    &mac
                )
            }
        }

        return mac.map { String(format: "%02x", $0) }.joined()
    }

    /// Constant-time comparison to prevent timing attacks on token verification
    public static func secureCompare(_ a: String, _ b: String) -> Bool {
        guard let aData = a.data(using: .utf8), let bData = b.data(using: .utf8) else {
            return false
        }
        guard aData.count == bData.count else {
            return false
        }

        var result: UInt8 = 0
        for i in 0..<aData.count {
            result |= aData[i] ^ bData[i]
        }
        return result == 0
    }
}
