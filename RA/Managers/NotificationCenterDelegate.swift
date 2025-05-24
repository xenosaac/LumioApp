import Foundation
import UserNotifications
import SwiftUI

/// 通知中心代理 - 处理通知的接收和用户响应
class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterDelegate()
    
    // 通知权限状态
    @Published var isAuthorized = false
    
    override init() {
        super.init()
        requestAuthorization()
    }
    
    // 请求通知授权
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                
                if granted {
                    self.setupNotificationCategories()
                } else if let error = error {
                    print("通知授权错误: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 设置通知类别和操作
    private func setupNotificationCategories() {
        // 唤醒动作
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "Dismiss",
            options: .foreground
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze 5 Minutes",
            options: .foreground
        )
        
        // 创建唤醒类别
        let wakeCategory = UNNotificationCategory(
            identifier: "WAKE_ACTION",
            actions: [dismissAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        // 注册类别
        UNUserNotificationCenter.current().setNotificationCategories([wakeCategory])
    }
    
    // 前台接收通知时的处理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 允许在前台显示通知
        completionHandler([.banner, .sound, .badge])
        
        // 处理闹钟通知
        if let alarmId = notification.request.content.userInfo["alarmId"] as? String {
            // 发送通知给 NotificationManager
            NotificationCenter.default.post(
                name: Notification.Name("AlarmNotificationResponse"), 
                object: nil, 
                userInfo: ["alarmId": alarmId]
            )
        }
    }
    
    // 用户响应通知时的处理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        // 处理特定类别的通知
        switch response.notification.request.content.categoryIdentifier {
        case "WAKE_ACTION":
            handleWakeAction(actionIdentifier, userInfo: userInfo)
        default:
            // 处理普通闹钟通知
            if let alarmId = userInfo["alarmId"] as? String {
                // 发送通知给 NotificationManager
                NotificationCenter.default.post(
                    name: Notification.Name("AlarmNotificationResponse"), 
                    object: nil, 
                    userInfo: ["alarmId": alarmId]
                )
            }
        }
        
        completionHandler()
    }
    
    // 处理唤醒通知的用户响应
    private func handleWakeAction(_ actionIdentifier: String, userInfo: [AnyHashable: Any]) {
        switch actionIdentifier {
        case "DISMISS_ACTION", UNNotificationDefaultActionIdentifier:
            // 用户点击或滑动通知，或点击"Dismiss"按钮
            SmartWakeManager.shared.userRespondedToWake()
            
        case "SNOOZE_ACTION":
            // 用户点击了"Snooze"按钮
            // 先响应当前唤醒
            SmartWakeManager.shared.userRespondedToWake()
            
            // 然后设置5分钟后的新唤醒
            let newWakeTime = Date().addingTimeInterval(5 * 60)
            SmartWakeManager.shared.scheduleSmartWake(at: newWakeTime)
            
        default:
            break
        }
    }
} 