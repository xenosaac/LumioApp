import Foundation
import WatchConnectivity
import HealthKit
#if os(watchOS)
import WatchKit
#endif
import UserNotifications

/// Watch端智能唤醒扩展 - 处理睡眠监测和唤醒触发
/// 这段代码将被包含在Watch App的Extension中
class WatchSmartWakeManager: NSObject, ObservableObject {
    static let shared = WatchSmartWakeManager()
    
    // 基本配置
    @Published var isMonitoring = false
    @Published var targetWakeTime: Date?
    @Published var wakeWindow: TimeInterval = 30 * 60 // 默认唤醒窗口30分钟
    @Published var currentSessionID: String?
    
    // 监测状态
    @Published var lastHeartRate: Double = 0
    @Published var movementDetected = false
    @Published var lastSleepState: SleepState = .unknown
    
    // 数据记录
    private var monitoringData: [SleepMonitoringPoint] = []
    private let dataStorageKey = "sleepMonitoringData"
    
    // 健康数据访问
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKQuery?
    #if os(watchOS)
    private var runtimeSession: WKExtendedRuntimeSession?
    #endif
    
    // 上次心率和移动检测时间
    private var lastHeartRateReadingTime: Date?
    private var movementDetectionTimes: [Date] = []
    
    private override init() {
        super.init()
        
        // 加载保存的监测数据
        loadMonitoringData()
        
        // 设置WCSession
        setupWCSession()
        
        // 检查处于活跃状态的会话
        checkForActiveSession()
    }
    
    // 设置Watch连接会话
    private func setupWCSession() {
        guard WCSession.isSupported() else { return }
        
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
    
    // 检查是否有活跃的监测会话
    private func checkForActiveSession() {
        if let sessionData = UserDefaults.standard.dictionary(forKey: "activeWakeSession") {
            if let targetTimeInterval = sessionData["targetWakeTime"] as? TimeInterval,
               let sessionID = sessionData["sessionID"] as? String,
               let wakeWindowValue = sessionData["wakeWindow"] as? TimeInterval {
                
                let targetTime = Date(timeIntervalSince1970: targetTimeInterval)
                
                // 如果目标时间还在未来并且在24小时内
                if targetTime > Date() && targetTime < Date().addingTimeInterval(24 * 60 * 60) {
                    currentSessionID = sessionID
                    targetWakeTime = targetTime
                    wakeWindow = wakeWindowValue
                    
                    // 检查是否应该开始监测
                    let windowStartTime = targetTime.addingTimeInterval(-wakeWindow)
                    if Date() >= windowStartTime {
                        startMonitoring()
                    }
                }
            }
        }
    }
    
    // 开始睡眠监测
    func startMonitoring() {
        guard let targetTime = targetWakeTime else { return }
        
        // 保存会话信息
        if let sessionID = currentSessionID {
            UserDefaults.standard.set([
                "targetWakeTime": targetTime.timeIntervalSince1970,
                "sessionID": sessionID,
                "wakeWindow": wakeWindow
            ], forKey: "activeWakeSession")
        }
        
        // 如果已经过了目标时间，则不开始
        if Date() > targetTime {
            return
        }
        
        // 开始扩展运行时会话
        startExtendedRuntimeSession()
        
        // 开始心率监测
        startHeartRateMonitoring()
        
        // 设置定时器以在目标时间强制唤醒
        setupForcedWakeTimer()
        
        isMonitoring = true
    }
    
    // 开始扩展运行时会话（保持Watch App在后台运行）
    private func startExtendedRuntimeSession() {
        #if os(watchOS)
        runtimeSession = WKExtendedRuntimeSession()
        runtimeSession?.start()
        #endif
    }
    
    // 开始心率监测
    private func startHeartRateMonitoring() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // 请求授权访问心率数据
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let motionTypes = Set([
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ])
        let typesToRead = Set([heartRateType]).union(motionTypes)
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            guard let self = self, success else {
                print("Failed to get authorization for heart rate: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            
            // 配置心率查询
            let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)
            let updateHandler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = { _, samples, _, _, error in
                if let error = error {
                    print("Heart rate query error: \(error.localizedDescription)")
                    return
                }
                
                guard let samples = samples as? [HKQuantitySample] else { return }
                
                DispatchQueue.main.async {
                    // 处理最新的心率样本
                    if let lastSample = samples.last {
                        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                        let heartRate = lastSample.quantity.doubleValue(for: heartRateUnit)
                        
                        self.lastHeartRate = heartRate
                        self.lastHeartRateReadingTime = lastSample.endDate
                        
                        // 记录监测点
                        self.recordMonitoringPoint(
                            heartRate: heartRate,
                            time: lastSample.endDate,
                            movementDetected: self.checkForRecentMovement(at: lastSample.endDate)
                        )
                        
                        // 评估是否为浅睡眠状态
                        self.evaluateSleepState()
                        
                        // 检查唤醒条件
                        self.checkWakeUpConditions()
                    }
                }
            }
            
            // 创建并执行查询
            let heartRateQuery = HKAnchoredObjectQuery(
                type: heartRateType,
                predicate: predicate,
                anchor: nil,
                limit: HKObjectQueryNoLimit,
                resultsHandler: updateHandler
            )
            
            heartRateQuery.updateHandler = updateHandler
            
            self.healthStore.execute(heartRateQuery)
            self.heartRateQuery = heartRateQuery
            
            // 开始监测活动/移动
            self.startMotionMonitoring()
        }
    }
    
