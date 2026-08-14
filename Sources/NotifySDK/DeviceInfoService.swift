import Foundation
#if canImport(UIKit)
import UIKit
#endif
import UserNotifications

internal final class DeviceInfoService: Sendable {
    
    /// Returns vendor identifier or fallback UUID stored in UserDefaults.
    func getDeviceId() -> String {
        #if canImport(UIKit)
        if let id = UIDevice.current.identifierForVendor?.uuidString {
            return id
        }
        #endif
        
        let key = "com.notifymvp.sdk.device_id"
        if let savedId = UserDefaults.standard.string(forKey: key) {
            return savedId
        }
        
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    /// Returns device model (e.g. "iPhone", "iPad").
    func getDeviceModel() -> String {
        #if canImport(UIKit)
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? UIDevice.current.model : identifier
        #else
        return "Apple Device"
        #endif
    }

    /// Returns OS version (e.g. "iOS 17.4").
    func getDeviceOs() -> String {
        #if canImport(UIKit)
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #else
        return "macOS/iOS"
        #endif
    }

    /// Returns main bundle version string.
    func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Returns language code (e.g. "en").
    func getLanguage() -> String {
        if #available(iOS 16.0, macOS 13.0, *) {
            return Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            return Locale.current.languageCode ?? "en"
        }
    }

    /// Returns system timezone identifier (e.g. "America/New_York").
    func getTimezone() -> String {
        return TimeZone.current.identifier
    }

    /// Fixed platform string matching backend enum.
    func getPlatform() -> String {
        return "ios"
    }

    /// Queries OS permission status asynchronously.
    func getPermissionStatus() async -> String {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized:
            return "granted"
        case .denied:
            return "denied"
        case .provisional:
            return "provisional"
        case .ephemeral:
            return "provisional"
        case .notDetermined:
            return "unknown"
        @unknown default:
            return "unknown"
        }
    }
}
