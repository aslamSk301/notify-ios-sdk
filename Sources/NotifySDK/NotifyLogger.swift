import Foundation
import os.log

/// Logger for NotifySDK internal diagnostics.
internal final class NotifyLogger: @unchecked Sendable {
    private let isEnabled: Bool
    private let category = "NotifySDK"

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    func debug(_ message: String) {
        guard isEnabled else { return }
        print("[NotifySDK 🔍 DEBUG] \(message)")
    }

    func info(_ message: String) {
        guard isEnabled else { return }
        print("[NotifySDK ℹ️ INFO] \(message)")
    }

    func warn(_ message: String) {
        guard isEnabled else { return }
        print("[NotifySDK ⚠️ WARN] \(message)")
    }

    func error(_ message: String) {
        print("[NotifySDK ❌ ERROR] \(message)")
    }
}
