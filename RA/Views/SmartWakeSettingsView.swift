import SwiftUI

struct SmartWakeSettingsView: View {
    @ObservedObject var smartWakeManager = SmartWakeManager.shared
    @ObservedObject var watchConnectivity = WatchConnectivityManager.shared
    
    @State private var isSmartWakeEnabled = false
    @State private var wakeWindowMinutes: Double = 30
    @State private var selectedWakeTime = Date()
    @State private var showingTimePicker = false
    @State private var saveToHealthKit = false
    
    // 唤醒时间格式化器
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
    
    var body: some View {
        List {
            // 智能唤醒开关
            Section(header: Text("智能唤醒")) {
                Toggle("开启智能唤醒", isOn: $isSmartWakeEnabled)
                    .onChange(of: isSmartWakeEnabled) { newValue in
                        if newValue {
                            scheduleWake()
                        } else {
                            smartWakeManager.cancelSmartWake()
                        }
                    }
                
                if let targetTime = smartWakeManager.targetWakeTime {
                    HStack {
                        Text("目标唤醒时间")
                        Spacer()
                        Text(timeFormatter.string(from: targetTime))
                            .foregroundColor(.blue)
                    }
                }
            }
            .onAppear {
                // 加载当前设置
                isSmartWakeEnabled = smartWakeManager.isSmartWakeEnabled
                wakeWindowMinutes = smartWakeManager.wakeTimeWindow / 60
                saveToHealthKit = UserDefaults.standard.bool(forKey: "saveWakeDataToHealth")
                
                // 如果有目标时间，使用它；否则默认为明天早上7点
                if let targetTime = smartWakeManager.targetWakeTime {
                    selectedWakeTime = targetTime
                } else {
                    // 设置默认唤醒时间为明天早上7点
                    let calendar = Calendar.current
                    let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                    selectedWakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow) ?? tomorrow
                }
            }
            
            // 唤醒设置
            if isSmartWakeEnabled {
                Section(header: Text("唤醒设置")) {
                    // 唤醒窗口设置
                    VStack(alignment: .leading) {
                        HStack {
                            Text("唤醒窗口")
                            Spacer()
                            Text("\(Int(wakeWindowMinutes)) 分钟")
                                .foregroundColor(.blue)
                        }
                        
                        Slider(value: $wakeWindowMinutes, in: 5...60, step: 5)
                            .onChange(of: wakeWindowMinutes) { newValue in
                                smartWakeManager.wakeTimeWindow = newValue * 60
                                if isSmartWakeEnabled {
                                    scheduleWake()
                                }
                            }
                    }
                    
                    // 唤醒时间设置
                    Button(action: {
                        showingTimePicker = true
                    }) {
                        HStack {
                            Text("设置唤醒时间")
                            Spacer()
                            Text(timeFormatter.string(from: selectedWakeTime))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // 数据设置
                Section(header: Text("数据设置")) {
                    Toggle("保存唤醒数据到健康", isOn: $saveToHealthKit)
                        .onChange(of: saveToHealthKit) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "saveWakeDataToHealth")
                        }
                }
                
                // 上次唤醒数据
                if let lastEvent = smartWakeManager.lastWakeEvent {
                    Section(header: Text("上次唤醒数据")) {
                        HStack {
                            Text("唤醒时间")
                            Spacer()
                            Text(timeFormatter.string(from: lastEvent.time))
                        }
                        
                        HStack {
                            Text("目标时间")
                            Spacer()
                            Text(timeFormatter.string(from: lastEvent.targetTime))
                        }
                        
                        if lastEvent.isOptimalWake {
                            HStack {
                                Text("提前唤醒")
                                Spacer()
                                Text("\(Int(lastEvent.minutesEarly)) 分钟")
                                    .foregroundColor(.green)
                            }
                        }
                        
                        HStack {
                            Text("唤醒心率")
                            Spacer()
                            Text("\(Int(lastEvent.heartRate)) BPM")
                        }
                        
                        if let responseTime = lastEvent.responseTime {
                            HStack {
                                Text("响应时间")
                                Spacer()
                                Text("\(Int(responseTime)) 秒")
                            }
                        }
                    }
                }
            }
            
            // Watch连接状态
            Section(header: Text("Apple Watch 连接状态")) {
                HStack {
                    Image(systemName: watchConnectivity.isConnected ? "applewatch.radiowaves.left.and.right" : "applewatch.slash")
                        .foregroundColor(watchConnectivity.isConnected ? .green : .red)
                    
                    Text(watchConnectivity.isConnected ? "已连接" : "未连接")
                    
                    Spacer()
                    
                    if !watchConnectivity.isConnected {
                        Text("需要Apple Watch连接")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // 使用说明
            Section(header: Text("智能唤醒说明")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("智能唤醒如何工作")
                        .font(.headline)
                    
                    Text("• 应用会监测您在唤醒窗口期内的睡眠状态")
                        .font(.caption)
                    
                    Text("• 当检测到浅睡眠状态时，会选择在目标时间之前唤醒您")
                        .font(.caption)
                    
                    Text("• 如果未检测到浅睡眠，将在目标时间唤醒")
                        .font(.caption)
                    
                    Text("• 需要佩戴Apple Watch监测心率和运动")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("• 唤醒后，只能通过手机停止闹钟")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("智能唤醒")
        .sheet(isPresented: $showingTimePicker) {
            // 时间选择器
            VStack {
                DatePicker("选择唤醒时间", selection: $selectedWakeTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                
                HStack {
                    Button("取消") {
                        showingTimePicker = false
                    }
                    
                    Spacer()
                    
                    Button("确定") {
                        scheduleWake()
                        showingTimePicker = false
                    }
                    .bold()
                }
                .padding()
            }
            .padding()
        }
        .alert(isPresented: .constant(!watchConnectivity.isConnected && isSmartWakeEnabled)) {
            Alert(
                title: Text("需要Apple Watch"),
                message: Text("智能唤醒功能需要与Apple Watch配对使用。请确保您的Apple Watch已连接。"),
                dismissButton: .default(Text("了解"))
            )
        }
    }
    
    // 安排唤醒
    private func scheduleWake() {
        // 确保选择了将来的时间
        let calendar = Calendar.current
        let now = Date()
        
        var wakeTime = selectedWakeTime
        
        // 如果选择的时间已经过去，设置为明天的相同时间
        if wakeTime < now {
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
                let hour = calendar.component(.hour, from: selectedWakeTime)
                let minute = calendar.component(.minute, from: selectedWakeTime)
                
                wakeTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow) ?? tomorrow
            }
        }
        
        // 设置智能唤醒
        smartWakeManager.wakeTimeWindow = wakeWindowMinutes * 60
        smartWakeManager.isSmartWakeEnabled = true
        smartWakeManager.scheduleSmartWake(at: wakeTime)
    }
}

struct SmartWakeSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SmartWakeSettingsView()
        }
    }
} 