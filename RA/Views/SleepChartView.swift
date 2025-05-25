import SwiftUI
import Charts
import HealthKit

struct SleepChartView: View {
    @ObservedObject var sleepManager = SleepManager.shared
    @State private var selectedNight: Date = Calendar.current.startOfDay(for: Date())
    @State private var showingNightPicker = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 24) {
                // Header
                headerView
                    .padding(.top, 8)

                // Night selector
                nightSelectorView
                    .padding(.bottom, 4)

                // Sleep score ring + 解释
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                    VStack(spacing: 12) {
                        sleepScoreRingView
                        sleepScoreDescriptionView
                    }
                    .padding(.vertical, 16)
                }
                .padding(.horizontal)

                // Sleep cycle wave chart
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                    VStack(alignment: .leading, spacing: 8) {
                        sleepCycleWaveChart
                            .frame(height: 220)
                            .padding(.top, 8)
                        sleepStageLegend
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal)

                // Night summary
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                    nightMetricsView
                        .padding(.vertical, 16)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            if let mostRecentNight = getMostRecentNightWithData() {
                selectedNight = mostRecentNight
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Sleep Cycle Analysis")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Wave visualization of sleep depth over time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Generate Test Data") {
                sleepManager.generateMockData()
                if let mostRecentNight = getMostRecentNightWithData() {
                    selectedNight = mostRecentNight
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    private var nightSelectorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Night")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(getAvailableNights(), id: \.self) { night in
                        Button(action: {
                            selectedNight = night
                        }) {
                            VStack(spacing: 4) {
                                Text(night, format: .dateTime.month().day())
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Text(night, format: .dateTime.weekday(.abbreviated))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Calendar.current.isDate(night, inSameDayAs: selectedNight) ? 
                                          Color.blue : Color.gray.opacity(0.1))
                            )
                            .foregroundColor(Calendar.current.isDate(night, inSameDayAs: selectedNight) ? 
                                           .white : .primary)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var sleepCycleWaveChart: some View {
        let nightData = getSleepDataForNight(selectedNight)
        let waveData = generateWaveData(from: nightData)
        
        return VStack(alignment: .leading, spacing: 8) {
            Text("Sleep Depth Over Time")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if waveData.isEmpty {
                // No data state
                VStack(spacing: 12) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No sleep data for this night")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Generate test data or select a different night")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            } else {
                Chart {
                    // Horizontal zone lines for sleep stages
                    ForEach(SleepStage.allCases, id: \.self) { stage in
                        RuleMark(y: .value("Depth", stage.depthValue))
                            .foregroundStyle(Color.gray.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }
                    
                    // Sleep depth wave line
                    ForEach(waveData) { point in
                        LineMark(
                            x: .value("Time", point.timeFromBedtime),
                            y: .value("Depth", point.sleepDepth)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // Area fill under the wave
                    ForEach(waveData) { point in
                        AreaMark(
                            x: .value("Time", point.timeFromBedtime),
                            y: .value("Depth", point.sleepDepth)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.3),
                                    Color.purple.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // Stage transition points
                    ForEach(nightData) { dataPoint in
                        PointMark(
                            x: .value("Time", dataPoint.timeFromBedtime),
                            y: .value("Depth", dataPoint.sleepStage.depthValue)
                        )
                        .foregroundStyle(Color(dataPoint.sleepStage.color))
                        .symbol(Circle())
                        .symbolSize(30)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                                    .font(.caption)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        if let depth = value.as(Double.self) {
                            AxisValueLabel {
                                Text(getSleepStageLabel(for: depth))
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartYScale(domain: -1...4)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            }
        }
    }
    
    private var sleepStageLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep Stages")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(SleepStage.allCases, id: \.self) { stage in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(stage.color))
                            .frame(width: 8, height: 8)
                        
                        Text(stage.name)
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(6)
                }
            }
        }
    }
    
    private var sleepScoreRingView: some View {
        let nightData = getSleepDataForNight(selectedNight)
        let score = SleepManager.calculateSleepScore(for: nightData.compactMap { $0.originalDataPoint })
        let sleepPoints = nightData.compactMap { $0.originalDataPoint }
        let totalSleep = sleepPoints.filter { [.asleep, .deep, .rem, .core].contains($0.sleepStage) }
            .reduce(0.0) { $0 + $1.durationInMinutes }
        let showScore = totalSleep > 0 ? score : 0.0
        return VStack(spacing: 8) {
            Text("Sleep Score")
                .font(.headline)
            SleepScoreRing(score: showScore)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var sleepScoreDescriptionView: some View {
        let nightData = getSleepDataForNight(selectedNight)
        let score = SleepManager.calculateSleepScore(for: nightData.compactMap { $0.originalDataPoint })
        let (desc, color) = score >= 85 ? ("Excellent!", Color.green) : score >= 70 ? ("Good", Color.blue) : score >= 50 ? ("Needs Improvement", Color.orange) : ("Poor", Color.red)
        let suggestion = score >= 85 ? "Keep up your great sleep habits!" : score >= 70 ? "Try to get a bit more deep sleep." : score >= 50 ? "Aim for longer and deeper sleep." : "Consider improving your sleep schedule."
        return VStack(spacing: 4) {
            Text(desc)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(suggestion)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var nightMetricsView: some View {
        let nightData = getSleepDataForNight(selectedNight)
        let sleepPoints = nightData.compactMap { $0.originalDataPoint }
        
        // 如果没有数据，直接显示全0
        if nightData.isEmpty || sleepPoints.isEmpty {
            return VStack(alignment: .leading, spacing: 16) {
                Text("Night Summary")
                    .font(.headline)
                    .padding(.horizontal)
                HStack(spacing: 16) {
                    MetricCard(title: "Total Sleep", value: "0.0h", color: .blue)
                    MetricCard(title: "Deep Sleep", value: "0.0h", color: .purple)
                    MetricCard(title: "REM Sleep", value: "0.0h", color: .green)
                    MetricCard(title: "Awakenings", value: "0", color: .red)
                }
                .padding(.horizontal)
            }
        }
        
        let totalSleep = sleepPoints.filter { [.asleep, .deep, .rem, .core].contains($0.sleepStage) }
            .reduce(0.0) { $0 + $1.durationInMinutes }
        let deepSleep = sleepPoints.filter { $0.sleepStage == .deep }
            .reduce(0.0) { $0 + $1.durationInMinutes }
        let remSleep = sleepPoints.filter { $0.sleepStage == .rem }
            .reduce(0.0) { $0 + $1.durationInMinutes }
        let awakenings = sleepPoints.filter { $0.sleepStage == .awake }.count
        
        // 防御：如果没有有效睡眠数据，全部显示为0
        let showTotalSleep = totalSleep > 0 ? totalSleep : 0
        let showDeepSleep = totalSleep > 0 ? deepSleep : 0
        let showRemSleep = totalSleep > 0 ? remSleep : 0
        let showAwakenings = totalSleep > 0 ? awakenings : 0
        
        return VStack(alignment: .leading, spacing: 16) {
            Text("Night Summary")
                .font(.headline)
                .padding(.horizontal)
            HStack(spacing: 16) {
                MetricCard(
                    title: "Total Sleep",
                    value: String(format: "%.1fh", showTotalSleep / 60),
                    color: .blue
                )
                MetricCard(
                    title: "Deep Sleep",
                    value: String(format: "%.1fh", showDeepSleep / 60),
                    color: .purple
                )
                MetricCard(
                    title: "REM Sleep",
                    value: String(format: "%.1fh", showRemSleep / 60),
                    color: .green
                )
                MetricCard(
                    title: "Awakenings",
                    value: "\(showAwakenings)",
                    color: .red
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Functions
    
    private func getAvailableNights() -> [Date] {
        let calendar = Calendar.current
        let groupedData = Dictionary(grouping: sleepManager.sleepData) { dataPoint in
            calendar.startOfDay(for: dataPoint.startTime)
        }
        
        return groupedData.keys.sorted(by: >).prefix(14).map { $0 }
    }
    
    private func getMostRecentNightWithData() -> Date? {
        return getAvailableNights().first
    }
    
    private func getSleepDataForNight(_ night: Date) -> [SleepWavePoint] {
        let calendar = Calendar.current
        let nextDay = calendar.date(byAdding: .day, value: 1, to: night)!
        
        let nightData = sleepManager.sleepData.filter { dataPoint in
            dataPoint.startTime >= night && dataPoint.startTime < nextDay
        }.sorted { $0.startTime < $1.startTime }
        
        // 如果没有数据，直接返回空数组
        guard !nightData.isEmpty, let bedtime = nightData.first?.startTime else { return [] }
        
        return nightData.map { dataPoint in
            SleepWavePoint(
                id: dataPoint.id,
                timeFromBedtime: dataPoint.startTime.timeIntervalSince(bedtime) / 3600, // Hours from bedtime
                sleepStage: dataPoint.sleepStage,
                sleepDepth: dataPoint.sleepStage.depthValue,
                originalDataPoint: dataPoint
            )
        }
    }
    
    private func generateWaveData(from nightData: [SleepWavePoint]) -> [SleepWavePoint] {
        guard !nightData.isEmpty else { return [] }
        
        var waveData: [SleepWavePoint] = []
        let timeStep: Double = 0.1 // 6-minute intervals for smooth wave
        
        guard let startTime = nightData.first?.timeFromBedtime,
              let endTime = nightData.last?.timeFromBedtime else { return [] }
        
        var currentTime = startTime
        while currentTime <= endTime {
            // Find the current sleep stage at this time
            let currentStage = findSleepStageAt(time: currentTime, in: nightData)
            let depth = currentStage.depthValue
            
            // Add some natural variation to make it look more wave-like
            let variation = sin(currentTime * 2) * 0.1 + cos(currentTime * 3) * 0.05
            let adjustedDepth = depth + variation
            
            waveData.append(SleepWavePoint(
                timeFromBedtime: currentTime,
                sleepStage: currentStage,
                sleepDepth: adjustedDepth
            ))
            
            currentTime += timeStep
        }
        
        return waveData
    }
    
    private func findSleepStageAt(time: Double, in nightData: [SleepWavePoint]) -> SleepStage {
        // Find the sleep stage that was active at the given time
        for i in 0..<nightData.count {
            let currentPoint = nightData[i]
            let nextPoint = i < nightData.count - 1 ? nightData[i + 1] : nil
            
            if let nextPoint = nextPoint {
                if time >= currentPoint.timeFromBedtime && time < nextPoint.timeFromBedtime {
                    return currentPoint.sleepStage
                }
            } else {
                // Last point
                if time >= currentPoint.timeFromBedtime {
                    return currentPoint.sleepStage
                }
            }
        }
        
        return nightData.first?.sleepStage ?? .asleep
    }
    
    private func getSleepStageLabel(for depth: Double) -> String {
        switch depth {
        case -1.0...(-0.25): return "In Bed"
        case -0.25...0.5: return "Awake"
        case 0.5...1.25: return "REM"
        case 1.25...1.75: return "Light"
        case 1.75...2.5: return "Core"
        case 2.5...4.0: return "Deep"
        default: return ""
        }
    }
}

// MARK: - Supporting Data Structures

struct SleepWavePoint: Identifiable {
    let id = UUID()
    let timeFromBedtime: Double // Hours from bedtime
    let sleepStage: SleepStage
    let sleepDepth: Double
    var originalDataPoint: SleepDataPoint?
    
    init(timeFromBedtime: Double, sleepStage: SleepStage, sleepDepth: Double) {
        self.timeFromBedtime = timeFromBedtime
        self.sleepStage = sleepStage
        self.sleepDepth = sleepDepth
        self.originalDataPoint = nil
    }
    
    init(id: UUID = UUID(), timeFromBedtime: Double, sleepStage: SleepStage, sleepDepth: Double, originalDataPoint: SleepDataPoint) {
        self.timeFromBedtime = timeFromBedtime
        self.sleepStage = sleepStage
        self.sleepDepth = sleepDepth
        self.originalDataPoint = originalDataPoint
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct SleepScoreRing: View {
    var score: Double // 0~100
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 16)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple, Color.blue]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text(String(format: "%.1f", score))
                .font(.largeTitle)
                .bold()
        }
        .frame(width: 120, height: 120)
    }
}

struct SleepChartView_Previews: PreviewProvider {
    static var previews: some View {
        SleepChartView()
    }
} 