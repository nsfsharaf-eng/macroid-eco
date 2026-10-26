import Foundation

/// Defines the wire-level message types for the Macroid Eco Companion Protocol.
public enum CompanionMessageType: UInt8, CaseIterable, Sendable {
    // Pairing Handshake (0x01 - 0x0F)
    case pairRequest        = 0x01
    case pairChallenge      = 0x02
    case pairConfirm        = 0x03
    case pairSuccess        = 0x04
    case pairFailed         = 0x05

    // Session Authentication (0x10 - 0x1F)
    case authRequest        = 0x10
    case authSuccess        = 0x11
    case authFailed         = 0x12

    // Heartbeat Keep-Alive (0x20 - 0x2F)
    case ping               = 0x20
    case pong               = 0x21

    // Device Telemetry (0x30 - 0x3F)
    case deviceStatus       = 0x30

    // Notifications (0x40 - 0x4F)
    case notificationPosted = 0x40
    case notificationRemoved = 0x41
    case notificationAction  = 0x42

    // SMS & Messaging (0x50 - 0x5F)
    case smsReceived        = 0x50
    case smsSendRequest     = 0x51
    case smsSendResult      = 0x52

    // Telephony & Calls (0x60 - 0x6F)
    case callStateChanged   = 0x60

    // Clipboard Synchronization (0x70 - 0x7F)
    case clipboardSync      = 0x70

    // Termination (0xFF)
    case disconnect         = 0xFF

    public var name: String {
        switch self {
        case .pairRequest: return "PAIR_REQUEST"
        case .pairChallenge: return "PAIR_CHALLENGE"
        case .pairConfirm: return "PAIR_CONFIRM"
        case .pairSuccess: return "PAIR_SUCCESS"
        case .pairFailed: return "PAIR_FAILED"
        case .authRequest: return "AUTH_REQUEST"
        case .authSuccess: return "AUTH_SUCCESS"
        case .authFailed: return "AUTH_FAILED"
        case .ping: return "PING"
        case .pong: return "PONG"
        case .deviceStatus: return "DEVICE_STATUS"
        case .notificationPosted: return "NOTIFICATION_POSTED"
        case .notificationRemoved: return "NOTIFICATION_REMOVED"
        case .notificationAction: return "NOTIFICATION_ACTION"
        case .smsReceived: return "SMS_RECEIVED"
        case .smsSendRequest: return "SMS_SEND_REQUEST"
        case .smsSendResult: return "SMS_SEND_RESULT"
        case .callStateChanged: return "CALL_STATE_CHANGED"
        case .clipboardSync: return "CLIPBOARD_SYNC"
        case .disconnect: return "DISCONNECT"
        }
    }
}
