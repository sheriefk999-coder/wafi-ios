import Foundation
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

/// Push through Firebase Cloud Messaging. Firebase is configured at runtime from the admin console's values
/// (/app/config → firebase), so a new Firebase project never needs a new build.
@MainActor
final class Push: NSObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    static let shared = Push()
    private var configured = false
    private var fcmToken: String?

    func start() {
        UNUserNotificationCenter.current().delegate = self
        configure(AppState.shared.config.firebase)
    }

    func configure(_ fb: FirebaseConfig?) {
        guard !configured, let fb, FirebaseApp.app() == nil else { return }
        let o = FirebaseOptions(googleAppID: fb.appId, gcmSenderID: fb.senderId)
        o.apiKey = fb.apiKey
        o.projectID = fb.projectId
        o.bundleID = Bundle.main.bundleIdentifier ?? "com.wafi.app"
        FirebaseApp.configure(options: o)
        Messaging.messaging().delegate = self
        configured = true
        if hasAsked { UIApplication.shared.registerForRemoteNotifications() }
    }

    var hasAsked: Bool { UserDefaults.standard.bool(forKey: "wafi.push.asked") }

    /// Asked when the user watches a product or opens settings, never at launch.
    func requestPermission() async -> Bool {
        UserDefaults.standard.set(true, forKey: "wafi.push.asked")
        let ok = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if ok { UIApplication.shared.registerForRemoteNotifications() }
        return ok
    }

    func permissionGranted() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized
    }

    func didRegister(deviceToken: Data) {
        guard configured else { return }
        Messaging.messaging().apnsToken = deviceToken
    }

    func registerIfSignedIn() async {
        guard configured, AppState.shared.isSignedIn else { return }
        if let t = try? await Messaging.messaging().token() {
            fcmToken = t
            try? await AppState.shared.api.registerDevice(token: t)
        }
    }

    func unregister() async {
        guard configured, let t = fcmToken ?? (try? await Messaging.messaging().token()) else { return }
        try? await AppState.shared.api.removeDevice(token: t)
    }

    // MARK: MessagingDelegate

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            self.fcmToken = fcmToken
            if let fcmToken, AppState.shared.isSignedIn { try? await AppState.shared.api.registerDevice(token: fcmToken) }
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    /// A tapped alert opens its product; a gold/dollar alert opens the alerts screen.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let type = info["type"] as? String
        let product = info["product_id"] as? String
        Task { @MainActor in
            if type == "market_alert" { AppState.shared.pendingRoute = .marketAlerts }
            else if let product, product.count == 36 { AppState.shared.pendingRoute = .product(product) }
        }
        completionHandler()
    }
}
