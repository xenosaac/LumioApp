import SwiftUI

struct ContentView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var sleepManager: SleepManager
    @StateObject private var smartWakeManager = SmartWakeManager.shared
    
    @State private var showingSmartWakeAlert = false
    
    var body: some View {
        TabView {
            AlarmListView()
                .tabItem {
                    Label("Alarms", systemImage: "alarm")
                }
            
            StatsView()
                .tabItem {
                    Label("Sleep", systemImage: "bed.double")
                }
            
            DreamTrackerView()
                .tabItem {
                    Label("Dream Tracker", systemImage: "moon.stars")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .accentColor(.blue)
        .onAppear {
            // 设置TabBar的外观
            if #available(iOS 15.0, *) {
                let appearance = UITabBarAppearance()
                appearance.configureWithDefaultBackground()
                UITabBar.appearance().scrollEdgeAppearance = appearance
                UITabBar.appearance().standardAppearance = appearance
            }
            
            // 设置NavigationBar的外观
            if #available(iOS 15.0, *) {
                let navigationBarAppearance = UINavigationBarAppearance()
                navigationBarAppearance.configureWithDefaultBackground()
                UINavigationBar.appearance().standardAppearance = navigationBarAppearance
                UINavigationBar.appearance().compactAppearance = navigationBarAppearance
                UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
            }
            
            // 检查是否有激活的智能唤醒事件
            checkForActiveSmartWakeEvent()
        }
        // 显示标准闹钟触发视图
        .sheet(item: $notificationManager.triggeredAlarm) { alarm in
            AlarmTriggerView(alarm: alarm, alarmManager: alarmManager)
                .environmentObject(notificationManager)
        }
        // 显示智能唤醒提醒视图
        .fullScreenCover(isPresented: $showingSmartWakeAlert) {
            SmartWakeAlertView()
        }
        // 监听智能唤醒事件
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WakeTriggered"))) { _ in
            showingSmartWakeAlert = true
        }
    }
    
    // 检查是否有活跃的智能唤醒事件
    private func checkForActiveSmartWakeEvent() {
        if smartWakeManager.lastWakeEvent != nil && 
           smartWakeManager.isWakeActive && 
           !UserDefaults.standard.bool(forKey: "smartWakeResponded") {
            // 如果有未响应的智能唤醒事件，显示提醒界面
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingSmartWakeAlert = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AlarmManager())
        .environmentObject(NotificationManager.shared)
        .environmentObject(SleepManager.shared)
        .environmentObject(SmartWakeManager.shared)
} 

