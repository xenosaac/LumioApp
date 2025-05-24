import Foundation
import HealthKit
import UserNotifications
import WatchConnectivity

/// Smart Wake Manager: Chooses optimal wake time based on sleep cycles
class SmartWakeManager: ObservableObject {
    static let shared = SmartWakeManager()
    
    // Sleep and health data management
    private let healthStore = HKHealthStore()
    private let sleepManager = SleepManager.shared
    private let watchConnectivity = WatchConnectivityManager.shared
    
    // Wake window settings
    @Published var isSmartWakeEnabled = false
    @Published var wakeTimeWindow: TimeInterval = 30 * 60 // Default 30-minute wake window
    @Published var targetWakeTime: Date? // Target wake time
    @Published var isWakeActive = false // Whether there is currently an active wake task
    
    // Wake event records
    @Published var lastWakeEvent: WakeEvent?
    
    // Watch communication session ID
    private var currentSessionID: String?
    
    private init() {
        setupNotificationHandling()
        
        // Restore settings from UserDefaults
        isSmartWakeEnabled = UserDefaults.standard.bool(forKey: "isSmartWakeEnabled")
        wakeTimeWindow = UserDefaults.standard.double(forKey: "wakeTimeWindow")
        if wakeTimeWindow == 0 {
            wakeTimeWindow = 30 * 60 // Default 30 minutes
        }
        
        if let savedWakeTime = UserDefaults.standard.object(forKey: "targetWakeTime") as? Date {
            // Only restore unexpired wake times (within next 24 hours)
            if savedWakeTime > Date() && savedWakeTime < Date().addingTimeInterval(24 * 60 * 60) {
                targetWakeTime = savedWakeTime
                checkAndScheduleWake()
            }
        }
        
        // Restore last wake event (if any)
        if let wakeEventData = UserDefaults.standard.data(forKey: "lastWakeEvent"),
           let wakeEvent = try? JSONDecoder().decode(WakeEvent.self, from: wakeEventData) {
            lastWakeEvent = wakeEvent
        }
    }
    
    // Set up smart wake
    func scheduleSmartWake(at targetTime: Date) {
        targetWakeTime = targetTime
        
        // Save to UserDefaults
        UserDefaults.standard.set(targetTime, forKey: "targetWakeTime")
        UserDefaults.standard.set(isSmartWakeEnabled, forKey: "isSmartWakeEnabled")
        UserDefaults.standard.set(wakeTimeWindow, forKey: "wakeTimeWindow")
        
        // Set current state
        isWakeActive = true
        
        // Send to Apple Watch
        sendWakeConfigToWatch()
        
        // Check and schedule wake synchronously
        checkAndScheduleWake()
    }
    
    // Send wake configuration to Apple Watch
    private func sendWakeConfigToWatch() {
        guard let targetTime = targetWakeTime else { return }
        
        // Create unique session ID
        let sessionID = UUID().uuidString
        currentSessionID = sessionID
        
        // Build message
        let message: [String: Any] = [
            "type": "smartWakeConfig",
            "sessionID": sessionID,
            "targetWakeTime": targetTime.timeIntervalSince1970,
            "wakeWindow": wakeTimeWindow,
            "isEnabled": isSmartWakeEnabled
        ]
        
        // Send to Watch
        watchConnectivity.sendMessageToWatch(message: message)
    }
    
    // Cancel scheduled wake
    func cancelSmartWake() {
        isWakeActive = false
        
        // Remove from UserDefaults
        UserDefaults.standard.removeObject(forKey: "targetWakeTime")
        
        // Send cancel message to Watch
        let message: [String: Any] = [
            "type": "cancelWake",
            "sessionID": currentSessionID ?? ""
        ]
        
        watchConnectivity.sendMessageToWatch(message: message)
        
        // Cancel local notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["smartWake"])
    }
    
