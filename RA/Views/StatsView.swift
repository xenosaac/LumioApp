import SwiftUI
import HealthKit
import WatchConnectivity

struct StatsView: View {
    @ObservedObject var sleepManager = SleepManager.shared
    @ObservedObject var watchConnectivity = WatchConnectivityManager.shared
    @State private var isHealthKitAuthorized = false
    @State private var showingAuthorizationAlert = false
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                ZStack(alignment: .top) {
                    // 主要内容
                    VStack(alignment: .leading, spacing: 20) {
                        // Apple Watch connection status
                        watchConnectionStatusView
                        
                        // Sleep data chart
                        SleepChartView()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 2)
                            .padding(.horizontal)
                        
                        // Additional information
                        infoSection
                    }
                    .padding(.vertical)
                    
                    // 上拉刷新指示器（覆盖在内容顶部）
                    RefreshControl(isRefreshing: $isRefreshing, onRefresh: refreshData)
                        .frame(height: 0) // 不占用额外高度
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sleep Analysis")
            .onAppear {
                checkHealthKitAuthorization()
            }
            .alert(isPresented: $showingAuthorizationAlert) {
                Alert(
                    title: Text("HealthKit Access Required"),
                    message: Text("Please authorize access to your sleep data in the Health app to use this feature."),
                    primaryButton: .default(Text("Settings"), action: openHealthApp),
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private var watchConnectionStatusView: some View {
        HStack {
            Image(systemName: watchConnectivity.isConnected ? "applewatch.radiowaves.left.and.right" : "applewatch.slash")
                .font(.title2)
                .foregroundColor(watchConnectivity.isConnected ? .green : .red)
            
            VStack(alignment: .leading) {
                Text(watchConnectivity.isConnected ? "Apple Watch Connected" : "Apple Watch Not Connected")
                    .font(.headline)
                Text(watchConnectivity.isConnected ? "Sleep data syncs automatically" : "Please open the app on your Apple Watch")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if !watchConnectivity.isConnected {
                Button(action: {
                    // Try to refresh connection status
                    watchConnectivity.sendMessageToWatch(message: ["type": "ping"])
                }) {
                    Text("Retry")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About Sleep Analysis")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRowView(
                    icon: "moon.fill", 
                    color: .blue, 
                    title: "Sleep Stages", 
                    description: "Your sleep is tracked in different stages: light, deep, and REM. A healthy adult typically cycles through these stages multiple times each night."
                )
                
                InfoRowView(
                    icon: "bed.double.fill", 
                    color: .indigo, 
                    title: "Sleep Duration", 
                    description: "Most adults need 7-9 hours of sleep per night. Consistently getting enough sleep is important for physical and mental health."
                )
                
                InfoRowView(
                    icon: "chart.bar.fill", 
                    color: .purple, 
                    title: "Sleep Efficiency", 
                    description: "This measures the percentage of time in bed that you're actually asleep. Good sleep efficiency is typically above 85%."
                )
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 2)
            .padding(.horizontal)
        }
    }
    
    // Refresh data
    private func refreshData() {
        sleepManager.fetchSleepDataSync()
        
        // Simulate refresh delay and reset refreshing state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isRefreshing = false
        }
    }
    
    // Check HealthKit authorization status
    private func checkHealthKitAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            isHealthKitAuthorized = false
            return
        }
        
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            isHealthKitAuthorized = false
            return
        }
        
        let status = sleepManager.healthStore.authorizationStatus(for: sleepType)
        isHealthKitAuthorized = (status == .sharingAuthorized)
        
        if isHealthKitAuthorized {
            sleepManager.fetchSleepDataSync()
        } else {
            requestHealthKitAccess()
        }
    }
    
    // Request HealthKit access
    private func requestHealthKitAccess() {
        sleepManager.requestAuthorization { success, error in
            DispatchQueue.main.async {
                isHealthKitAuthorized = success
                if success {
                    sleepManager.fetchSleepDataSync()
                } else {
                    showingAuthorizationAlert = true
                }
            }
        }
    }
    
    // Open Health app for permissions
    private func openHealthApp() {
        if let url = URL(string: "x-apple-health://") {
            UIApplication.shared.open(url)
        }
    }
}

// 优化的RefreshControl，不占用垂直空间
struct RefreshControl: View {
    @Binding var isRefreshing: Bool
    let onRefresh: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            // 检测滚动位置以触发刷新
            if geometry.frame(in: .global).minY > 20 {
                Color.clear
                    .preference(key: RefreshableKeyTypes.PrefKey.self, value: RefreshableKeyTypes.PrefData(threshold: true))
                    .onAppear {
                        if !isRefreshing {
                            isRefreshing = true
                            onRefresh()
                        }
                    }
            } else {
                Color.clear
                    .preference(key: RefreshableKeyTypes.PrefKey.self, value: RefreshableKeyTypes.PrefData(threshold: false))
            }
            
            // 刷新指示器
            if isRefreshing {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Spacer()
                    }
                    Spacer()
                }
                .frame(height: 40)
                .offset(y: max(0, -geometry.frame(in: .global).origin.y - 10))
                .animation(.easeInOut, value: isRefreshing)
            }
        }
        .frame(height: 0) // 没有实际高度
    }
}

// 用于检测刷新状态的偏好键
enum RefreshableKeyTypes {
    struct PrefData: Equatable {
        let threshold: Bool
    }
    
    struct PrefKey: PreferenceKey {
        static var defaultValue: PrefData = PrefData(threshold: false)
        
        static func reduce(value: inout PrefData, nextValue: () -> PrefData) {
            value = nextValue()
        }
    }
}

// Information row component
struct InfoRowView: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView()
    }
} 
 