    // 开始移动监测
    private func startMotionMonitoring() {
        // 每分钟检查移动状态
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkActivityStatus()
        }
    }
    
    // 检查活动状态
    private func checkActivityStatus() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // 查询最近一分钟的步数
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-60),
            end: Date(),
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, error in
            guard let self = self, let result = result, error == nil else { return }
            
            if let sum = result.sumQuantity() {
                let steps = sum.doubleValue(for: HKUnit.count())
                
                // 如果检测到步数，记录移动状态
                if steps > 0 {
                    DispatchQueue.main.async {
                        self.movementDetected = true
                        self.movementDetectionTimes.append(Date())
                        
                        // 只保留最近10分钟的移动记录
                        self.movementDetectionTimes = self.movementDetectionTimes.filter {
                            $0 > Date().addingTimeInterval(-600)
                        }
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    // 检查最近是否有移动
    private func checkForRecentMovement(at time: Date) -> Bool {
        // 检查过去3分钟内是否有移动记录
        return movementDetectionTimes.contains { 
            abs($0.timeIntervalSince(time)) < 180
        }
    }
    
    // 评估睡眠状态
    private func evaluateSleepState() {
        // 获取最近5分钟的监测点
        let recentPoints = monitoringData.filter {
            $0.timestamp > Date().addingTimeInterval(-300)
        }
        
        // 至少需要3个点来评估
        guard recentPoints.count >= 3 else {
            lastSleepState = .unknown
            return
        }
        
        // 计算心率波动
        let heartRates = recentPoints.map { $0.heartRate }
        let maxHR = heartRates.max() ?? 0
        let minHR = heartRates.min() ?? 0
        let hrVariation = maxHR - minHR
        
        // 检查是否有轻微移动
        let hasSlightMovement = recentPoints.contains { $0.movementDetected } && 
                               !recentPoints.allSatisfy { $0.movementDetected }
        
        // 浅睡判断条件: 心率波动小 (< 5bpm) + 有轻微移动
        if hrVariation < 5 && hasSlightMovement {
            lastSleepState = .light
        } 
        // 深睡判断: 心率波动极小且非常稳定，没有移动
        else if hrVariation < 3 && !hasSlightMovement {
            lastSleepState = .deep
        } 
        // 清醒或REM睡眠: 心率波动较大或有频繁移动
        else if hrVariation > 7 || (hasSlightMovement && heartRates.last ?? 0 > heartRates.first ?? 0 + 5) {
            lastSleepState = .awakeOrREM
        } 
        else {
            lastSleepState = .medium
        }
    }
    
    // 检查唤醒条件
    private func checkWakeUpConditions() {
        guard let targetTime = targetWakeTime,
              isMonitoring,
              Date() >= targetTime.addingTimeInterval(-wakeWindow),
              Date() <= targetTime else {
            return
        }
        
        // 如果检测到浅睡眠状态，触发唤醒
        if lastSleepState == .light {
            triggerWakeUp()
        }
        // 如果距离强制唤醒时间不到60秒，且用户处于非深睡眠状态，也触发唤醒
        else if Date() > targetTime.addingTimeInterval(-60) && lastSleepState != .deep {
            triggerWakeUp()
        }
    }
    
    // 设置强制唤醒定时器
    private func setupForcedWakeTimer() {
        guard let targetTime = targetWakeTime else { return }
        
        // 计算到目标时间的时间间隔
        let timeInterval = targetTime.timeIntervalSince(Date())
        
        // 如果时间间隔有效，设置定时器
        if timeInterval > 0 {
            Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                self?.triggerWakeUp()
            }
        }
    }
    
    // 触发唤醒
    private func triggerWakeUp() {
        // 防止重复触发
        guard isMonitoring, !UserDefaults.standard.bool(forKey: "wakeupTriggered") else { return }
        
        // 标记已触发
        UserDefaults.standard.set(true, forKey: "wakeupTriggered")
        
        // 记录唤醒数据
        let wakeupData = [
            "wakeTime": ISO8601DateFormatter().string(from: Date()),
            "heartRate": "\(lastHeartRate)",
            "wakeState": lastSleepState.description,
            "sessionID": currentSessionID ?? ""
        ]
        
        // 保存唤醒数据
        UserDefaults.standard.set(wakeupData, forKey: "lastWakeupData")
        
        // 通知iPhone
        sendWakeupEventToiPhone(wakeupData)
        
        // 本地触发手表振动和提示
        triggerLocalWakeupNotification()
        
        // 保存完整监测数据
        saveMonitoringData()
        
        // 停止心率监测但保持会话活跃直到用户响应
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
    }
    
    // 发送唤醒事件到iPhone
    private func sendWakeupEventToiPhone(_ wakeupData: [String: String]) {
        if WCSession.default.activationState == .activated && 
           WCSession.default.isReachable {
            WCSession.default.sendMessage(
                ["type": "wakeup", "data": wakeupData],
                replyHandler: nil,
                errorHandler: { error in
                    print("Error sending wakeup to iPhone: \(error.localizedDescription)")
                }
            )
        }
    }
    
    // 触发本地唤醒通知（振动和声音）
    private func triggerLocalWakeupNotification() {
        // 获取通知中心
        let center = UNUserNotificationCenter.current()
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "Wake Up Time"
        content.body = "It's your optimal wake-up time. Check your iPhone to dismiss."
        content.sound = UNNotificationSound.default
        
        // 设置触发器（立即触发）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // 创建通知请求
        let request = UNNotificationRequest(
            identifier: "wakeupAlert",
            content: content,
            trigger: trigger
        )
        
        // 添加通知请求
        center.add(request)
        
        // 触发手表振动
        #if os(watchOS)
        WKInterfaceDevice.current().play(.notification)
        #endif
    }
    
    // 停止监测
    func stopMonitoring() {
        // 停止心率查询
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        
        // 结束扩展运行时会话
        #if os(watchOS)
        runtimeSession?.invalidate()
        runtimeSession = nil
        #endif
        
        // 清除状态
        isMonitoring = false
        UserDefaults.standard.removeObject(forKey: "activeWakeSession")
        UserDefaults.standard.removeObject(forKey: "wakeupTriggered")
        
        // 保存数据并清除
        saveMonitoringData()
        monitoringData = []
    }
    
    // 记录监测点
    private func recordMonitoringPoint(heartRate: Double, time: Date, movementDetected: Bool) {
        let point = SleepMonitoringPoint(
            timestamp: time,
            heartRate: heartRate,
            movementDetected: movementDetected,
            sleepState: lastSleepState
        )
        
        monitoringData.append(point)
        
        // 定期保存数据，防止丢失
        if monitoringData.count % 10 == 0 {
            saveMonitoringData()
        }
    }
    
    // 保存监测数据
    private func saveMonitoringData() {
        if let encoded = try? JSONEncoder().encode(monitoringData) {
            UserDefaults.standard.set(encoded, forKey: dataStorageKey)
        }
    }
    
    // 加载监测数据
    private func loadMonitoringData() {
        if let savedData = UserDefaults.standard.data(forKey: dataStorageKey),
           let loadedData = try? JSONDecoder().decode([SleepMonitoringPoint].self, from: savedData) {
            monitoringData = loadedData
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchSmartWakeManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // 处理会话激活
        print("WCSession activation state: \(activationState.rawValue)")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // 处理来自iPhone的消息
        DispatchQueue.main.async {
            guard let messageType = message["type"] as? String else { return }
            
            switch messageType {
            case "smartWakeConfig":
                // 接收智能唤醒配置
                if let targetTimeInterval = message["targetWakeTime"] as? TimeInterval,
                   let sessionID = message["sessionID"] as? String,
                   let wakeWindow = message["wakeWindow"] as? TimeInterval,
                   let isEnabled = message["isEnabled"] as? Bool,
                   isEnabled {
                    
                    self.targetWakeTime = Date(timeIntervalSince1970: targetTimeInterval)
                    self.wakeWindow = wakeWindow
                    self.currentSessionID = sessionID
                    
                    // 检查是否应该立即开始监测
                    let windowStartTime = self.targetWakeTime?.addingTimeInterval(-self.wakeWindow)
                    if let startTime = windowStartTime, Date() >= startTime {
                        self.startMonitoring()
                    }
                }
                
            case "startMonitoring":
                // 开始监测命令
                if let sessionID = message["sessionID"] as? String {
                    self.currentSessionID = sessionID
                    
                    if !self.isMonitoring {
                        self.startMonitoring()
                    }
                }
                
            case "stopWake":
                // 停止唤醒命令（用户已在iPhone上响应）
                self.stopMonitoring()
                
            case "cancelWake":
                // 取消唤醒命令
                self.stopMonitoring()
                
            default:
                break
            }
        }
    }
    
    // iOS-specific required WCSessionDelegate methods
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        // Reactivate session after it deactivates
        session.activate()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        print("WCSession watch state changed")
    }
    #endif
}

// 睡眠状态枚举
enum SleepState: Codable, Equatable {
    case unknown
    case deep
    case medium
    case light
    case awakeOrREM
    
    var description: String {
        switch self {
        case .unknown: return "unknown"
        case .deep: return "deep sleep"
        case .medium: return "normal sleep"
        case .light: return "light sleep"
        case .awakeOrREM: return "REM/awake"
        }
    }
}

// 睡眠监测点数据模型
struct SleepMonitoringPoint: Codable, Identifiable {
    var id = UUID()
    let timestamp: Date
    let heartRate: Double
    let movementDetected: Bool
    let sleepState: SleepState
} 