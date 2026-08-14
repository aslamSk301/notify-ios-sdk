# NotifyMVP iOS SDK (`NotifySDK`)

Native iOS SDK for **NotifyMVP** — lightweight, powerful push notification management.

---

## 🚀 Features

- 📱 **Native Swift 5.7+ / iOS 13+ Support**
- ⚡ **Zero-bloat dependencies** (Pure Swift `URLSession` & `UserNotifications`)
- 🔔 **APNs & Firebase Cloud Messaging (FCM)** compatibility
- 📲 **OneSignal-style Opt-in / Opt-out** management
- 👤 **External User ID binding** (bind devices to user accounts)
- 🏷️ **Topic Subscriptions** (subscribe/unsubscribe to push channels)
- 🎯 **Deep Link & Launch URL Support** (`data.url`)

---

## 📦 Installation

### Option A: Swift Package Manager (Recommended)

1. Open your project in **Xcode**.
2. Go to **File > Add Package Dependencies...**
3. Enter the repository URL:
   ```text
   https://github.com/aslamSk301/notify-ios-sdk.git
   ```
4. Select **NotifySDK** package and add it to your app target.

---

### Option B: CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'NotifySDK', :path => '../notify_ios_sdk' # or git repo URL
```

Then run:
```bash
pod install
```

---

## 🛠️ Xcode Project Configuration

1. In Xcode, select your app **Target** -> **Signing & Capabilities**.
2. Click **+ Capability** and add:
   - **Push Notifications**
   - **Background Modes** (check **Remote notifications**)

---

## 🏁 Quick Start Guide

### 1. SwiftUI Integration

Add initialization inside your `@main` App struct:

```swift
import SwiftUI
import NotifySDK
import UserNotifications

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        
        Task {
            let config = NotifyConfig(
                appId: "app_xxxxxxxx",          // Your Project App ID
                apiKey: "your_api_key_here",    // Your Project API Key
                baseUrl: "https://notyfy.vercel.app",
                debugLogging: true
            )
            
            // Initialize SDK
            await NotifyMVP.initialize(config: config, autoRegister: true)
            
            // Handle Notification Tap / Launch URL
            NotifyMVP.setNotificationTapHandler { payload in
                print("Notification Tapped! Title: \(payload.title)")
                if let launchUrl = payload.url {
                    print("Deep Link / Launch URL: \(launchUrl)")
                    // Open URL or navigate inside app
                }
            }
        }
        
        return true
    }

    // Register APNs Device Token
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            await NotifyMVP.setAPNsToken(deviceToken)
        }
    }
}
```

---

### 2. UIKit Integration (`AppDelegate.swift`)

```swift
import UIKit
import NotifySDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        Task {
            let config = NotifyConfig(
                appId: "app_xxxxxxxx",
                apiKey: "your_api_key",
                baseUrl: "https://notyfy.vercel.app",
                debugLogging: true
            )
            
            await NotifyMVP.initialize(config: config)
            
            NotifyMVP.setNotificationTapHandler { payload in
                print("Tapped Notification: \(payload.title), DeepLink: \(payload.url ?? "")")
            }
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            await NotifyMVP.setAPNsToken(deviceToken)
        }
    }
}
```

---

## 🛠️ Firebase Cloud Messaging (FCM) Integration

If your app uses Firebase Messaging (`FirebaseMessaging`), pass the FCM Token to `NotifyMVP`:

```swift
import FirebaseMessaging
import NotifySDK

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        Task {
            await NotifyMVP.setFCMToken(token)
        }
    }
}
```

---

## 👤 External User ID (User Identity & Login/Logout)

You can associate the device with your app's user account ID (e.g., database User ID or Email).

```swift
// When User Logs In:
Task {
    let result = await NotifyMVP.setExternalUserId("user_987654")
    if result.isSuccess {
        print("External User ID set successfully")
    }
}

// When User Logs Out:
Task {
    await NotifyMVP.setExternalUserId(nil)
}
```

---

## 📖 API Reference

### Core Methods

| Method | Description |
| :--- | :--- |
| `NotifyMVP.initialize(config:autoRegister:)` | Initializes the SDK and optionally registers the device. |
| `NotifyMVP.register()` | Manually sync device metadata and push token with backend. |
| `NotifyMVP.optIn()` | Enable push notifications for the current device. |
| `NotifyMVP.optOut()` | Disable push notifications without deleting device record. |
| `NotifyMVP.setExternalUserId("user_123")` | Bind device to your backend user ID (or `nil` to clear). |
| `NotifyMVP.setAPNsToken(data)` | Pass raw APNs token data from iOS delegate. |
| `NotifyMVP.setFCMToken("fcm_token...")` | Pass FCM token string from Firebase Messaging. |

---

### Topic Management

```swift
// Subscribe to a topic
await NotifyMVP.subscribeToTopic("news_alerts")

// Unsubscribe from a topic
await NotifyMVP.unsubscribeFromTopic("news_alerts")

// Fetch available topics
do {
    let topics = try await NotifyMVP.fetchTopics()
    for topic in topics {
        print("Topic: \(topic.name) (\(topic.id))")
    }
} catch {
    print("Failed to fetch topics: \(error)")
}
```

---

### Notification Handlers

```swift
// Handle notification tap (User clicked banner)
NotifyMVP.setNotificationTapHandler { payload in
    print("Title: \(payload.title)")
    print("Body: \(payload.body)")
    print("Launch URL: \(payload.url ?? "None")")
    print("Custom Data: \(payload.data)")
}

// Handle notification received while app is open
NotifyMVP.setForegroundNotificationHandler { payload in
    print("Received in foreground: \(payload.title)")
}
```

---

## 📄 License

Distributed under the **MIT License**.
