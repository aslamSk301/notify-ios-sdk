import Foundation

/// Represents a topic available in NotifyMVP.
public struct NotifyTopic: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let isDefault: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case isDefault = "is_default"
    }

    public init(id: String, name: String, description: String? = nil, isDefault: Bool? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.isDefault = isDefault
    }
}

/// Generic SDK operation result.
public struct NotifyResult: Sendable {
    public let isSuccess: Bool
    public let error: String?
    public let data: [String: String]?

    public init(isSuccess: Bool, error: String? = nil, data: [String: String]? = nil) {
        self.isSuccess = isSuccess
        self.error = error
        self.data = data
    }

    public static func success(data: [String: String]? = nil) -> NotifyResult {
        return NotifyResult(isSuccess: true, error: nil, data: data)
    }

    public static func failure(_ error: String) -> NotifyResult {
        return NotifyResult(isSuccess: false, error: error, data: nil)
    }
}

/// Errors thrown by NotifySDK.
public enum NotifyError: Error, LocalizedError, Sendable {
    case notInitialized
    case authError(String)
    case networkError(String, statusCode: Int?)
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "NotifyMVP SDK is not initialized. Call NotifyMVP.initialize(...) before using the SDK."
        case .authError(let message):
            return "Authentication failed: \(message)"
        case .networkError(let message, let statusCode):
            if let code = statusCode {
                return "Network error (\(code)): \(message)"
            }
            return "Network error: \(message)"
        case .invalidResponse(let message):
            return "Invalid server response: \(message)"
        }
    }
}

/// Payload sent to POST /api/device/register
internal struct RegisterPayload: Encodable, Sendable {
    let appId: String
    let apiKey: String
    let fcmToken: String
    let platform: String
    let deviceId: String
    let appVersion: String?
    let deviceModel: String?
    let deviceOs: String?
    let language: String?
    let timezone: String?
    let sdkVersion: String?
    let permissionStatus: String?
    let optedIn: Bool
    let externalUserId: String?
}

/// Payload delivered when a push notification arrives or is tapped.
public struct NotifyNotificationPayload: Sendable {
    public let title: String
    public let body: String
    public let url: String?
    public let data: [String: String]

    public init(title: String, body: String, url: String? = nil, data: [String: String] = [:]) {
        self.title = title
        self.body = body
        self.url = url
        self.data = data
    }
}
