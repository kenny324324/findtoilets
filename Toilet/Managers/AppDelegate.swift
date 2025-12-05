//
//  AppDelegate.swift
//  Toilet
//
//  Created by Assistant on 2024/12/06.
//

import SwiftUI
import UserNotifications

// 使用 canImport 確保在 SDK 安裝前不會報錯
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    let gcmMessageIDKey = "gcm.message_id"

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // 1. 初始化 Firebase
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif

        // 2. 設定推播代理
        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        #endif
        
        // 3. 註冊遠端通知
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )
        
        application.registerForRemoteNotifications()
        
        return true
    }
    
    // 收到 Device Token 時 (APNs)
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        print("APNs Token 設定成功")
        #endif
    }
    
    // 註冊失敗時
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("無法註冊遠端通知: \(error.localizedDescription)")
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    // 當 App 在前景時收到通知
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        #if canImport(FirebaseMessaging)
        Messaging.messaging().appDidReceiveMessage(userInfo)
        #endif

        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }

        print(userInfo)

        // 設定在前景時也要跳出橫幅、播放聲音
        completionHandler([[.banner, .badge, .sound]])
    }

    // 當使用者點擊通知時
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        #if canImport(FirebaseMessaging)
        Messaging.messaging().appDidReceiveMessage(userInfo)
        #endif

        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }

        print(userInfo)

        completionHandler()
    }
}

// MARK: - MessagingDelegate (Firebase)
#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")

        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
        // 之後如果需要，可以在這裡把 Token 上傳到您的伺服器
    }
}
#endif

