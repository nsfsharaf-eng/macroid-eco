package com.macroideco.companion.ui

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.macroideco.companion.databinding.ActivityMainBinding
import com.macroideco.companion.service.CompanionServerService
import com.macroideco.companion.service.MacroidNotificationListenerService

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    private val requestSmsPermissions = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { updatePermissionStatus() }

    private val requestPhonePermissions = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { updatePermissionStatus() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupListeners()
    }

    override fun onResume() {
        super.onResume()
        updateServiceStatus()
        updatePermissionStatus()
    }

    private fun setupListeners() {
        binding.btnToggleService.setOnClickListener {
            if (CompanionServerService.instance != null) {
                stopService(Intent(this, CompanionServerService::class.java))
            } else {
                val serviceIntent = Intent(this, CompanionServerService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
            }
            binding.root.postDelayed({ updateServiceStatus() }, 300)
        }

        binding.btnGrantNotification.setOnClickListener {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }

        binding.btnGrantSms.setOnClickListener {
            val perms = mutableListOf(
                Manifest.permission.RECEIVE_SMS,
                Manifest.permission.READ_SMS
            )
            requestSmsPermissions.launch(perms.toTypedArray())
        }

        binding.btnGrantPhone.setOnClickListener {
            val perms = arrayOf(
                Manifest.permission.READ_PHONE_STATE,
                Manifest.permission.READ_CONTACTS
            )
            requestPhonePermissions.launch(perms)
        }
    }

    private fun updateServiceStatus() {
        val isRunning = CompanionServerService.instance != null
        if (isRunning) {
            binding.tvServiceStatus.text = "Listening on port 8275 (Ready for Macroid Eco Mac)"
            binding.btnToggleService.text = "Stop Service"
        } else {
            binding.tvServiceStatus.text = "Companion server is stopped"
            binding.btnToggleService.text = "Start Service"
        }
    }

    private fun updatePermissionStatus() {
        // Notification listener check
        val isNotifGranted = isNotificationServiceEnabled()
        binding.btnGrantNotification.isEnabled = !isNotifGranted
        binding.btnGrantNotification.text = if (isNotifGranted) "Granted ✓" else "Grant"

        // SMS check
        val isSmsGranted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.RECEIVE_SMS
        ) == PackageManager.PERMISSION_GRANTED
        binding.btnGrantSms.isEnabled = !isSmsGranted
        binding.btnGrantSms.text = if (isSmsGranted) "Granted ✓" else "Grant"

        // Phone check
        val isPhoneGranted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
        binding.btnGrantPhone.isEnabled = !isPhoneGranted
        binding.btnGrantPhone.text = if (isPhoneGranted) "Granted ✓" else "Grant"
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val cn = ComponentName(this, MacroidNotificationListenerService::class.java)
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(cn.flattenToString())
    }
}
