package com.macroideco.companion.service

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import com.macroideco.companion.protocol.CompanionMessageType
import com.macroideco.companion.protocol.CompanionPacket
import com.macroideco.companion.protocol.NotificationPayload

/**
 * Listens to active Android system notifications and streams them
 * in real-time to the paired Macroid Eco client on macOS.
 */
class MacroidNotificationListenerService : NotificationListenerService() {

    companion object {
        const val TAG = "MacroidNotifListener"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        // Skip our own persistent foreground service notification
        if (sbn.packageName == packageName) return

        try {
            val extras = sbn.notification.extras ?: return
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
            val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
            val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()

            // Ignore blank notifications
            if (title.isBlank() && text.isBlank()) return

            val appName = try {
                val appInfo = packageManager.getApplicationInfo(sbn.packageName, 0)
                packageManager.getApplicationLabel(appInfo).toString()
            } catch (_: Exception) {
                sbn.packageName
            }

            val payload = NotificationPayload(
                id = sbn.id.toString(),
                key = sbn.key,
                packageName = sbn.packageName,
                appName = appName,
                title = title,
                text = text,
                subText = subText,
                postTime = sbn.postTime,
                isClearable = sbn.isClearable
            )

            val packet = CompanionPacket(
                type = CompanionMessageType.NOTIFICATION_POSTED,
                payload = payload.toJson().toString().toByteArray(Charsets.UTF_8)
            )

            CompanionServerService.instance?.sendPacket(packet)
            Log.d(TAG, "Forwarded notification: [$appName] $title")
        } catch (e: Exception) {
            Log.w(TAG, "Error processing posted notification", e)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        if (sbn == null || sbn.packageName == packageName) return

        try {
            val removePayload = org.json.JSONObject().apply {
                put("key", sbn.key)
                put("id", sbn.id.toString())
            }

            val packet = CompanionPacket(
                type = CompanionMessageType.NOTIFICATION_REMOVED,
                payload = removePayload.toString().toByteArray(Charsets.UTF_8)
            )

            CompanionServerService.instance?.sendPacket(packet)
        } catch (e: Exception) {
            Log.w(TAG, "Error processing removed notification", e)
        }
    }
}
