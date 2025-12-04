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
        
        FirebaseApp.configure()
        Database.database().isPersistenceEnabled = true
        
        UNUserNotificationCenter.current().delegate = self

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if let error = error {
                    print("❌ AppDelegate: Notification permission request failed: \(error)")
                } else {
                    print("✅ AppDelegate: Notification permission: \(granted ? "granted" : "denied")")
                }
            }
        ) 
        
        application.registerForRemoteNotifications()
        Messaging.messaging().delegate = self
        
        return true
    }
    
    // Successfully registered for remote notifications
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("✅ Device Token: \(token)")
        // ✅ Link APNs token with FCM so Firebase can route pushes through APNs
        Messaging.messaging().apnsToken = deviceToken
        
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
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification) async
    -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo

        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)

        // ...

        // Print full message.
        print(userInfo)

        // Change this to your preferred presentation option
        // Note: UNNotificationPresentationOptions.alert has been deprecated.
        if #available(iOS 14.0, *) {
          return [.list, .banner, .sound]
        } else {
          return [.alert, .sound]
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                          didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo

        // ...

        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)

        // Print full message.
        print(userInfo)
    }
    
    @MainActor
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async
      -> UIBackgroundFetchResult {
      // If you are receiving a notification message while your app is in the background,
      // this callback will not be fired till the user taps on the notification launching the application.
      // TODO: Handle data of notification

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
      return UIBackgroundFetchResult.newData
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
