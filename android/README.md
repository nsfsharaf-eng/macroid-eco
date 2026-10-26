# Macroid Eco — Android Companion App

Native Android companion service for **Macroid Eco**, enabling Phone Link-style integration between Android and macOS.

---

## Capabilities

- **Real-Time Notification Forwarding**: Captures system notifications using Android's `NotificationListenerService` and streams them over a secure local TCP connection to your Mac.
- **Incoming SMS Alerts**: Detects incoming SMS messages and displays them in Macroid Eco.
- **Phone Call Alerts**: Observes call state transitions (ringing, off-hook, idle) with caller identification.
- **Dual Local Transport**:
  - **Wi-Fi Transport**: Direct local TCP connection over Wi-Fi on port `8275`.
  - **USB ADB Bridge**: Works seamlessly over USB with zero configuration via `adb forward tcp:8275 tcp:8275`, completely bypassing Wi-Fi AP Client Isolation.
- **Cryptographic Pairing**:
  - Secure 6-digit Short Authentication String (SAS) code matching on both screens.
  - Zero plain-text transmission; HMAC-SHA256 authenticated sessions.
  - Persistent auth tokens stored locally in app preferences.

---

## Technical Specifications

| Parameter | Value |
|---|---|
| **Language** | Kotlin 1.9+ |
| **Minimum Android SDK** | API 26 (Android 8.0 Oreo) |
| **Target Android SDK** | API 34 (Android 14) |
| **Default TCP Port** | `8275` |
| **Wire Protocol** | 12-byte framed binary header (`MECO`) + JSON payload |

---

## Building and Installing

### Option 1: Open in Android Studio
1. Open Android Studio.
2. Select **Open** and choose the `android/` directory inside `MacdroidMirror`.
3. Let Gradle sync project dependencies.
4. Click **Run** or press `Shift + F10` with your Android phone connected via USB.

### Option 2: Command Line (Gradle)
```bash
cd android

# Build debug APK
./gradlew assembleDebug

# Install on connected device via ADB
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

---

## Permission Setup on Device

Once installed on your phone:
1. Open **Macroid Eco Companion**.
2. Tap **Start Service** to launch the foreground background server.
3. Tap **Grant** next to **Notification Listener Access** and toggle ON Macroid Eco Companion in Android Settings.
4. Tap **Grant** for SMS and Phone State permissions when prompted.
5. On your Mac, Macroid Eco will detect the companion server and display the 6-digit SAS confirmation code.
