import Foundation
import SwiftUI

// 闹钟管理器类 - 负责处理闹钟列表、调度通知和持久化存储
class AlarmManager: ObservableObject {
    // 用于UI观察的已发布闹钟数组
    @Published var alarms: [Alarm] = []
    // 用于调度和取消通知的共享通知管理器
    private let notificationManager = NotificationManager.shared
    
    // 初始化时加载已保存的闹钟
    init() {
        loadAlarms()
    }
    
    // 添加新闹钟：生成随机触发时间，调度通知，并持久化存储
    func addAlarm(_ alarm: Alarm) {
        var newAlarm = alarm
        if newAlarm.isActive {
            newAlarm.generateRandomTime()  // 确保设置了随机时间
            notificationManager.scheduleNotification(for: newAlarm)
        }
        alarms.append(newAlarm)
        saveAlarms()
    }
    
    // 更新现有闹钟：取消旧通知，重新生成随机时间，如果闹钟处于激活状态则调度新通知
    func updateAlarm(_ alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            notificationManager.cancelNotification(for: alarms[index])
            var updatedAlarm = alarm
            if updatedAlarm.isActive {
                updatedAlarm.generateRandomTime()
                notificationManager.scheduleNotification(for: updatedAlarm)
            }
            alarms[index] = updatedAlarm
            saveAlarms()
        }
    }
    
    // 删除闹钟：取消已调度的通知并从列表中移除
    func deleteAlarm(_ alarm: Alarm) {
        notificationManager.cancelNotification(for: alarm)
        alarms.removeAll { $0.id == alarm.id }
        saveAlarms()
    }
    
    // 切换闹钟的激活状态：激活时重新生成时间并调度，停用时取消通知
    func toggleAlarm(_ alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            // 用数组里的 alarm 作为基础，避免副本导致的问题
            var updatedAlarm = alarms[index]
            updatedAlarm.isActive.toggle()
            if updatedAlarm.isActive {
                // 激活时，生成新的随机时间并调度通知
                updatedAlarm.generateRandomTime()
                notificationManager.cancelNotification(for: updatedAlarm)
                notificationManager.scheduleNotification(for: updatedAlarm)
            } else {
                // 停用时，取消任何待处理的通知
                notificationManager.cancelNotification(for: updatedAlarm)
            }
            alarms[index] = updatedAlarm
            saveAlarms()
        }
    }
    
    // 处理触发的闹钟：如果设置了重复日期则生成下一次时间，否则停用闹钟
    func handleAlarmTrigger(_ alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            notificationManager.cancelNotification(for: alarm)
            if !alarm.repeatDays.isEmpty {
                // 如果是重复闹钟，生成下一次触发时间
                var nextAlarm = alarm
                nextAlarm.generateRandomTime()
                notificationManager.scheduleNotification(for: nextAlarm)
                alarms[index] = nextAlarm
            } else {
                // 如果是单次闹钟，则停用
                var updatedAlarm = alarm
                updatedAlarm.isActive = false
                alarms[index] = updatedAlarm
            }
            saveAlarms()
        }
    }
    
    // MARK: - 持久化存储
    
    // 将闹钟数组保存到 UserDefaults
    private func saveAlarms() {
        if let encoded = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encoded, forKey: "alarms")
        }
    }
    
    // 从 UserDefaults 加载闹钟数组
    private func loadAlarms() {
        if let data = UserDefaults.standard.data(forKey: "alarms"),
           let decoded = try? JSONDecoder().decode([Alarm].self, from: data) {
            alarms = decoded
        }
    }
    
    // 获取指定闹钟的下一次触发时间
    func getNextTriggerTimeForAlarm(_ alarm: Alarm) -> Date? {
        guard alarm.isActive else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // 如果没有设置重复，直接使用设定的触发时间
        if alarm.repeatDays.isEmpty {
            // 确保是当天的触发时间
            let alarmHour = calendar.component(.hour, from: alarm.startTime)
            let alarmMinute = calendar.component(.minute, from: alarm.startTime)
            
            let todayTriggerDate = calendar.date(bySettingHour: alarmHour, minute: alarmMinute, second: 0, of: today)!
            
            // 如果今天的时间已经过了，返回明天的触发时间
            if todayTriggerDate < now {
                return calendar.date(byAdding: .day, value: 1, to: todayTriggerDate)
            } else {
                return todayTriggerDate
            }
        }
        
        // 处理重复闹钟
        // 获取今天是周几
        let todayWeekday = calendar.component(.weekday, from: now)
        
        // 按顺序存储接下来7天的日期
        var nextSevenDays: [Date] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                nextSevenDays.append(date)
            }
        }
        
        // 查找下一个符合重复规则的日期
        for dayOffset in 0..<7 {
            if let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                let targetWeekday = calendar.component(.weekday, from: targetDate)
                let weekday = Weekday(rawValue: targetWeekday)!
                
                if alarm.repeatDays.contains(weekday) {
                    // 获取闹钟时间
                    let alarmHour = calendar.component(.hour, from: alarm.startTime)
                    let alarmMinute = calendar.component(.minute, from: alarm.startTime)
                    
                    // 设置目标日期的时间部分
                    if let targetDateTime = calendar.date(bySettingHour: alarmHour, minute: alarmMinute, second: 0, of: targetDate) {
                        // 如果是今天但已经过了触发时间，则跳过
                        if dayOffset == 0 && targetDateTime < now {
                            continue
                        }
                        return targetDateTime
                    }
                }
            }
        }
        
        return nil
    }
} 