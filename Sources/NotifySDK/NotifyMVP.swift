import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

/// Official iOS Swift SDK for NotifyMVP Push Notification Service.
///
/// Usage (SwiftUI / AppDelegate):
/// ```swift
/// let config = NotifyConfig(
///     appId: "app_xxxxxxxx",
///     apiKey: "your_api_key",
///     baseUrl: "https://your-worker.workers.dev" // your Cloudflare Worker URL
/// )
/// await NotifyMVP.initialize(config: config)
/// ```
public final class NotifyMVP: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    
    // MARK: - Singleton
    public static let shared = NotifyMVP()

    // MARK: - Private State
    private var config: NotifyConfig?
    private var logger: NotifyLogger?
    private var httpClient: NotifyHttpClient?
    private let deviceInfo = DeviceInfoService()

    private var _isInitialized = false
    private var _fcmToken: String?
    private var _apnsToken: String?
    private var _externalUserId: String?
    private var _isOptedIn = true
    private var _permissionStatus = "unknown"

    private var onNotificationTapHandler: ((NotifyNotificationPayload) -> Void)?
    private var onForegroundNotificationHandler: ((NotifyNotificationPayload) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Public Properties

    public static var isInitialized: Bool {
        return shared._isInitialized
    }

    public static var fcmToken: String? {
        return shared._fcmToken
    }

    public static var apnsToken: String? {
        return shared._apnsToken
    }

    public static var externalUserId: String? {
        return shared._externalUserId
    }

    public static var isOptedIn: Bool {
        return shared._isOptedIn
    }

    public static var permissionStatus: String {
        return shared._permissionStatus
    }

    public static var subscriptionStatus: String {
        let inst = shared
        let hasToken = (inst._fcmToken != nil && !inst._fcmToken!.isEmpty) || (inst._apnsToken != nil && !inst._apnsToken!.isEmpty)
        let isPermitted = inst._permissionStatus == "granted" || inst._permissionStatus == "provisional"
        return (hasToken && isPermitted && inst._isOptedIn) ? "subscribed" : "unsubscribed"
    }

    // MARK: - Public Core API

    /// Initialize the NotifyMVP SDK. Call once at application startup.
    ///
    /// - Parameters:
    ///   - config: Project configuration options.
    ///   - autoRegister: Automatically register device and request push permissions (default: true).
    @discardableResult
    public static func initialize(
        config: NotifyConfig,
        autoRegister: Bool = true
    ) async -> NotifyResult {
        return await shared.initSDK(config: config, autoRegister: autoRegister)
    }

    /// Manually register or update device registration with backend.
    @discardableResult
    public static func register() async -> NotifyResult {
        guard shared._isInitialized else {
            return .failure(NotifyError.notInitialized.localizedDescription)
        }
        return await shared.registerDeviceInternal()
    }

    /// Opt-in to receive push notifications (OneSignal style).
    @discardableResult
    public static func optIn() async -> NotifyResult {
        guard shared._isInitialized else {
            return .failure(NotifyError.notInitialized.localizedDescription)
        }
        shared._isOptedIn = true
        return await shared.registerDeviceInternal()
    }

    /// Opt-out of push notifications without removing device record.
    @discardableResult
    public static func optOut() async -> NotifyResult {
        guard shared._isInitialized else {
            return .failure(NotifyError.notInitialized.localizedDescription)
        }
        shared._isOptedIn = false
        return await shared.registerDeviceInternal()
    }

    /// Attach custom external user ID (e.g. developer's user account ID).
    @discardableResult
    public static func setExternalUserId(_ userId: String?) async -> NotifyResult {
        guard shared._isInitialized else {
            return .failure(NotifyError.notInitialized.localizedDescription)
        }
        shared._externalUserId = userId
        return await shared.registerDeviceInternal()
    }

    /// Set FCM (Firebase Cloud Messaging) token manually.
    @discardableResult
    public static func setFCMToken(_ token: String) async -> NotifyResult {
        shared._fcmToken = token
        shared.logger?.info("FCM Token set: ...\(token.suffix(8))")
        if shared._isInitialized {
            return await shared.registerDeviceInternal()
        }
        return .success()
    }

    /// Set APNs device token (converts Data to hex string).
    @discardableResult
    public static func setAPNsToken(_ deviceTokenData: Data) async -> NotifyResult {
        let tokenHex = deviceTokenData.map { String(format: "%02.2hhx", $0) }.joined()
        shared._apnsToken = tokenHex
        // If FCM token is not present, use APNs hex token as fallback
        if shared._fcmToken == nil || shared._fcmToken!.isEmpty {
            shared._fcmToken = tokenHex
        }
        shared.logger?.info("APNs Device Token set: ...\(tokenHex.suffix(8))")
        if shared._isInitialized {
            return await shared.registerDeviceInternal()
        }
        return .success()
    }

    /// Re-check notification authorization settings and update backend registration.
    @discardableResult
    public static func syncSubscription() async -> NotifyResult {
        guard shared._isInitialized else {
            return .failure(NotifyError.notInitialized.localizedDescription)
        }
        shared._permissionStatus = await shared.deviceInfo.getPermissionStatus()
        return await shared.registerDeviceInternal()
    }

    /// Request notification authorization from iOS.
    @discardableResult
    public static func requestNotificationPermission(
        options: UNAuthorizationOptions = [.alert, .badge, .sound]
    ) async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: options)
            shared._permissionStatus = granted ? "granted" : "denied"
            
            #if canImport(UIKit)
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
            #endif
            
            if shared._isInitialized {
                _ = await shared.registerDeviceInternal()
            }
            return granted
        } catch {
            shared.logger?.error("Failed to request push authorization: \(error)")
            shared._permissionStatus = "denied"
            return false
        }
    }

    // MARK: - Topic Subscriptions

    /// Subscribe current device to a push topic.
    @discardableResult
    public static func subscribeToTopic(_ topic: String) async -> NotifyResult {
        guard let config = shared.config, let client = shared.httpClient else {
            return .failure(NotifyError.notInitialized.localizedDescription)
        }
        let token = shared._fcmToken ?? shared._apnsToken ?? ""
        guard !token.isEmpty else {
            return .failure("Cannot subscribe to topic: FCM/APNs token is missing")
        }
        do {
            try await client.subscribeToTopic(
                appId: config.appId,
                apiKey: config.apiKey,
                fcmToken: token,
                topic: topic
            )
            shared.logger?.info("Subscribed to topic: \(topic)")
            return .success()
        } catch {
            shared.logger?.error("Subscribe to topic failed: \(error)")
            return .failure(error.localizedDescription)
        }
    }

    /// Unsubscribe current device from a push topic.
    @discardableResult
    public static func unsubscribeFromTopic(_ topic: String) async -> NotifyResult {
        guard let config = shared.config, let client = shared.httpClient else {
            return .failure(NotifyError.notInitialized.localizedDescription)
        }
        let token = shared._fcmToken ?? shared._apnsToken ?? ""
        guard !token.isEmpty else {
            return .failure("Cannot unsubscribe from topic: FCM/APNs token is missing")
        }
        do {
            try await client.unsubscribeFromTopic(
                appId: config.appId,
                apiKey: config.apiKey,
                fcmToken: token,
                topic: topic
            )
            shared.logger?.info("Unsubscribed from topic: \(topic)")
            return .success()
        } catch {
            shared.logger?.error("Unsubscribe from topic failed: \(error)")
            return .failure(error.localizedDescription)
        }
    }

    /// Fetch list of available topics for this project.
    public static func fetchTopics() async throws -> [NotifyTopic] {
        guard let config = shared.config, let client = shared.httpClient else {
            throw NotifyError.notInitialized
        }
        return try await client.fetchTopics(appId: config.appId, apiKey: config.apiKey)
    }

    // MARK: - Notification Callbacks & Handlers

    /// Set callback listener for notification tap (opened app from background or killed state).
    public static func setNotificationTapHandler(_ handler: @escaping (NotifyNotificationPayload) -> Void) {
        shared.onNotificationTapHandler = handler
    }

    /// Set callback listener for foreground notification delivery.
    public static func setForegroundNotificationHandler(_ handler: @escaping (NotifyNotificationPayload) -> Void) {
        shared.onForegroundNotificationHandler = handler
    }

    /// Parse notification response when user taps a notification banner.
    public static func handleNotificationResponse(_ response: UNNotificationResponse) {
        let content = response.notification.request.content
        let payload = extractPayload(from: content)
        shared.logger?.info("Notification tapped: title='\(payload.title)', url='\(payload.url ?? "")'")
        shared.onNotificationTapHandler?(payload)
    }

    /// Parse notification content received in foreground.
    public static func handleForegroundNotification(_ notification: UNNotification) {
        let content = notification.request.content
        let payload = extractPayload(from: content)
        shared.logger?.info("Foreground notification received: title='\(payload.title)'")
        shared.onForegroundNotificationHandler?(payload)
    }

    // MARK: - UNUserNotificationCenterDelegate Conformance

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        NotifyMVP.handleForegroundNotification(notification)
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotifyMVP.handleNotificationResponse(response)
        completionHandler()
    }

    // MARK: - Private Implementation

    private func initSDK(config: NotifyConfig, autoRegister: Bool) async -> NotifyResult {
        self.config = config
        let logger = NotifyLogger(isEnabled: config.debugLogging)
        self.logger = logger
        self.httpClient = NotifyHttpClient(config: config, logger: logger)
        
        logger.info("Initializing NotifyMVP iOS SDK v1.0.0")
        
        // Auto assign UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = self
        
        self._permissionStatus = await deviceInfo.getPermissionStatus()
        self._isInitialized = true

        if autoRegister {
            _ = await requestNotificationPermission()
            return await registerDeviceInternal()
        }

        return .success()
    }

    private func registerDeviceInternal() async -> NotifyResult {
        guard let config = self.config, let client = self.httpClient else {
            return .failure(NotifyError.notInitialized.localizedDescription)
        }

        do {
            self._permissionStatus = await deviceInfo.getPermissionStatus()
            let deviceId = deviceInfo.getDeviceId()
            let appVersion = deviceInfo.getAppVersion()
            let deviceModel = deviceInfo.getDeviceModel()
            let deviceOs = deviceInfo.getDeviceOs()
            let language = deviceInfo.getLanguage()
            let timezone = deviceInfo.getTimezone()
            let country = deviceInfo.getCountry()
            let platform = deviceInfo.getPlatform()

            let activeToken = self._fcmToken ?? self._apnsToken ?? ""

            let payload = RegisterPayload(
                appId: config.appId,
                apiKey: config.apiKey,
                fcmToken: activeToken,
                platform: platform,
                deviceId: deviceId,
                appVersion: appVersion,
                deviceModel: deviceModel,
                deviceOs: deviceOs,
                language: language,
                timezone: timezone,
                country: country.isEmpty ? nil : country,
                sdkVersion: "1.0.0",
                permissionStatus: self._permissionStatus,
                optedIn: self._isOptedIn,
                externalUserId: self._externalUserId
            )

            try await client.registerDevice(payload)

            logger?.info("Device registered successfully ✓ [deviceId: \(deviceId), status: \(NotifyMVP.subscriptionStatus)]")

            let responseData: [String: String] = [
                "deviceId": deviceId,
                "platform": platform,
                "appVersion": appVersion,
                "subscriptionStatus": NotifyMVP.subscriptionStatus
            ]
            return .success(data: responseData)

        } catch {
            logger?.error("Device registration failed: \(error.localizedDescription)")
            return .failure(error.localizedDescription)
        }
    }

    private static func extractPayload(from content: UNNotificationContent) -> NotifyNotificationPayload {
        let title = content.title
        let body = content.body
        
        var stringData: [String: String] = [:]
        for (key, value) in content.userInfo {
            let keyStr = String(describing: key)
            if let valStr = value as? String {
                stringData[keyStr] = valStr
            } else if let numVal = value as? NSNumber {
                stringData[keyStr] = numVal.stringValue
            }
        }
        
        let launchUrl = stringData["url"] ?? stringData["launch_url"] ?? stringData["link"]
        
        return NotifyNotificationPayload(
            title: title,
            body: body,
            url: launchUrl,
            data: stringData
        )
    }
}
