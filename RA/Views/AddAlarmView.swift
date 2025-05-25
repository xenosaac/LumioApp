import SwiftUI

struct AddAlarmView: View {
    @Environment(\.dismiss) private var dismiss
    let alarmManager: AlarmManager
    
    @State private var name: String = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var selectedDays: Set<Weekday> = []
    @State private var selectedSound: String = "beep"
    @State private var useSmartWake: Bool = false
    
    // 引用声音管理器和智能唤醒管理器
    @ObservedObject private var soundManager = SoundManager.shared
    @ObservedObject private var smartWakeManager = SmartWakeManager.shared
    @ObservedObject private var watchConnectivity = WatchConnectivityManager.shared
    
    private let weekdayAbbreviations = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    
    var isTimeValid: Bool {
        startTime <= endTime
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Alarm Details")) {
                    TextField("Alarm Name (Optional)", text: $name)
                        .textContentType(.none)
                        .autocapitalization(.none)
                    
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    
                    if !isTimeValid {
                        Text("Start time must be earlier than or equal to end time")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section(header: Text("Sound")) {
                    Picker("Alarm Sound", selection: $selectedSound) {
                        ForEach(Array(soundManager.availableSounds.keys), id: \.self) { name in
                            Text(name).tag(soundManager.availableSounds[name]!)
                        }
                    }
                    .pickerStyle(DefaultPickerStyle())
                    .onChange(of: selectedSound) { _ in
                        // 当选择新声音时停止播放之前的声音
                        soundManager.stopSound()
                    }
                    
                    Button(action: {
                        // 切换播放/暂停
                        soundManager.togglePlayPause(selectedSound)
                    }) {
                        Label(
                            soundManager.isPreviewPlaying && soundManager.currentSoundName == selectedSound 
                                ? "Stop Preview" : "Preview Sound", 
                            systemImage: soundManager.isPreviewPlaying && soundManager.currentSoundName == selectedSound 
                                ? "stop.circle" : "play.circle"
                        )
                        .foregroundColor(soundManager.isPreviewPlaying && soundManager.currentSoundName == selectedSound 
                            ? .red : .blue)
                    }
                }
                
                Section(header: Text("Smart Wake")) {
                    Toggle("Enable Smart Wake", isOn: $useSmartWake)
                    
                    if useSmartWake {
                        // Add explanation text
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Smart Wake uses Apple Watch to monitor your sleep and wake you at the optimal moment within your set time range.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("If no optimal wake moment is found, you'll be awakened at the end time.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                        
                        if !watchConnectivity.isConnected {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                
                                Text("Apple Watch connection required for Smart Wake")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section(header: Text("Repeat")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Weekday.allCases, id: \.self) { weekday in
                                Button(action: {
                                    if selectedDays.contains(weekday) {
                                        selectedDays.remove(weekday)
                                    } else {
                                        selectedDays.insert(weekday)
                                    }
                                }) {
                                    Text(weekdayAbbreviations[weekday.rawValue - 1])
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle()
                                                .fill(selectedDays.contains(weekday) ? 
                                                    (weekday == .sunday || weekday == .saturday ? Color.red : Color.blue) : 
                                                    Color.clear)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(weekday == .sunday || weekday == .saturday ? Color.red : Color.blue, lineWidth: 1)
                                        )
                                        .foregroundColor(selectedDays.contains(weekday) ? .white : 
                                            (weekday == .sunday || weekday == .saturday ? Color.red : Color.blue))
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("New Alarm")
            .navigationBarItems(
                leading: Button("Cancel") {
                    // 停止任何正在播放的预览声音
                    soundManager.stopSound()
                    dismiss()
                },
                trailing: Button("Save") {
                    saveAlarm()
                }
                .disabled(!isTimeValid)
            )
            .onDisappear {
                // 确保在视图消失时停止任何声音播放
                soundManager.stopSound()
            }
        }
    }
    
    private func saveAlarm() {
        // 停止任何正在播放的预览声音
        soundManager.stopSound()
        
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var alarm = Alarm(
            name: name.isEmpty ? "Alarm" : name,
            startTime: startTime,
            endTime: endTime,
            repeatDays: selectedDays,
            soundName: selectedSound
        )
        
        // 自动激活闹钟并生成随机时间
        alarm.isActive = true
        alarm.generateRandomTime()
        
        // 添加闹钟
        alarmManager.addAlarm(alarm)
        
        // 如果启用了智能唤醒，同时设置智能唤醒
        if useSmartWake && watchConnectivity.isConnected {
            // Use the existing window between startTime and endTime
            // rather than a separate wakeTimeWindow setting
            
            // Calculate window duration in seconds
            let windowDuration = endTime.timeIntervalSince(startTime)
            
            // Update SmartWakeManager's wakeTimeWindow to match this alarm's window
            smartWakeManager.wakeTimeWindow = windowDuration
            
            // Enable smart wake and schedule using the end time (latest wake time)
            smartWakeManager.isSmartWakeEnabled = true
            smartWakeManager.scheduleSmartWake(at: alarm.endTime)
            
            // Store this alarm's ID as the one using Smart Wake
            UserDefaults.standard.set(alarm.id.uuidString, forKey: "smartWakeAlarmId")
            
            print("[AddAlarmView] Scheduled smart wake with window: \(Int(windowDuration/60)) minutes from \(startTime) to \(endTime)")
        }
        
        dismiss()
    }
} 