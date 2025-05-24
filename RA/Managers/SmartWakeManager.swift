import Foundation
import HealthKit
import UserNotifications
import WatchConnectivity

/// 智能唤醒管理器：根据睡眠周期选择最佳唤醒时间
class SmartWakeManager: ObservableObject {
    static let shared = SmartWakeManager()
    
    // 睡眠和健康数据管理
    private let healthStore = HKHealthStore()
    private let sleepManager = SleepManager.shared
    private let watchConnectivity = WatchConnectivityManager.shared
    
    // 唤醒区间设置
    @Published var isSmartWakeEnabled = false
    @Published var wakeTimeWindow: TimeInterval = 30 * 60 // 默认30分钟唤醒窗口
    @Published var targetWakeTime: Date? // 目标唤醒时间
    @Published var isWakeActive = false // 当前是否有活跃的唤醒任务
    
    // 唤醒事件记录
    @Published var lastWakeEvent: WakeEvent?
    
    // 手表通信会话ID
    private var currentSessionID: String?
    
    private init() {
        setupNotificationHandling()
        
        // 从UserDefaults恢复设置
        isSmartWakeEnabled = UserDefaults.standard.bool(forKey: "isSmartWakeEnabled")
        wakeTimeWindow = UserDefaults.standard.double(forKey: "wakeTimeWindow")
        if wakeTimeWindow == 0 {
            wakeTimeWindow = 30 * 60 // 默认30分钟
        }
        
        if let savedWakeTime = UserDefaults.standard.object(forKey: "targetWakeTime") as? Date {
            // 仅恢复未过期的唤醒时间（未来24小时内）
            if savedWakeTime > Date() && savedWakeTime < Date().addingTimeInterval(24 * 60 * 60) {
                targetWakeTime = savedWakeTime
                checkAndScheduleWake()
            }
        }
        
        // 恢复上次唤醒事件（如果有）
        if let wakeEventData = UserDefaults.standard.data(forKey: "lastWakeEvent"),
           let wakeEvent = try? JSONDecoder().decode(WakeEvent.self, from: wakeEventData) {
            lastWakeEvent = wakeEvent
        }
    }
    
    // 设置智能唤醒
    func scheduleSmartWake(at targetTime: Date) {
        targetWakeTime = targetTime
        
        // 保存到UserDefaults
        UserDefaults.standard.set(targetTime, forKey: "targetWakeTime")
        UserDefaults.standard.set(isSmartWakeEnabled, forKey: "isSmartWakeEnabled")
        UserDefaults.standard.set(wakeTimeWindow, forKey: "wakeTimeWindow")
        
        // 设置当前状态
        isWakeActive = true
        
        // 发送到Apple Watch
        sendWakeConfigToWatch()
        
        // 同步检查并安排唤醒
        checkAndScheduleWake()
    }
    
    // 发送唤醒配置到Apple Watch
    private func sendWakeConfigToWatch() {
        guard let targetTime = targetWakeTime else { return }
        
        // 创建唯一会话ID
        let sessionID = UUID().uuidString
        currentSessionID = sessionID
        
        // 构建消息
        let message: [String: Any] = [
            "type": "smartWakeConfig",
            "sessionID": sessionID,
            "targetWakeTime": targetTime.timeIntervalSince1970,
            "wakeWindow": wakeTimeWindow,
            "isEnabled": isSmartWakeEnabled
        ]
        
        // 发送到Watch
        watchConnectivity.sendMessageToWatch(message: message)
    }
    
