import SwiftUI

struct AlarmListView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var editingAlarm: Alarm?
    @State private var isAddingAlarm: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(alarmManager.alarms) { alarm in
                        AlarmRowView(alarm: alarm)
                            .contentShape(Rectangle())
                            .onLongPressGesture(minimumDuration: 0.5) {
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                editingAlarm = alarm
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            alarmManager.deleteAlarm(alarmManager.alarms[index])
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                
                if alarmManager.alarms.isEmpty {
                    VStack {
                        Spacer()
                        Text("No alarms yet")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("Tap + to add a new alarm")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isAddingAlarm = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20))
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
    }
}

struct AlarmRowView: View {
    let alarm: Alarm
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var notificationManager: NotificationManager
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if !alarm.name.isEmpty {
                        Text(alarm.name)
                            .font(.headline)
                    }
                    
                    Text("Start Time: \(alarm.startTime.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                    
                    Text("End Time: \(alarm.endTime.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { alarm.isActive },
                    set: { _ in alarmManager.toggleAlarm(alarm) }
                ))
                .labelsHidden()
            }
            
            if !alarm.repeatDays.isEmpty {
                Text("Repeat: \(alarm.repeatDays.map { $0.name }.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
} 
 