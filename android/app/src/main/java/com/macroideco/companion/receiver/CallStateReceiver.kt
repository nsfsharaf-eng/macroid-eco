package com.macroideco.companion.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import android.util.Log
import com.macroideco.companion.protocol.CallStatePayload
import com.macroideco.companion.protocol.CompanionMessageType
import com.macroideco.companion.protocol.CompanionPacket
import com.macroideco.companion.service.CompanionServerService

/**
 * BroadcastReceiver for phone call status changes (ringing, off-hook, idle).
 */
class CallStateReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "MacroidCallReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        try {
            val stateString = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
            val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

            val normalizedState = when (stateString) {
                TelephonyManager.EXTRA_STATE_RINGING -> "RINGING"
                TelephonyManager.EXTRA_STATE_OFFHOOK -> "OFFHOOK"
                TelephonyManager.EXTRA_STATE_IDLE -> "IDLE"
                else -> stateString
            }

            val payload = CallStatePayload(
                state = normalizedState,
                incomingNumber = number
            )

            val packet = CompanionPacket(
                type = CompanionMessageType.CALL_STATE_CHANGED,
                payload = payload.toJson().toString().toByteArray(Charsets.UTF_8)
            )

            CompanionServerService.instance?.sendPacket(packet)
            Log.d(TAG, "Forwarded call state: $normalizedState")
        } catch (e: Exception) {
            Log.w(TAG, "Error handling phone state change", e)
        }
    }
}
