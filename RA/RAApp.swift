//
//  RAApp.swift
//  RA
//
//  Created by 卢驰 on 5/1/25.
//

import SwiftUI
import UserNotifications
import HealthKit
import WatchConnectivity

/// AppDelegate 注册 UNUserNotificationCenterDelegate，处理通知点击回调
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Register notification center delegate
        UNUserNotificationCenter.current().delegate = NotificationCenterDelegate.shared
        // Clear any pending triggered alarm
        NotificationManager.shared.triggeredAlarm = nil
        // Initialize sound manager
        _ = SoundManager.shared
        // Initialize sleep data manager
        _ = SleepManager.shared
        // Initialize watch connectivity manager
        _ = WatchConnectivityManager.shared
        
        // WORKAROUND: Add keys to Info.plist programmatically
        if let infoDictionary = Bundle.main.infoDictionary {
            var mutableDict = infoDictionary as! [String: Any]
            mutableDict["NSHealthShareUsageDescription"] = "This app requires access to your sleep data to analyze and display your sleep patterns."
            mutableDict["NSHealthUpdateUsageDescription"] = "This app does not write any health data."
            // Note: This is just for debugging, it won't actually modify the Info.plist
            print("WORKAROUND: Added HealthKit keys to info dictionary")
        }
        
        return true
    }
}

@main
struct RAApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var alarmManager = AlarmManager()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var sleepManager = SleepManager.shared
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    
    // Check if this is the user's first time opening the app
    @State private var isFirstLaunch = !UserDefaults.standard.bool(forKey: "HasLaunchedBefore")

    init() {
        notificationManager.alarmManager = alarmManager
        
        // Print the bundle URL for debugging
        if let bundleURL = Bundle.main.url(forResource: "Info", withExtension: "plist") {
            print("INFO: Found Info.plist at \(bundleURL.path)")
            
            if let infoDictionary = NSDictionary(contentsOf: bundleURL) {
                print("INFO: HealthKit usage description: \(infoDictionary["NSHealthShareUsageDescription"] ?? "MISSING")")
            } else {
                print("ERROR: Could not load Info.plist contents")
            }
        } else {
            print("ERROR: Could not locate Info.plist in the bundle")
        }
        
        // Request permissions for HealthKit on app launch
        if HKHealthStore.isHealthDataAvailable() {
            requestHealthKitPermissions()
        }
    }
    
    private func requestHealthKitPermissions() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            print("ERROR: Could not create sleepType")
            return
        }
        
        // WORKAROUND: Print healthKit requirements before requesting authorization
        print("INFO: About to request HealthKit authorization")
        print("INFO: Bundle ID = \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        sleepManager.healthStore.requestAuthorization(toShare: nil, read: [sleepType]) { success, error in
            if success {
                print("HealthKit authorization successful")
                DispatchQueue.main.async {
                    sleepManager.fetchSleepDataSync()
                }
            } else if let error = error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            // Always show welcome page
            WelcomeView()
                .environmentObject(alarmManager)
                .environmentObject(notificationManager)
                .environmentObject(sleepManager)
                .environmentObject(watchConnectivity)
                
            // Original first-launch logic (commented out):
            /*
            Group {
                if isFirstLaunch {
                    WelcomeView()
                        .environmentObject(alarmManager)
                        .environmentObject(notificationManager)
                        .environmentObject(sleepManager)
                        .environmentObject(watchConnectivity)
                        .onAppear {
                            // Mark that the app has been launched before
                            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
                        }
                } else {
                    ContentView()
                        .environmentObject(alarmManager)
                        .environmentObject(notificationManager)
                        .environmentObject(sleepManager)
                        .environmentObject(watchConnectivity)
                }
            }
            */
        }
    }
}
