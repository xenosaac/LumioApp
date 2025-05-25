import SwiftUI
import Charts

struct SleepTrackerView: View {
    @ObservedObject var sleepManager = SleepManager.shared
    @State private var selectedDate = Date()
    @State private var currentWeek = Date()
    @State private var showingDreamTracker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(colors: [.appPurple, .appPurpleDark], startPoint: .topLeading, endPoint: .bottomTrailing)
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
                    .padding(.top, -4)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Weekly Calendar Header
                            weeklyCalendarView
                            
                            // Sleep Score Section
                            sleepScoreSection
                            
                            // Sleep Stages Visualization
                            sleepStagesSection
                            
                            // Dream Section
                            dreamSection
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
            .sheet(isPresented: $showingDreamTracker) {
                DreamTrackerView()
            }
        }
    }
    
    // MARK: - Weekly Calendar View
    
    private var weeklyCalendarView: some View {
        VStack(spacing: 12) {
            // Week navigation
            HStack {
                Button(action: { changeWeek(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(weekTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { changeWeek(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            // Days of week
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { date in
                    VStack(spacing: 8) {
                        Text(dayName(date))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Button(action: { selectedDate = date }) {
                            VStack(spacing: 4) {
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(isSelected(date) ? .white : .primary)
                                
                                // Sleep quality indicator dot
                                Circle()
                                    .fill(sleepQualityColor(for: date))
                                    .frame(width: 6, height: 6)
                            }
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(isSelected(date) ? Color.blue : Color.clear)
                            )
                            .overlay(
                                Circle()
                                    .stroke(isToday(date) ? Color.blue : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Sleep Score Section
    
    private var sleepScoreSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sleep Score")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(selectedDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 24) {
                // Sleep Score Ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(sleepScore) / 100)
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: sleepScore)
                    
                    VStack(spacing: 2) {
                        Text("\(sleepScore)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Score")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Sleep Times
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sleep Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(sleepTime)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wake Up Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(wakeUpTime)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(sleepDuration)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Sleep Stages Section
    
    private var sleepStagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Stages")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Sleep stages chart
            Chart {
                ForEach(sleepStagesData) { stage in
                    LineMark(
                        x: .value("Time", stage.time),
                        y: .value("Stage", stage.stageValue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }
                
                // Area fill
                ForEach(sleepStagesData) { stage in
                    AreaMark(
                        x: .value("Time", stage.time),
                        y: .value("Stage", stage.stageValue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.3),
                                Color.purple.opacity(0.2),
                                Color.green.opacity(0.2),
                                Color.orange.opacity(0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text(sleepStageLabel(for: intValue))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    AxisGridLine()
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let dateValue = value.as(Date.self) {
                            Text(dateValue, format: .dateTime.hour().minute())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Sleep stages legend
            HStack(spacing: 16) {
                sleepStageLegendItem("Awake", color: .red)
                sleepStageLegendItem("REM", color: .orange)
                sleepStageLegendItem("Light", color: .green)
                sleepStageLegendItem("Deep", color: .blue)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Dream Section
    
    private var dreamSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dream")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Add Dream") {
                    showingDreamTracker = true
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
            
            if hasDreamForSelectedDate {
                // Dream content
                VStack(alignment: .leading, spacing: 8) {
                    Text("The Flying Library")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("I was in a magical library where books could fly around...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Text("😊 Pleasant")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(6)
                        
                        Text("Flying")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
            } else {
                // No dream state
                VStack(spacing: 8) {
                    Image(systemName: "moon.stars")
                        .font(.title2)
                        .foregroundColor(.gray)
                    
                    Text("No dreams recorded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Tap 'Add Dream' to record your dreams")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Helper Views
    
    private func sleepStageLegendItem(_ title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Computed Properties
    
    private var weekDays: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: currentWeek)?.start ?? currentWeek
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }
    }
    
    private var weekTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentWeek)
    }
    
    private var sleepScore: Int {
        // Mock data - replace with actual sleep score calculation
        return 70
    }
    
    private var sleepTime: String {
        return "11:30 PM"
    }
    
    private var wakeUpTime: String {
        return "7:15 AM"
    }
    
    private var sleepDuration: String {
        return "7h 45m"
    }
    
    private var hasDreamForSelectedDate: Bool {
        // Mock data - replace with actual dream data check
        return Calendar.current.isDate(selectedDate, inSameDayAs: Date())
    }
    
    private var sleepStagesData: [SleepStageData] {
        // Mock data - replace with actual sleep stages data
        let calendar = Calendar.current
        let baseTime = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: selectedDate) ?? selectedDate
        
        var data: [SleepStageData] = []
        for i in 0..<480 { // 8 hours in minutes
            let time = calendar.date(byAdding: .minute, value: i, to: baseTime) ?? baseTime
            let stage = mockSleepStage(for: i)
            data.append(SleepStageData(time: time, stageValue: stage))
        }
        return data
    }
    
    // MARK: - Helper Methods
    
    private func changeWeek(_ direction: Int) {
        let calendar = Calendar.current
        if let newWeek = calendar.date(byAdding: .weekOfYear, value: direction, to: currentWeek) {
            currentWeek = newWeek
        }
    }
    
    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
    
    private func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }
    
    private func sleepQualityColor(for date: Date) -> Color {
        // Mock data - replace with actual sleep quality
        if Calendar.current.isDate(date, inSameDayAs: Date()) {
            return .green
        } else if Calendar.current.isDate(date, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            return .orange
        }
        return .gray.opacity(0.3)
    }
    
    private func sleepStageLabel(for value: Int) -> String {
        switch value {
        case 0: return "Awake"
        case 1: return "REM"
        case 2: return "Light"
        case 3: return "Deep"
        default: return ""
        }
    }
    
    private func mockSleepStage(for minute: Int) -> Int {
        // Create a realistic sleep pattern
        let hour = minute / 60
        let minuteInHour = minute % 60
        
        switch hour {
        case 0: // First hour - falling asleep
            return minuteInHour < 30 ? 0 : 2
        case 1...2: // Deep sleep
            return 3
        case 3: // Mix of deep and light
            return minuteInHour < 30 ? 3 : 2
        case 4: // REM cycle
            return 1
        case 5: // Light sleep
            return 2
        case 6: // Another REM cycle
            return minuteInHour < 45 ? 1 : 2
        case 7: // Light sleep before waking
            return minuteInHour < 30 ? 2 : 0
        default:
            return 0
        }
    }
}

// MARK: - Data Models

struct SleepStageData: Identifiable {
    let id = UUID()
    let time: Date
    let stageValue: Int
}

// MARK: - Preview

struct SleepTrackerView_Previews: PreviewProvider {
    static var previews: some View {
        SleepTrackerView()
    }
} 
 