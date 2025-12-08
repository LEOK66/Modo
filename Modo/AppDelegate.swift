import UIKit
import FirebaseDatabaseInternal
import FirebaseCore
import FirebaseAuth
import UserNotifications
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    let gcmMessageIDKey = "gcm.Message_ID"
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        // Detect unit test runs and skip Firebase initialization in that case.
        let runningUnitTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        // Optional CI override: set SKIP_FIREBASE_INIT=1 to force skipping initialization
        let skipFirebaseEnv = ProcessInfo.processInfo.environment["SKIP_FIREBASE_INIT"] == "1"

        if runningUnitTests || skipFirebaseEnv {
            print("⚠️ Skipping FirebaseApp.configure() (runningUnitTests=\(runningUnitTests), skipFirebaseEnv=\(skipFirebaseEnv))")
        } else {
            FirebaseApp.configure()
            Database.database().isPersistenceEnabled = true

            UNUserNotificationCenter.current().delegate = self

            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions
            ) { granted, error in
                if let error = error {
                    print("❌ AppDelegate: Notification permission request failed: \(error)")
                } else {
                  print("✅ AppDelegate: Notification permission: \(granted ? "granted" : "denied")")
                }
            }

            application.registerForRemoteNotifications()
            Messaging.messaging().delegate = self
        }

        return true
    }

    // Failed to register for remote notifications
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ AppDelegate: Failed to register for remote notifications: \(error)")
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    // Called when a notification is delivered to a foreground app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)

        // ...

        // Print full message.
        print(userInfo)

        // Present as banner/list + sound on modern iOS, fall back to alert + sound otherwise
        if #available(iOS 14.0, *) {
            completionHandler([.list, .banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }

    // Called when the user interacts with a notification (app launched or tapped).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // ...

        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)

        // Print full message.
        print(userInfo)

        completionHandler()
    }

    // Handle remote notification with background fetch
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)

        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }

        // Print full message.
        print(userInfo)
        print("Call exportDeliveryMetricsToBigQuery() from AppDelegate")
        Messaging.serviceExtension().exportDeliveryMetricsToBigQuery(withMessageInfo: userInfo)

        completionHandler(.newData)
    }
}


extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("⚠️ AppDelegate: Received nil FCM token")
            return
        }

        print("✅ AppDelegate: Firebase registration token: \(fcmToken)")

        // Post notification for app to handle if needed
        let dataDict: [String: String] = ["token": fcmToken]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )

        // Save FCM token to Firebase database if user is authenticated
        if let userId = Auth.auth().currentUser?.uid {
            DatabaseService.shared.saveFCMToken(userId: userId, fcmToken: fcmToken) { result in
                switch result {
                case .success:
                    print("✅ AppDelegate: FCM token saved to database for user \(userId)")
                case .failure(let error):
                    print("❌ AppDelegate: Failed to save FCM token to database: \(error.localizedDescription)")
                }
            }
        } else {
            print("⚠️ AppDelegate: User not authenticated, FCM token will be saved after login")
        }
    }
}
