import SwiftUI
import UserNotifications

struct AlarmTriggerView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    let alarm: Alarm
    let alarmManager: AlarmManager
    @Environment(\.dismiss) private var dismiss
    // 引用声音管理器单例
    private let soundManager = SoundManager.shared
    
    // 添加倒计时计时器
    @State private var remainingSeconds: Int = 300 // 5分钟 = 300秒
    @State private var timer: Timer?
    @State private var missedAlarmSent: Bool = false
    
    private func ensureAlarmExists() {
        print("[AlarmTriggerView] Ensuring alarm exists: \(alarm.id)")
        if !alarmManager.alarms.contains(where: { $0.id == alarm.id }) {
            print("[AlarmTriggerView] Adding alarm to alarmManager: \(alarm.id)")
            alarmManager.addAlarm(alarm)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Time's Up!")
                .font(.largeTitle)
                .bold()
            
            Text(alarm.name)
                .font(.title2)
            
            if let randomTime = alarm.randomTime {
                Text(randomTime.formatted(date: .omitted, time: .shortened))
                    .font(.title3)
            }
            
            // 显示剩余时间
            Text("Auto-dismiss in: \(formatTime(seconds: remainingSeconds))")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.top, 10)
            
            Button(action: dismissAlarm) {
                VStack {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 30))
                    Text("Dismiss")
                }
            }
            .padding(.top, 20)
        }
        .padding()
        .onAppear {
            ensureAlarmExists()
            // 开始播放闹钟声音，带渐增效果
            soundManager.loopSound(alarm.soundName, withFadeIn: true)
            // 启动倒计时计时器
            startTimer()
        }
        .onDisappear {
            // 停止闹钟声音
            soundManager.stopSound()
            // 取消计时器
            timer?.invalidate()
            notificationManager.triggeredAlarm = nil
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                if !missedAlarmSent {
                    // 时间到，自动dismiss并发送通知
                    sendMissedAlarmNotification()
                    missedAlarmSent = true
                    dismissAlarm()
                }
            }
        }
    }
    
    private func formatTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func sendMissedAlarmNotification() {
        // 创建本地通知
        let content = UNMutableNotificationContent()
        content.title = "Missed Alarm"
        content.body = "You missed an alarm: \(alarm.name)"
        content.sound = .default
        
        // 立即触发
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "missedAlarm-\(UUID().uuidString)", content: content, trigger: trigger)
        
        // 添加通知
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send missed alarm notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func dismissAlarm() {
        // 停止闹钟声音
        soundManager.stopSound()
        // 停止计时器
        timer?.invalidate()
        
        if alarm.isRepeating {
            var updatedAlarm = alarm
            updatedAlarm.generateRandomTime()
            alarmManager.updateAlarm(updatedAlarm)
        } else {
            var updatedAlarm = alarm
            updatedAlarm.isActive = false
            alarmManager.updateAlarm(updatedAlarm)
        }
        dismiss()
    }
} 
 