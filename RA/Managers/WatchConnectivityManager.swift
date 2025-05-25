import Foundation
import WatchConnectivity
import UIKit
import UserNotifications

// Watch connectivity manager - handles communication between iPhone and Apple Watch
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    // Current session
    private let session = WCSession.default
    
    // Connection status
    @Published var isConnected = false
    @Published var isWatchAppInstalled = false
    
    // Sleep manager
    private let sleepManager = SleepManager.shared
    
    private override init() {
        super.init()
        
        // Check if device supports WatchConnectivity
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    // Send message to watch
    func sendMessageToWatch(message: [String: Any]) {
        guard session.activationState == .activated,
              session.isWatchAppInstalled else {
            print("⚠️ Watch connection not activated or Watch App not installed")
            return
        }
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("❌ Failed to send message to Watch: \(error.localizedDescription)")
        }
    }
    
    // Update connection status
    private func updateConnectionStatus() {
        DispatchQueue.main.async {
            self.isConnected = self.session.activationState == .activated
            self.isWatchAppInstalled = self.session.isWatchAppInstalled
        }
    }
    
    // Handle received sleep data
    private func handleSleepData(_ data: [String: Any]) {
        guard let startTime = data["startTime"] as? Date,
              let endTime = data["endTime"] as? Date,
              let stageValue = data["sleepStage"] as? Int,
              let sleepStage = SleepStage(rawValue: stageValue) else {
            print("❌ Invalid sleep data format")
            return
        }
        
        let sleepDataPoint = SleepDataPoint(startTime: startTime, endTime: endTime, sleepStage: sleepStage)
        // Update the sleep manager with the new data point
        DispatchQueue.main.async {
            self.sleepManager.sleepData.append(sleepDataPoint)
            self.sleepManager.saveData()
        }
    }
    
    // Handle wakeup event from Watch
    private func handleWakeupEvent(_ data: [String: Any]) {
        guard let wakeupData = data["data"] as? [String: String] else {
            print("❌ Invalid wakeup data format")
            return
        }
        
        // 将唤醒事件通过通知中心传递给SmartWakeManager
        NotificationCenter.default.post(
            name: NSNotification.Name("WakeTriggered"),
            object: nil,
            userInfo: wakeupData
        )
        
        // 确保应用处于激活状态来处理唤醒
        ensureAppIsActive()
    }
    
    // 确保应用处于活跃状态
    private func ensureAppIsActive() {
        // 检查应用是否在前台
        if UIApplication.shared.applicationState != .active {
            // 触发本地通知以唤醒应用
            let center = UNUserNotificationCenter.current()
            let content = UNMutableNotificationContent()
            content.title = "Time to Wake Up"
            content.body = "It's your optimal wake-up time!"
            content.sound = UNNotificationSound(named: UNNotificationSoundName("wakeup_sound.wav"))
            content.categoryIdentifier = "WAKE_ACTION"
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: "wakeupForeground", content: content, trigger: trigger)
            
            center.add(request) { error in
                if let error = error {
                    print("❌ Error scheduling notification: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    // Session activation state changed
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ Session activation failed: \(error.localizedDescription)")
            return
        }
        
        print("✅ Session activation state: \(activationState.rawValue)")
        updateConnectionStatus()
    }
    
    // Received message from Watch
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("📱 Received message from Watch: \(message)")
        
        // Check message type
        if let messageType = message["type"] as? String {
            switch messageType {
            case "sleepData":
                if let sleepData = message["data"] as? [String: Any] {
                    handleSleepData(sleepData)
                }
                
            case "wakeup":
                // 处理来自Watch的唤醒事件
                handleWakeupEvent(message)
                
            case "status":
                // Handle status update
                print("📱 Watch status update: \(message)")
                
            default:
                print("⚠️ Unknown message type: \(messageType)")
            }
        }
    }
    
    // The following methods must be implemented on iOS platform
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ Session became inactive")
        updateConnectionStatus()
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("⚠️ Session deactivated")
        // Reactivate session
        session.activate()
        updateConnectionStatus()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        print("🔄 Watch state changed")
        updateConnectionStatus()
    }
} 