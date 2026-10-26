package com.macroideco.companion.protocol

import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Binary packet framing for the Macroid Eco Companion Protocol.
 *
 * Header Layout (12 bytes fixed):
 * - 0..3:  Magic ("MECO" = 0x4D45434F)
 * - 4:     Version (1 byte)
 * - 5:     Type (1 byte)
 * - 6..7:  Flags (2 bytes, Big-Endian)
 * - 8..11: Payload Length (4 bytes, Big-Endian UInt32)
 * - 12..N: Payload Bytes (UTF-8 JSON)
 */
data class CompanionPacket(
    val version: Byte = CURRENT_VERSION,
    val type: CompanionMessageType,
    val flags: Short = 0,
    val payload: ByteArray = ByteArray(0)
) {
    companion object {
        val MAGIC_BYTES = byteArrayOf(0x4D, 0x45, 0x43, 0x4F) // "MECO"
        const val CURRENT_VERSION: Byte = 0x01
        const val HEADER_SIZE = 12
        const val MAX_PAYLOAD_SIZE = 16 * 1024 * 1024 // 16 MB safety limit

        @Throws(IOException::class)
        fun readFrom(stream: DataInputStream): CompanionPacket {
            val magic = ByteArray(4)
            stream.readFully(magic)
            if (!magic.contentEquals(MAGIC_BYTES)) {
                throw IOException("Invalid magic bytes in companion packet header.")
            }

            val version = stream.readByte()
            if (version != CURRENT_VERSION) {
                throw IOException("Unsupported companion protocol version: $version")
            }

            val rawType = stream.readByte()
            val type = CompanionMessageType.fromCode(rawType)
                ?: throw IOException("Unknown companion message type: $rawType")

            val flags = stream.readShort()
            val payloadLength = stream.readInt()

            if (payloadLength < 0 || payloadLength > MAX_PAYLOAD_SIZE) {
                throw IOException("Payload length out of bounds: $payloadLength")
            }

            val payload = ByteArray(payloadLength)
            if (payloadLength > 0) {
                stream.readFully(payload)
            }

            return CompanionPacket(version, type, flags, payload)
        }
    }

    @Throws(IOException::class)
    fun writeTo(stream: DataOutputStream) {
        stream.write(MAGIC_BYTES)
        stream.writeByte(version.toInt())
        stream.writeByte(type.code.toInt())
        stream.writeShort(flags.toInt())
        stream.writeInt(payload.size)
        if (payload.isNotEmpty()) {
            stream.write(payload)
        }
        stream.flush()
    }

    fun toByteArray(): ByteArray {
        val buffer = ByteBuffer.allocate(HEADER_SIZE + payload.size).order(ByteOrder.BIG_ENDIAN)
        buffer.put(MAGIC_BYTES)
        buffer.put(version)
        buffer.put(type.code)
        buffer.putShort(flags)
        buffer.putInt(payload.size)
        if (payload.isNotEmpty()) {
            buffer.put(payload)
        }
        return buffer.array()
    }

    fun payloadAsString(): String = String(payload, Charsets.UTF_8)

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as CompanionPacket
        if (version != other.version) return false
        if (type != other.type) return false
        if (flags != other.flags) return false
        if (!payload.contentEquals(other.payload)) return false

        return true
    }

    override fun hashCode(): Int {
        var result = version.toInt()
        result = 31 * result + type.hashCode()
        result = 31 * result + flags.toInt()
        result = 31 * result + payload.contentHashCode()
        return result
    }
}
