package com.macroideco.companion.protocol

import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Cryptographic security utilities for the Macroid Eco Companion Protocol.
 * Matching the macOS CompanionSecurity implementation byte-for-byte.
 */
object CompanionSecurity {
    private val secureRandom = SecureRandom()

    fun generateNonce(byteCount: Int = 16): String {
        val bytes = ByteArray(byteCount)
        secureRandom.nextBytes(bytes)
        return bytes.joinToString("") { "%02x".format(it) }
    }

    /**
     * Derives a 6-digit Short Authentication String (SAS) from client & server nonces.
     * Formats as "123 456" for side-by-side user visual confirmation.
     */
    fun computeSAS(clientNonce: String, serverNonce: String, salt: String): String {
        val input = "$clientNonce:$serverNonce:$salt"
        val md = MessageDigest.getInstance("SHA-256")
        val hash = md.digest(input.toByteArray(Charsets.UTF_8))

        // Take first 4 bytes as unsigned big-endian 32-bit int
        val b0 = (hash[0].toInt() and 0xFF).toLong()
        val b1 = (hash[1].toInt() and 0xFF).toLong()
        val b2 = (hash[2].toInt() and 0xFF).toLong()
        val b3 = (hash[3].toInt() and 0xFF).toLong()

        val value = (b0 shl 24) or (b1 shl 16) or (b2 shl 8) or b3
        val code = (value % 1_000_000L).toInt()
        val formatted = "%06d".format(code)
        return "${formatted.substring(0, 3)} ${formatted.substring(3)}"
    }

    /**
     * Computes HMAC-SHA256 signature
     */
    fun computeHMAC(message: String, key: String): String {
        val secretKeySpec = SecretKeySpec(key.toByteArray(Charsets.UTF_8), "HmacSHA256")
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(secretKeySpec)
        val hmacBytes = mac.doFinal(message.toByteArray(Charsets.UTF_8))
        return hmacBytes.joinToString("") { "%02x".format(it) }
    }

    /**
     * Constant time string comparison to prevent timing attacks
     */
    fun secureCompare(a: String, b: String): Boolean {
        val aBytes = a.toByteArray(Charsets.UTF_8)
        val bBytes = b.toByteArray(Charsets.UTF_8)
        return MessageDigest.isEqual(aBytes, bBytes)
    }
}
