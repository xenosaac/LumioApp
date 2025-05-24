import Foundation
import UserNotifications
import SwiftUI

// 通知管理器类 - 处理闹钟的用户通知，包括调度和响应点击
class NotificationManager: ObservableObject {
    // 单例共享实例
    static let shared = NotificationManager()
    // 当通知被点击时触发UI更新的已发布属性
    @Published var triggeredAlarm: Alarm?
    // 新增：主用 AlarmManager 的弱引用
    weak var alarmManager: AlarmManager?
    
    private init() {
        // 请求通知权限并设置代理以处理通知点击
        requestAuthorization()
        setupNotificationCenter()
    }
    
    // 请求用户授权通知权限
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("通知权限已授予")
            } else if let error = error {
                print("请求通知权限时出错: \(error.localizedDescription)")
            }
        }
    }
    
    // 设置 UNUserNotificationCenter 代理
    private func setupNotificationCenter() {
        UNUserNotificationCenter.current().delegate = NotificationCenterDelegate.shared
        
        // 添加观察者以监听来自通知中心代理的回调
        NotificationCenter.default.addObserver(self, 
            selector: #selector(handleNotificationResponse), 
            name: Notification.Name("AlarmNotificationResponse"), 
            object: nil)
    }
    
    // 处理通知响应的观察者方法
    @objc func handleNotificationResponse(_ notification: Notification) {
        if let alarmId = notification.userInfo?["alarmId"] as? String {
            handleNotificationTap(alarmId: alarmId)
        }
    }
    
    // 为特定闹钟调度一次性通知
    func scheduleNotification(for alarm: Alarm) {
        guard let randomTime = alarm.randomTime else { return }
        print("[NotificationManager] Scheduling notification for alarm id: \(alarm.id.uuidString) at time: \(randomTime)")
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "Alarm"
        // alarm.name is non-optional and set to "Alarm" if empty by user input in AddAlarmView
        content.body = alarm.name
        content.sound = .default
        content.userInfo = ["alarmId": alarm.id.uuidString]
        
        // 从随机时间中提取日期组件
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: randomTime)
        
        // 创建基于日历的触发器
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)
        
        // 添加通知请求
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationManager] Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("[NotificationManager] Notification scheduled successfully for id: \(alarm.id.uuidString)")
            }
        }
    }
    
    // 移除特定闹钟的所有已调度通知
    func cancelNotification(for alarm: Alarm) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [alarm.id.uuidString])
    }
    
    // 当通知被点击时调用：设置 triggeredAlarm 以显示UI
    func handleNotificationTap(alarmId: String) {
        print("[NotificationManager] handleNotificationTap called with alarmId: \(alarmId)")
        // Try in-memory alarms first
        if let manager = alarmManager,
           let alarm = manager.alarms.first(where: { $0.id.uuidString == alarmId }) {
            DispatchQueue.main.async {
                print("[NotificationManager] Setting triggeredAlarm for alarm: \(alarm.id.uuidString)")
                self.triggeredAlarm = alarm
            }
            return
        }
        // Fallback: load from persistent storage
        if let data = UserDefaults.standard.data(forKey: "alarms"),
           let decoded = try? JSONDecoder().decode([Alarm].self, from: data),
           let alarm = decoded.first(where: { $0.id.uuidString == alarmId }) {
            DispatchQueue.main.async {
                print("[NotificationManager] Setting triggeredAlarm (from storage) for alarm: \(alarm.id.uuidString)")
                self.triggeredAlarm = alarm
            }
        } else {
            print("[NotificationManager] Alarm not found in memory or storage for id: \(alarmId)")
        }
    }
    
    // 为重复闹钟调度下一次触发
    func scheduleNextNotification(for alarm: Alarm) {
        if alarm.isRepeating {
            var nextAlarm = alarm
            nextAlarm.generateRandomTime()
            scheduleNotification(for: nextAlarm)
        }
    }
    
    // MARK: - Alarm Notifications
    
    func scheduleAlarmNotification(for alarm: Alarm) {
        // Create a notification content for alarm
        let content = UNMutableNotificationContent()
        content.title = "Alarm"
        content.body = alarm.name
        content.sound = UNNotificationSound(named: UNNotificationSoundName(alarm.soundName + ".wav"))
    }
} 