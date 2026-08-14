import Foundation

/// Configuration options for initializing NotifyMVP SDK.
public struct NotifyConfig: Sendable {
    public let appId: String
    public let apiKey: String
    public let baseUrl: String
    public let debugLogging: Bool
    public let requestTimeoutMs: TimeInterval
    public let maxRetries: Int

    /// Initialize configuration with project parameters.
    ///
    /// - Parameters:
    ///   - appId: Your project appId (e.g., "app_xxxxxxxx")
    ///   - apiKey: Your project apiKey
    ///   - baseUrl: Backend server URL (e.g., "https://notyfy.vercel.app")
    ///   - debugLogging: Enable console logs for debugging (default: false)
    ///   - requestTimeoutMs: HTTP request timeout in milliseconds (default: 15,000)
    ///   - maxRetries: Max network retry attempts (default: 3)
    public init(
        appId: String,
        apiKey: String,
        baseUrl: String,
        debugLogging: Bool = false,
        requestTimeoutMs: TimeInterval = 15_000,
        maxRetries: Int = 3
    ) {
        self.appId = appId
        self.apiKey = apiKey
        // Strip trailing slashes from baseUrl
        self.baseUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.debugLogging = debugLogging
        self.requestTimeoutMs = requestTimeoutMs
        self.maxRetries = maxRetries
    }
}
