package com.macroideco.companion.protocol

import org.json.JSONArray
import org.json.JSONObject

// MARK: - Pairing & Authentication Payloads

data class PairRequestPayload(
    val clientName: String,
    val clientOS: String,
    val clientNonce: String,
    val protocolVersion: Int
) {
    companion object {
        fun fromJson(json: JSONObject): PairRequestPayload {
            return PairRequestPayload(
                clientName = json.optString("clientName", "Unknown"),
                clientOS = json.optString("clientOS", "macOS"),
                clientNonce = json.getString("clientNonce"),
                protocolVersion = json.optInt("protocolVersion", 1)
            )
        }
    }
}

data class PairChallengePayload(
    val serverName: String,
    val serverDevice: String,
    val sasCode: String,
    val serverNonce: String,
    val salt: String
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("serverName", serverName)
        put("serverDevice", serverDevice)
        put("sasCode", sasCode)
        put("serverNonce", serverNonce)
        put("salt", salt)
    }
}

data class PairConfirmPayload(
    val clientProof: String,
    val sasConfirmed: Boolean
) {
    companion object {
        fun fromJson(json: JSONObject): PairConfirmPayload {
            return PairConfirmPayload(
                clientProof = json.getString("clientProof"),
                sasConfirmed = json.optBoolean("sasConfirmed", true)
            )
        }
    }
}

data class PairSuccessPayload(
    val authToken: String,
    val serverProof: String
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("authToken", authToken)
        put("serverProof", serverProof)
    }
}

data class AuthRequestPayload(
    val clientName: String,
    val authToken: String,
    val nonce: String
) {
    companion object {
        fun fromJson(json: JSONObject): AuthRequestPayload {
            return AuthRequestPayload(
                clientName = json.optString("clientName", "Macroid Eco"),
                authToken = json.getString("authToken"),
                nonce = json.optString("nonce", "")
            )
        }
    }
}

data class AuthResponsePayload(
    val isSuccess: Boolean,
    val message: String
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("isSuccess", isSuccess)
        put("message", message)
    }
}

// MARK: - Device Telemetry

data class DeviceStatusPayload(
    val batteryLevel: Int,
    val isCharging: Boolean,
    val isPowerSave: Boolean = false,
    val wifiSSID: String? = null,
    val cellularNetwork: String? = null
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("batteryLevel", batteryLevel)
        put("isCharging", isCharging)
        put("isPowerSave", isPowerSave)
        wifiSSID?.let { put("wifiSSID", it) }
        cellularNetwork?.let { put("cellularNetwork", it) }
    }
}

// MARK: - Notification Payload

data class NotificationPayload(
    val id: String,
    val key: String,
    val packageName: String,
    val appName: String,
    val title: String,
    val text: String,
    val subText: String? = null,
    val postTime: Long = System.currentTimeMillis(),
    val isClearable: Boolean = true
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("key", key)
        put("packageName", packageName)
        put("appName", appName)
        put("title", title)
        put("text", text)
        subText?.let { put("subText", it) }
        put("postTime", postTime)
        put("isClearable", isClearable)
        put("actions", JSONArray())
    }
}

// MARK: - SMS Message Payload

data class SmsMessagePayload(
    val id: String,
    val threadId: String,
    val senderAddress: String,
    val senderName: String? = null,
    val body: String,
    val timestamp: Long = System.currentTimeMillis(),
    val isRead: Boolean = false
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("threadId", threadId)
        put("senderAddress", senderAddress)
        senderName?.let { put("senderName", it) }
        put("body", body)
        put("timestamp", timestamp)
        put("isRead", isRead)
    }
}

// MARK: - Call State Payload

data class CallStatePayload(
    val state: String, // "IDLE", "RINGING", "OFFHOOK"
    val incomingNumber: String? = null,
    val callerName: String? = null,
    val timestamp: Long = System.currentTimeMillis()
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("state", state)
        incomingNumber?.let { put("incomingNumber", it) }
        callerName?.let { put("callerName", it) }
        put("timestamp", timestamp)
    }
}

// MARK: - Clipboard Payload

data class ClipboardSyncPayload(
    val text: String,
    val timestamp: Long = System.currentTimeMillis(),
    val sourceDeviceId: String
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("text", text)
        put("timestamp", timestamp)
        put("sourceDeviceId", sourceDeviceId)
    }

    companion object {
        fun fromJson(json: JSONObject): ClipboardSyncPayload {
            return ClipboardSyncPayload(
                text = json.getString("text"),
                timestamp = json.optLong("timestamp", System.currentTimeMillis()),
                sourceDeviceId = json.optString("sourceDeviceId", "Mac")
            )
        }
    }
}
