package com.macroideco.companion.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import com.macroideco.companion.protocol.CompanionMessageType
import com.macroideco.companion.protocol.CompanionPacket
import com.macroideco.companion.protocol.SmsMessagePayload
import com.macroideco.companion.service.CompanionServerService
import java.util.UUID

/**
 * BroadcastReceiver for incoming SMS events.
 * Forwards incoming message details to the connected Mac client.
 */
class SmsBroadcastReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "MacroidSmsReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isNullOrEmpty()) return

            val sender = messages[0].displayOriginatingAddress ?: "Unknown"
            val body = messages.joinToString("") { it.displayMessageBody ?: "" }
            val timestamp = messages[0].timestampMillis

            val payload = SmsMessagePayload(
                id = UUID.randomUUID().toString(),
                threadId = "0",
                senderAddress = sender,
                body = body,
                timestamp = timestamp
            )

            val packet = CompanionPacket(
                type = CompanionMessageType.SMS_RECEIVED,
                payload = payload.toJson().toString().toByteArray(Charsets.UTF_8)
            )

            CompanionServerService.instance?.sendPacket(packet)
            Log.d(TAG, "Forwarded incoming SMS from $sender")
        } catch (e: Exception) {
            Log.w(TAG, "Error handling incoming SMS", e)
        }
    }
}