    // 取消设定的唤醒
    func cancelSmartWake() {
        isWakeActive = false
        
        // 从UserDefaults中移除
        UserDefaults.standard.removeObject(forKey: "targetWakeTime")
        
        // 向Watch发送取消消息
        let message: [String: Any] = [
            "type": "cancelWake",
            "sessionID": currentSessionID ?? ""
        ]
        
        watchConnectivity.sendMessageToWatch(message: message)
        
        // 取消本地通知
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["smartWake"])
    }
    
    // 检查并安排唤醒
    private func checkAndScheduleWake() {
        guard isSmartWakeEnabled, let targetTime = targetWakeTime else { return }
        
        // 计算唤醒窗口开始时间
        let windowStartTime = targetTime.addingTimeInterval(-wakeTimeWindow)
        
        // 如果已经过了唤醒窗口结束时间，取消此次唤醒
        if Date() > targetTime {
            isWakeActive = false
            return
        }
        
        // 如果在唤醒窗口内，发送立即开始监测消息到Watch
        if Date() >= windowStartTime && Date() <= targetTime {
            let message: [String: Any] = [
                "type": "startMonitoring",
                "sessionID": currentSessionID ?? UUID().uuidString,
                "targetWakeTime": targetTime.timeIntervalSince1970,
                "remainingTime": targetTime.timeIntervalSince(Date())
            ]
            
            watchConnectivity.sendMessageToWatch(message: message)
        }
    }
    
    // 配置通知处理
    private func setupNotificationHandling() {
        // 处理从Watch接收的唤醒触发事件
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWakeTriggered(_:)),
            name: NSNotification.Name("WakeTriggered"),
            object: nil
        )
    }
    
    // 处理唤醒触发事件
    @objc private func handleWakeTriggered(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let wakeTimeStr = userInfo["wakeTime"] as? String,
              let wakeStateStr = userInfo["wakeState"] as? String,
              let heartRateStr = userInfo["heartRate"] as? String,
              let sessionID = userInfo["sessionID"] as? String,
              sessionID == currentSessionID else {
            return
        }
        
        // 创建唤醒事件
        let dateFormatter = ISO8601DateFormatter()
        
        guard let wakeTime = dateFormatter.date(from: wakeTimeStr),
              let heartRate = Double(heartRateStr) else {
            return
        }
        
        let wakeEvent = WakeEvent(
            time: wakeTime,
            targetTime: targetWakeTime ?? Date(),
            heartRate: heartRate,
            wakeState: wakeStateStr,
            responseTime: nil // 将在用户响应闹钟时更新
        )
        
        // 保存唤醒事件
        lastWakeEvent = wakeEvent
        saveWakeEvent(wakeEvent)
        
        // 触发本地通知
        triggerWakeNotification(wakeEvent)
    }
    
    // 保存唤醒事件
    private func saveWakeEvent(_ event: WakeEvent) {
        if let encoded = try? JSONEncoder().encode(event) {
            UserDefaults.standard.set(encoded, forKey: "lastWakeEvent")
        }
    }
    
    // 触发唤醒通知
    private func triggerWakeNotification(_ event: WakeEvent) {
        // 获取通知中心
        let center = UNUserNotificationCenter.current()
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "Time to Wake Up"
        content.body = "It's your optimal wake-up time!"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("wakeup_sound.wav"))
        content.categoryIdentifier = "WAKE_ACTION"
        content.userInfo = ["sessionID": currentSessionID ?? ""]
        
        // 创建触发器（立即触发）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // 创建请求
        let request = UNNotificationRequest(
            identifier: "smartWake",
            content: content,
            trigger: trigger
        )
        
        // 添加请求
        center.add(request) { error in
            if let error = error {
                print("Error adding notification: \(error.localizedDescription)")
            }
        }
    }
    
    // 用户响应闹钟
    func userRespondedToWake() {
        // 更新唤醒事件的响应时间
        if var event = lastWakeEvent {
            event.responseTime = Date().timeIntervalSince(event.time)
            lastWakeEvent = event
            saveWakeEvent(event)
            
            // 将事件保存到HealthKit（可选）
            if UserDefaults.standard.bool(forKey: "saveWakeDataToHealth") {
                saveWakeDataToHealthKit(event)
            }
        }
        
        // 发送停止消息给Watch
        let message: [String: Any] = [
            "type": "stopWake",
            "sessionID": currentSessionID ?? ""
        ]
        
        watchConnectivity.sendMessageToWatch(message: message)
        
        // 重置状态
        isWakeActive = false
        targetWakeTime = nil
        UserDefaults.standard.removeObject(forKey: "targetWakeTime")
    }
    
    // 保存唤醒数据到HealthKit
    private func saveWakeDataToHealthKit(_ event: WakeEvent) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // 保存心率样本
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
            let heartRateQuantity = HKQuantity(unit: heartRateUnit, doubleValue: event.heartRate)
            let heartRateSample = HKQuantitySample(
                type: heartRateType,
                quantity: heartRateQuantity,
                start: event.time,
                end: event.time
            )
            
            healthStore.save(heartRateSample) { success, error in
                if let error = error {
                    print("Error saving heart rate to HealthKit: \(error.localizedDescription)")
                }
            }
        }
    }
}

// 唤醒事件数据模型
struct WakeEvent: Codable, Identifiable {
    var id = UUID()
    let time: Date // 实际唤醒时间
    let targetTime: Date // 目标唤醒时间
    let heartRate: Double // 唤醒时的心率
    let wakeState: String // 唤醒时的睡眠状态 (如 "light sleep")
    var responseTime: TimeInterval? // 用户响应闹钟所需的时间
    
    // 计算是否在最佳唤醒窗口内
    var isOptimalWake: Bool {
        return time < targetTime
    }
    
    // 计算提前唤醒的时间（分钟）
    var minutesEarly: Double {
        if isOptimalWake {
            return targetTime.timeIntervalSince(time) / 60.0
        } else {
            return 0
        }
    }
} 