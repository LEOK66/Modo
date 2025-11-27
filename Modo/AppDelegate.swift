import UIKit
import FirebaseDatabaseInternal
import FirebaseCore
import UserNotifications
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    let gcmMessageIDKey = "gcm.Message_ID"
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        
        // 1. 配置 Firebase
        FirebaseApp.configure()
        Database.database().isPersistenceEnabled = true
        
        // 2. 设置通知代理
        UNUserNotificationCenter.current().delegate = self
        
        // 3. 请求通知权限
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if let error = error {
                    print("❌ 通知权限请求失败: \(error)")
                } else {
                    print("✅ 通知权限: \(granted ? "已授予" : "被拒绝")")
                }
            }
        )
        
        // 4. 注册远程通知
        application.registerForRemoteNotifications()
        Messaging.messaging().delegate = self
        
        return true
    }
    
    // 注册成功回调
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("✅ Device Token: \(token)")
        // ✅ Link APNs token with FCM so Firebase can route pushes through APNs
        Messaging.messaging().apnsToken = deviceToken
        
        // 这里可以将 token 发送到你的服务器
    }
    
    // 注册失败回调
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ 远程通知注册失败: \(error)")
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
      print("Firebase registration token: \(String(describing: fcmToken))")

      let dataDict: [String: String] = ["token": fcmToken ?? ""]
      NotificationCenter.default.post(
        name: Notification.Name("FCMToken"),
        object: nil,
        userInfo: dataDict
      )
      // TODO: If necessary send token to application server.
      // Note: This callback is fired at each app startup and whenever a new token is generated.
    }
    
}
