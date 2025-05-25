import SwiftUI

struct ContentView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var sleepManager: SleepManager
    @StateObject private var smartWakeManager = SmartWakeManager.shared
    
    @State private var showingSmartWakeAlert = false
    @State private var selectedTab = 1
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SleepTrackerView()
                .tabItem {
                    Label("Sleep", systemImage: "bed.double")
                }
                .tag(0)
            
            AlarmListView()
                .tabItem {
                    Label("Alarms", systemImage: "alarm")
                }
                .tag(1)
            
            // Dream Tracker as regular tab (no longer full screen)
            DreamTrackerView()
                .tabItem {
                    Label("Dream Tracker", systemImage: "moon.stars")
                }
                .tag(2)
        }
        .accentColor(.appYellowDark)
        .onAppear {
            // 设置TabBar的外观
            if #available(iOS 15.0, *) {
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(Color.appPurpleGradient)
                
                // Set unselected item color to white
                appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white
                appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
                
                // Set selected item color to yellow (handled by accentColor)
                appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.appYellowDark)
                appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.appYellowDark)]
                
                UITabBar.appearance().scrollEdgeAppearance = appearance
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().unselectedItemTintColor = UIColor.white
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