    // Check and schedule wake
    private func checkAndScheduleWake() {
        guard isSmartWakeEnabled, let targetTime = targetWakeTime else { return }
        
        // Calculate wake window start time
        let windowStartTime = targetTime.addingTimeInterval(-wakeTimeWindow)
        
        // If wake window end time has passed, cancel this wake
        if Date() > targetTime {
            isWakeActive = false
            return
        }
        
        // If within wake window, send start monitoring message to Watch
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
    
    // Configure notification handling
    private func setupNotificationHandling() {
        // Handle wake trigger events received from Watch
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWakeTriggered(_:)),
            name: NSNotification.Name("WakeTriggered"),
            object: nil
        )
    }
    
    // Handle wake trigger events
    @objc private func handleWakeTriggered(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let wakeTimeStr = userInfo["wakeTime"] as? String,
              let wakeStateStr = userInfo["wakeState"] as? String,
              let heartRateStr = userInfo["heartRate"] as? String,
              let sessionID = userInfo["sessionID"] as? String,
              sessionID == currentSessionID else {
            return
        }
        
        // Create wake event
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
            responseTime: nil // Will be updated when user responds to alarm
        )
        
        // Save wake event
        lastWakeEvent = wakeEvent
        saveWakeEvent(wakeEvent)
        
        // Trigger local notification
        triggerWakeNotification(wakeEvent)
    }
    
    // Save wake event
    private func saveWakeEvent(_ event: WakeEvent) {
        if let encoded = try? JSONEncoder().encode(event) {
            UserDefaults.standard.set(encoded, forKey: "lastWakeEvent")
        }
    }
    
    // Trigger wake notification
    private func triggerWakeNotification(_ event: WakeEvent) {
        // Get notification center
        let center = UNUserNotificationCenter.current()
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Time to Wake Up"
        content.body = "It's your optimal wake-up time!"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("wakeup_sound.wav"))
        content.categoryIdentifier = "WAKE_ACTION"
        content.userInfo = ["sessionID": currentSessionID ?? ""]
        
        // Create trigger (immediate trigger)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "smartWake",
            content: content,
            trigger: trigger
        )
        
        // Add request
        center.add(request) { error in
            if let error = error {
                print("Error adding notification: \(error.localizedDescription)")
            }
        }
    }
    
    // User responded to alarm
    func userRespondedToWake() {
        // Update wake event response time
        if var event = lastWakeEvent {
            event.responseTime = Date().timeIntervalSince(event.time)
            lastWakeEvent = event
            saveWakeEvent(event)
            
            // Save event to HealthKit (optional)
            if UserDefaults.standard.bool(forKey: "saveWakeDataToHealth") {
                saveWakeDataToHealthKit(event)
            }
        }
        
        // Send stop message to Watch
        let message: [String: Any] = [
            "type": "stopWake",
            "sessionID": currentSessionID ?? ""
        ]
        
        watchConnectivity.sendMessageToWatch(message: message)
        
        // Reset state
        isWakeActive = false
        targetWakeTime = nil
        UserDefaults.standard.removeObject(forKey: "targetWakeTime")
    }
    
    // Save wake data to HealthKit
    private func saveWakeDataToHealthKit(_ event: WakeEvent) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // Save heart rate sample
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

// Wake event data model
struct WakeEvent: Codable, Identifiable {
    var id = UUID()
    let time: Date // Actual wake time
    let targetTime: Date // Target wake time
    let heartRate: Double // Heart rate at wake time
    let wakeState: String // Sleep state at wake time (e.g. "light sleep")
    var responseTime: TimeInterval? // Time required for user to respond to alarm
    
    // Calculate if wake is within optimal wake window
    var isOptimalWake: Bool {
        return time < targetTime
    }
    
    // Calculate early wake time (minutes)
    var minutesEarly: Double {
        if isOptimalWake {
            return targetTime.timeIntervalSince(time) / 60.0
        } else {
            return 0
        }
    }
} 