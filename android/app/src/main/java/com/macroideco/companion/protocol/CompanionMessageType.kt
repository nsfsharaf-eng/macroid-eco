package com.macroideco.companion.protocol

/**
 * Defines wire-level message types for the Macroid Eco Companion Protocol.
 * Values match the macOS client exactly.
 */
enum class CompanionMessageType(val code: Byte) {
    // Pairing Handshake (0x01 - 0x0F)
    PAIR_REQUEST(0x01),
    PAIR_CHALLENGE(0x02),
    PAIR_CONFIRM(0x03),
    PAIR_SUCCESS(0x04),
    PAIR_FAILED(0x05),

    // Session Authentication (0x10 - 0x1F)
    AUTH_REQUEST(0x10),
    AUTH_SUCCESS(0x11),
    AUTH_FAILED(0x12),

    // Heartbeat Keep-Alive (0x20 - 0x2F)
    PING(0x20),
    PONG(0x21),

    // Device Telemetry (0x30 - 0x3F)
    DEVICE_STATUS(0x30),

    // Notifications (0x40 - 0x4F)
    NOTIFICATION_POSTED(0x40),
    NOTIFICATION_REMOVED(0x41),
    NOTIFICATION_ACTION(0x42),

    // SMS & Messaging (0x50 - 0x5F)
    SMS_RECEIVED(0x50),
    SMS_SEND_REQUEST(0x51),
    SMS_SEND_RESULT(0x52),

    // Telephony & Calls (0x60 - 0x6F)
    CALL_STATE_CHANGED(0x60),

    // Clipboard Synchronization (0x70 - 0x7F)
    CLIPBOARD_SYNC(0x70),

    // Termination (0xFF)
    DISCONNECT(0xFF.toByte());

    companion object {
        private val map = entries.associateBy { it.code }
        fun fromCode(code: Byte): CompanionMessageType? = map[code]
    }
}
