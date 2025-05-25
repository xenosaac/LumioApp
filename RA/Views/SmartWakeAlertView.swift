import SwiftUI

struct SmartWakeAlertView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var smartWakeManager = SmartWakeManager.shared
    @State private var fadeIn = false
    
    // 格式化唤醒时间
    private var timeString: String {
        guard let wakeEvent = smartWakeManager.lastWakeEvent else { return "" }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: wakeEvent.time)
    }
    
    // 计算早醒分钟数
    private var minutesEarlyString: String {
        guard let wakeEvent = smartWakeManager.lastWakeEvent, wakeEvent.isOptimalWake else {
            return "On Time"
        }
        
        return "\(Int(wakeEvent.minutesEarly)) minutes early"
    }
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.85).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // 顶部时间显示
                VStack(spacing: 15) {
                    Text(timeString)
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.white)
                    
                    Text("Smart Wake")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(minutesEarlyString)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
                .opacity(fadeIn ? 1 : 0)
                .scaleEffect(fadeIn ? 1 : 0.95)
                
                Spacer()
                
                // 睡眠数据
                if let wakeEvent = smartWakeManager.lastWakeEvent {
                    VStack(spacing: 25) {
                        // 心率
                        HStack(spacing: 15) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading) {
                                Text("Wake-up Heart Rate")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("\(Int(wakeEvent.heartRate)) BPM")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // 睡眠状态
                        HStack(spacing: 15) {
                            Image(systemName: "bed.double.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text("Sleep Stage at Wake-up")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text(wakeEvent.wakeState)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 25)
                    .padding(.horizontal, 30)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(15)
                    .padding(.horizontal, 30)
                    .opacity(fadeIn ? 1 : 0)
                    .offset(y: fadeIn ? 0 : 20)
                }
                
                Spacer()
                
                // 底部按钮
                VStack(spacing: 15) {
                    Button(action: {
                        // 关闭闹钟
                        smartWakeManager.userRespondedToWake()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Stop")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(height: 55)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(15)
                    }
                    
                    Button(action: {
                        // 稍后提醒（5分钟）
                        let newWakeTime = Date().addingTimeInterval(5 * 60)
                        smartWakeManager.userRespondedToWake()
                        smartWakeManager.scheduleSmartWake(at: newWakeTime)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Snooze 5 Minutes")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
                .opacity(fadeIn ? 1 : 0)
                .offset(y: fadeIn ? 0 : 30)
            }
            .padding(.top, 60)
        }
        .onAppear {
            // 启动声音
            SoundManager.shared.loopSound("wakeup_sound")
            
            // 启动振动
            startVibration()
            
            // 动画
            withAnimation(.easeInOut(duration: 1.2)) {
                fadeIn = true
            }
        }
        .onDisappear {
            // 停止音效
            SoundManager.shared.stopSound()
        }
    }
    
    // 播放振动
    private func startVibration() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // 重复振动
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            generator.notificationOccurred(.success)
        }
    }
}

struct SmartWakeAlertView_Previews: PreviewProvider {
    static var previews: some View {
        SmartWakeAlertView()
    }
} 