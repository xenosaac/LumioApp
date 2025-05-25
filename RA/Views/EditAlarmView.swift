import SwiftUI

struct EditAlarmView: View {
    @Environment(\.dismiss) private var dismiss
    let alarm: Alarm
    let alarmManager: AlarmManager
    
    @State private var name: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var selectedDays: Set<Weekday>
    @State private var selectedSound: String
    @State private var useSmartWake: Bool
    
    // 引用声音管理器和智能唤醒管理器
    @ObservedObject private var soundManager = SoundManager.shared
    @ObservedObject private var smartWakeManager = SmartWakeManager.shared
    @ObservedObject private var watchConnectivity = WatchConnectivityManager.shared
    
    private let weekdayAbbreviations = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    
    var isTimeValid: Bool {
        startTime <= endTime
    }
    
    init(alarm: Alarm, alarmManager: AlarmManager) {
        self.alarm = alarm
        self.alarmManager = alarmManager
        _name = State(initialValue: alarm.name ?? "")
        _startTime = State(initialValue: alarm.startTime)
        _endTime = State(initialValue: alarm.endTime)
        _selectedDays = State(initialValue: alarm.repeatDays)
        _selectedSound = State(initialValue: alarm.soundName)
        
        // Check if this alarm is registered for smart wake
        let isSmartWakeEnabled = UserDefaults.standard.string(forKey: "smartWakeAlarmId") == alarm.id.uuidString
        _useSmartWake = State(initialValue: isSmartWakeEnabled)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(colors: [.appPurple, .appPurpleDark], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

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
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Alarm")
            .navigationBarItems(
                leading: Button(action: {
                    deleteAlarm()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
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
        
        var updatedAlarm = alarm
        updatedAlarm.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedAlarm.startTime = startTime
        updatedAlarm.endTime = endTime
        updatedAlarm.repeatDays = selectedDays
        updatedAlarm.soundName = selectedSound
        
        // 自动激活闹钟并生成新的随机时间
        updatedAlarm.isActive = true
        updatedAlarm.generateRandomTime()
        
        alarmManager.updateAlarm(updatedAlarm)
        
        // Handle Smart Wake updating
        if useSmartWake && watchConnectivity.isConnected {
            // Calculate window duration in seconds
            let windowDuration = endTime.timeIntervalSince(startTime)
            
            // Update SmartWakeManager's wakeTimeWindow to match this alarm's window
            smartWakeManager.wakeTimeWindow = windowDuration
            
            // Enable smart wake and schedule using the end time (latest wake time)
            smartWakeManager.isSmartWakeEnabled = true
            smartWakeManager.scheduleSmartWake(at: updatedAlarm.endTime)
            
            // Store this alarm's ID as the one using Smart Wake
            UserDefaults.standard.set(updatedAlarm.id.uuidString, forKey: "smartWakeAlarmId")
            
            print("[EditAlarmView] Updated smart wake with window: \(Int(windowDuration/60)) minutes from \(startTime) to \(endTime)")
        } else if UserDefaults.standard.string(forKey: "smartWakeAlarmId") == updatedAlarm.id.uuidString {
            // If this alarm was previously using Smart Wake but now it's disabled
            smartWakeManager.cancelSmartWake()
            UserDefaults.standard.removeObject(forKey: "smartWakeAlarmId")
            print("[EditAlarmView] Disabled smart wake for alarm ID: \(updatedAlarm.id.uuidString)")
        }
        
        dismiss()
    }
    
    private func deleteAlarm() {
        // Stop any playing preview sound
        soundManager.stopSound()
        
        // If this alarm was using Smart Wake, disable it
        if UserDefaults.standard.string(forKey: "smartWakeAlarmId") == alarm.id.uuidString {
            smartWakeManager.cancelSmartWake()
            UserDefaults.standard.removeObject(forKey: "smartWakeAlarmId")
            print("[EditAlarmView] Disabled smart wake for deleted alarm ID: \(alarm.id.uuidString)")
        }
        
        // Delete the alarm
        alarmManager.deleteAlarm(alarm)
        
        // Dismiss the view
        dismiss()
    }
} 