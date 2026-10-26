package com.macroideco.companion.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.BatteryManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.macroideco.companion.protocol.*
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.IOException
import java.net.ServerSocket
import java.net.Socket

/**
 * Foreground Service hosting the secure local Companion TCP Server (default port 8275).
 * Manages client connection lifecycle, pairing challenge-response, authentication,
 * and dispatching incoming telephony/notification/clipboard events to the Mac.
 */
class CompanionServerService : Service() {

    companion object {
        const val TAG = "MacroidCompanionServer"
        const val PORT = 8275
        const val CHANNEL_ID = "macroid_companion_service"
        const val NOTIF_ID = 1001

        const val PREFS_NAME = "macroid_eco_companion_prefs"
        const val KEY_AUTH_TOKEN = "paired_auth_token"
        const val KEY_PAIRED_CLIENT = "paired_client_name"

        // Singleton instance hook for listeners and receivers to forward data
        @Volatile
        var instance: CompanionServerService? = null
            private set
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var serverSocket: ServerSocket? = null
    private var activeSocket: Socket? = null
    private var activeOutputStream: DataOutputStream? = null

    private lateinit var prefs: SharedPreferences

    override fun onCreate() {
        super.onCreate()
        instance = this
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        createNotificationChannel()
        startForeground(NOTIF_ID, buildForegroundNotification("Waiting for Macroid Eco Mac connection..."))
        startServer()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        instance = null
        serviceScope.cancel()
        closeCurrentClient()
        try {
            serverSocket?.close()
        } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startServer() {
        serviceScope.launch {
            try {
                serverSocket = ServerSocket(PORT)
                Log.i(TAG, "Companion server listening on port $PORT")

                while (isActive) {
                    val socket = serverSocket?.accept() ?: break
                    Log.i(TAG, "Accepted client connection from ${socket.remoteSocketAddress}")
                    handleClientConnection(socket)
                }
            } catch (e: Exception) {
                if (isActive) {
                    Log.e(TAG, "Server socket error", e)
                }
            }
        }
    }

    private suspend fun handleClientConnection(socket: Socket) = withContext(Dispatchers.IO) {
        closeCurrentClient()
        activeSocket = socket

        try {
            val inStream = DataInputStream(socket.getInputStream())
            val outStream = DataOutputStream(socket.getOutputStream())
            activeOutputStream = outStream

            var isAuthenticated = false
            updateNotification("Client connected, authenticating...")

            while (isActive && !socket.isClosed) {
                val packet = CompanionPacket.readFrom(inStream)
                Log.d(TAG, "Received packet: ${packet.type}")

                when (packet.type) {
                    CompanionMessageType.PAIR_REQUEST -> {
                        val req = PairRequestPayload.fromJson(JSONObject(packet.payloadAsString()))
                        handlePairingRequest(req, outStream)
                    }

                    CompanionMessageType.PAIR_CONFIRM -> {
                        val confirm = PairConfirmPayload.fromJson(JSONObject(packet.payloadAsString()))
                        handlePairingConfirm(confirm, outStream)
                        isAuthenticated = true
                    }

                    CompanionMessageType.AUTH_REQUEST -> {
                        val authReq = AuthRequestPayload.fromJson(JSONObject(packet.payloadAsString()))
                        val savedToken = prefs.getString(KEY_AUTH_TOKEN, null)

                        if (savedToken != null && CompanionSecurity.secureCompare(authReq.authToken, savedToken)) {
                            isAuthenticated = true
                            val successResp = AuthResponsePayload(true, "Authentication successful")
                            val respPacket = CompanionPacket(
                                type = CompanionMessageType.AUTH_SUCCESS,
                                payload = successResp.toJson().toString().toByteArray(Charsets.UTF_8)
                            )
                            respPacket.writeTo(outStream)
                            updateNotification("Connected to Macroid Eco")
                            sendCurrentDeviceStatus()
                        } else {
                            val failResp = AuthResponsePayload(false, "Authentication failed: invalid token")
                            val respPacket = CompanionPacket(
                                type = CompanionMessageType.AUTH_FAILED,
                                payload = failResp.toJson().toString().toByteArray(Charsets.UTF_8)
                            )
                            respPacket.writeTo(outStream)
                            socket.close()
                            break
                        }
                    }

                    CompanionMessageType.PING -> {
                        val pong = CompanionPacket(type = CompanionMessageType.PONG)
                        pong.writeTo(outStream)
                    }

                    CompanionMessageType.CLIPBOARD_SYNC -> {
                        if (isAuthenticated) {
                            val clip = ClipboardSyncPayload.fromJson(JSONObject(packet.payloadAsString()))
                            Log.i(TAG, "Received remote clipboard update (${clip.text.length} chars)")
                        }
                    }

                    CompanionMessageType.DISCONNECT -> {
                        Log.i(TAG, "Client requested disconnect")
                        break
                    }

                    else -> {
                        Log.w(TAG, "Unhandled message type: ${packet.type}")
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Client session terminated: ${e.message}")
        } finally {
            closeCurrentClient()
            updateNotification("Waiting for Macroid Eco Mac connection...")
        }
    }

    private var currentClientNonce: String? = null
    private var currentServerNonce: String? = null
    private var currentSalt: String? = null

    private fun handlePairingRequest(req: PairRequestPayload, outStream: DataOutputStream) {
        val serverNonce = CompanionSecurity.generateNonce()
        val salt = "macroid-eco-sas-v1"
        val sas = CompanionSecurity.computeSAS(req.clientNonce, serverNonce, salt)

        currentClientNonce = req.clientNonce
        currentServerNonce = serverNonce
        currentSalt = salt

        val challenge = PairChallengePayload(
            serverName = "Macroid Companion",
            serverDevice = "${Build.MANUFACTURER} ${Build.MODEL}",
            sasCode = sas,
            serverNonce = serverNonce,
            salt = salt
        )

        val packet = CompanionPacket(
            type = CompanionMessageType.PAIR_CHALLENGE,
            payload = challenge.toJson().toString().toByteArray(Charsets.UTF_8)
        )
        packet.writeTo(outStream)
        updateNotification("Pairing requested. Confirmation code: $sas")
    }

    private fun handlePairingConfirm(confirm: PairConfirmPayload, outStream: DataOutputStream) {
        val cNonce = currentClientNonce ?: ""
        val sNonce = currentServerNonce ?: ""
        val salt = currentSalt ?: ""

        val expectedProof = CompanionSecurity.computeHMAC("$cNonce:$sNonce", salt)
        if (confirm.sasConfirmed && CompanionSecurity.secureCompare(confirm.clientProof, expectedProof)) {
            val newAuthToken = CompanionSecurity.generateNonce(32)
            val serverProof = CompanionSecurity.computeHMAC("$sNonce:$cNonce", salt)

            prefs.edit().putString(KEY_AUTH_TOKEN, newAuthToken).apply()

            val successPayload = PairSuccessPayload(newAuthToken, serverProof)
            val packet = CompanionPacket(
                type = CompanionMessageType.PAIR_SUCCESS,
                payload = successPayload.toJson().toString().toByteArray(Charsets.UTF_8)
            )
            packet.writeTo(outStream)
            updateNotification("Paired and connected to Mac")
            sendCurrentDeviceStatus()
        } else {
            val failPayload = AuthResponsePayload(false, "Pairing proof verification failed")
            val packet = CompanionPacket(
                type = CompanionMessageType.PAIR_FAILED,
                payload = failPayload.toJson().toString().toByteArray(Charsets.UTF_8)
            )
            packet.writeTo(outStream)
        }
    }

    /**
     * Broadcasts a packet to the connected Mac client safely across coroutines.
     */
    fun sendPacket(packet: CompanionPacket) {
        serviceScope.launch {
            try {
                activeOutputStream?.let { out ->
                    synchronized(out) {
                        packet.writeTo(out)
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to send packet to client: ${e.message}")
            }
        }
    }

    fun sendCurrentDeviceStatus() {
        val batteryIntent = registerReceiver(null, android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPct = if (level >= 0 && scale > 0) (level * 100 / scale) else 50
        val status = batteryIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL

        val statusPayload = DeviceStatusPayload(
            batteryLevel = batteryPct,
            isCharging = isCharging,
            cellularNetwork = "${Build.MANUFACTURER} ${Build.MODEL}"
        )

        val packet = CompanionPacket(
            type = CompanionMessageType.DEVICE_STATUS,
            payload = statusPayload.toJson().toString().toByteArray(Charsets.UTF_8)
        )
        sendPacket(packet)
    }

    private fun closeCurrentClient() {
        try {
            activeOutputStream = null
            activeSocket?.close()
            activeSocket = null
        } catch (_: Exception) {}
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Macroid Eco Companion Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps connection open with Macroid Eco for Mac"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(status: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Macroid Eco Companion")
            .setContentText(status)
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(status: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.notify(NOTIF_ID, buildForegroundNotification(status))
    }
}
