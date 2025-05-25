import SwiftUI

struct AlarmListView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var editingAlarm: Alarm?
    @State private var isAddingAlarm: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Faded purple gradient background
                LinearGradient(
                    colors: [
                        .appPurple, .appPurpleDark
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Centered Title
                    HStack {
                        Spacer()
                        Text("LUMIO")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(.appPurpleDark)
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    
                    if alarmManager.alarms.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "alarm")
                                .font(.system(size: 70, weight: .light))
                                .foregroundColor(.white)
                            
                            Text("No alarms yet")
                                .font(.title)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text("Tap + to add a new alarm")
                                .font(.body)
                                .fontWeight(.regular)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                    ForEach(alarmManager.alarms) { alarm in
                        AlarmRowView(alarm: alarm)
                            .contentShape(Rectangle())
                            .onLongPressGesture(minimumDuration: 0.5) {
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                editingAlarm = alarm
                            }
                    }
                                .onDelete(perform: deleteAlarms)
                            }
                            .padding()
                        }
                        }
                    }
                }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isAddingAlarm = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.appYellow)
                    }
                }
            }
            .sheet(item: $editingAlarm) { alarm in
                EditAlarmView(alarm: alarm, alarmManager: alarmManager)
            }
            .sheet(isPresented: $isAddingAlarm) {
                AddAlarmView(alarmManager: alarmManager)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Hide navigation bar title
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.titleTextAttributes = [
                .foregroundColor: UIColor.clear
            ]
            appearance.largeTitleTextAttributes = [
                .foregroundColor: UIColor.clear
            ]
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    // Function to handle deleting alarms
    private func deleteAlarms(at offsets: IndexSet) {
        for index in offsets {
            let alarm = alarmManager.alarms[index]
            alarmManager.deleteAlarm(alarm)
        }
    }
}

struct AlarmRowView: View {
    let alarm: Alarm
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var notificationManager: NotificationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    if !alarm.name.isEmpty {
                        Text(alarm.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    Text("Start: \(alarm.startTime.formatted(date: .omitted, time: .shortened))")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("End: \(alarm.endTime.formatted(date: .omitted, time: .shortened))")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { alarm.isActive },
                    set: { _ in alarmManager.toggleAlarm(alarm) }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .yellow))
                .scaleEffect(1.1)
            }
            
            if !alarm.repeatDays.isEmpty {
                Text("Repeat: \(alarm.repeatDays.map { $0.name }.joined(separator: ", "))")
                    .font(.subheadline)
                    .fontWeight(.regular)
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                )
        )
    }
} 
 
 