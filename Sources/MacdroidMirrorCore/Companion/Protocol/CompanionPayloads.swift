import Foundation

// MARK: - Pairing & Authentication Payloads

public struct PairRequestPayload: Codable, Sendable, Equatable {
    public let clientName: String
    public let clientOS: String
    public let clientNonce: String
    public let protocolVersion: Int

    public init(
        clientName: String = "Macroid Eco for Mac",
        clientOS: String = "macOS " + ProcessInfo.processInfo.operatingSystemVersionString,
        clientNonce: String = UUID().uuidString,
        protocolVersion: Int = 1
    ) {
        self.clientName = clientName
        self.clientOS = clientOS
        self.clientNonce = clientNonce
        self.protocolVersion = protocolVersion
    }
}

public struct PairChallengePayload: Codable, Sendable, Equatable {
    public let serverName: String
    public let serverDevice: String
    public let sasCode: String          // Short Authentication String (e.g. "614 829")
    public let serverNonce: String
    public let salt: String

    public init(
        serverName: String,
        serverDevice: String,
        sasCode: String,
        serverNonce: String,
        salt: String
    ) {
        self.serverName = serverName
        self.serverDevice = serverDevice
        self.sasCode = sasCode
        self.serverNonce = serverNonce
        self.salt = salt
    }
}

public struct PairConfirmPayload: Codable, Sendable, Equatable {
    public let clientProof: String
    public let sasConfirmed: Bool

    public init(clientProof: String, sasConfirmed: Bool = true) {
        self.clientProof = clientProof
        self.sasConfirmed = sasConfirmed
    }
}

public struct PairSuccessPayload: Codable, Sendable, Equatable {
    public let authToken: String
    public let serverProof: String

    public init(authToken: String, serverProof: String) {
        self.authToken = authToken
        self.serverProof = serverProof
    }
}

public struct AuthRequestPayload: Codable, Sendable, Equatable {
    public let clientName: String
    public let authToken: String
    public let nonce: String

    public init(clientName: String, authToken: String, nonce: String = UUID().uuidString) {
        self.clientName = clientName
        self.authToken = authToken
        self.nonce = nonce
    }
}

public struct AuthResponsePayload: Codable, Sendable, Equatable {
    public let isSuccess: Bool
    public let message: String

    public init(isSuccess: Bool, message: String) {
        self.isSuccess = isSuccess
        self.message = message
    }
}

// MARK: - Device Status Telemetry

public struct DeviceStatusPayload: Codable, Sendable, Equatable {
    public let batteryLevel: Int        // 0 to 100
    public let isCharging: Bool
    public let isPowerSave: Bool
    public let wifiSSID: String?
    public let cellularNetwork: String?

    public init(
        batteryLevel: Int,
        isCharging: Bool,
        isPowerSave: Bool = false,
        wifiSSID: String? = nil,
        cellularNetwork: String? = nil
    ) {
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.isPowerSave = isPowerSave
        self.wifiSSID = wifiSSID
        self.cellularNetwork = cellularNetwork
    }
}

// MARK: - Notification Payloads

public struct NotificationActionItem: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let isQuickReply: Bool

    public init(id: String, title: String, isQuickReply: Bool = false) {
        self.id = id
        self.title = title
        self.isQuickReply = isQuickReply
    }
}

public struct NotificationPayload: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let key: String
    public let packageName: String
    public let appName: String
    public let title: String
    public let text: String
    public let subText: String?
    public let postTime: Int64
    public let isClearable: Bool
    public let actions: [NotificationActionItem]

    public init(
        id: String,
        key: String,
        packageName: String,
        appName: String,
        title: String,
        text: String,
        subText: String? = nil,
        postTime: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        isClearable: Bool = true,
        actions: [NotificationActionItem] = []
    ) {
        self.id = id
        self.key = key
        self.packageName = packageName
        self.appName = appName
        self.title = title
        self.text = text
        self.subText = subText
        self.postTime = postTime
        self.isClearable = isClearable
        self.actions = actions
    }
}

public struct NotificationActionRequestPayload: Codable, Sendable, Equatable {
    public let notificationKey: String
    public let actionId: String?       // nil = dismiss notification
    public let replyText: String?

    public init(notificationKey: String, actionId: String? = nil, replyText: String? = nil) {
        self.notificationKey = notificationKey
        self.actionId = actionId
        self.replyText = replyText
    }
}

// MARK: - SMS Payloads

public struct SmsMessagePayload: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let threadId: String
    public let senderAddress: String
    public let senderName: String?
    public let body: String
    public let timestamp: Int64
    public let isRead: Bool

    public init(
        id: String,
        threadId: String,
        senderAddress: String,
        senderName: String? = nil,
        body: String,
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        isRead: Bool = false
    ) {
        self.id = id
        self.threadId = threadId
        self.senderAddress = senderAddress
        self.senderName = senderName
        self.body = body
        self.timestamp = timestamp
        self.isRead = isRead
    }
}

public struct SmsSendRequestPayload: Codable, Sendable, Equatable {
    public let recipientAddress: String
    public let body: String
    public let clientRefId: String

    public init(recipientAddress: String, body: String, clientRefId: String = UUID().uuidString) {
        self.recipientAddress = recipientAddress
        self.body = body
        self.clientRefId = clientRefId
    }
}

public struct SmsSendResultPayload: Codable, Sendable, Equatable {
    public let clientRefId: String
    public let isSuccess: Bool
    public let errorCode: Int?
    public let errorMessage: String?

    public init(clientRefId: String, isSuccess: Bool, errorCode: Int? = nil, errorMessage: String? = nil) {
        self.clientRefId = clientRefId
        self.isSuccess = isSuccess
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}

// MARK: - Call State & Clipboard Payloads

public enum CallStateType: String, Codable, Sendable {
    case idle       = "IDLE"
    case ringing    = "RINGING"
    case offhook    = "OFFHOOK"
}

public struct CallStatePayload: Codable, Sendable, Equatable {
    public let state: CallStateType
    public let incomingNumber: String?
    public let callerName: String?
    public let timestamp: Int64

    public init(
        state: CallStateType,
        incomingNumber: String? = nil,
        callerName: String? = nil,
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.state = state
        self.incomingNumber = incomingNumber
        self.callerName = callerName
        self.timestamp = timestamp
    }
}

public struct ClipboardSyncPayload: Codable, Sendable, Equatable {
    public let text: String
    public let timestamp: Int64
    public let sourceDeviceId: String

    public init(text: String, timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000), sourceDeviceId: String) {
        self.text = text
        self.timestamp = timestamp
        self.sourceDeviceId = sourceDeviceId
    }
}
