import Foundation
import HealthKit

// Sleep data point model
struct SleepDataPoint: Identifiable, Codable {
    var id = UUID()
    let startTime: Date
    let endTime: Date
    let sleepStage: SleepStage
    
    var durationInMinutes: Double {
        return endTime.timeIntervalSince(startTime) / 60.0
    }
    
    init(startTime: Date, endTime: Date, sleepStage: SleepStage) {
        self.startTime = startTime
        self.endTime = endTime
        self.sleepStage = sleepStage
    }
}

// Sleep stages enum
enum SleepStage: Int, Codable, CaseIterable {
    case inBed = 0
    case asleep = 1
    case awake = 2
    case deep = 3
    case rem = 4
    case core = 5
    
    var name: String {
        switch self {
        case .inBed: return "In Bed"
        case .asleep: return "Asleep"
        case .awake: return "Awake"
        case .deep: return "Deep Sleep"
        case .rem: return "REM Sleep"
        case .core: return "Core Sleep"
        }
    }
    
    var color: String {
        switch self {
        case .inBed: return "gray"
        case .asleep: return "blue"
        case .awake: return "red"
        case .deep: return "purple"
        case .rem: return "green"
        case .core: return "indigo"
        }
    }
    
    static func fromHKCategoryValue(_ value: Int) -> SleepStage {
        switch value {
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            return .inBed
        case HKCategoryValueSleepAnalysis.asleep.rawValue:
            return .asleep
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            return .awake
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            return .deep
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            return .rem
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
            return .core
        default:
            return .asleep
        }
    }
}

// Sleep data manager
class SleepManager: ObservableObject {
    static let shared = SleepManager()
    
    // Store sleep data points
    @Published var sleepData: [SleepDataPoint] = []
    
    // Time range selection
    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "1 Week"
        case month = "1 Month"
        
        var id: String { self.rawValue }
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            }
        }
    }
    
    // Currently selected time range
    @Published var selectedTimeRange: TimeRange = .week
    
    // Health store for HealthKit access
    let healthStore = HKHealthStore()
    
    // Observer query
    private var observerQuery: HKObserverQuery?
    
    private init() {
        // Load saved data initially
        loadData()
        
        // Generate mock data for development testing
        #if DEBUG
        if sleepData.isEmpty {
            generateMockData()
        }
        #endif
        
        // Setup automatic updates if HealthKit is available
        if HKHealthStore.isHealthDataAvailable() {
            setupObserverQuery()
        }
    }
    
    // Setup observer query to automatically update when new sleep data is available
    private func setupObserverQuery() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        // Create observer query
        observerQuery = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] (query, completionHandler, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error setting up observer query: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            // Fetch new data when changes are detected
            DispatchQueue.main.async {
                self.fetchSleepData()
                completionHandler()
            }
        }
        
        // Execute the query
        if let observerQuery = observerQuery {
            healthStore.execute(observerQuery)
            
            // Enable background delivery
            healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { (success, error) in
                if let error = error {
                    print("Failed to enable background delivery: \(error.localizedDescription)")
                }
                if success {
                    print("Background delivery enabled for sleep data")
                }
            }
        }
    }
    
    // Request authorization for sleep data
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }
        
        // Define the sleep analysis type
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(false, nil)
            return
        }
        
        // Request authorization
        healthStore.requestAuthorization(toShare: nil, read: [sleepType]) { success, error in
            completion(success, error)
        }
    }
    
    // Fetch sleep data from HealthKit
    func fetchSleepData() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        // Calculate the start date based on the selected time range
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate) ?? endDate
        
        // Create the predicate for the query
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        // Create the query
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
            guard let self = self, let samples = samples as? [HKCategorySample], error == nil else {
                print("Error fetching sleep data: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                var newSleepData: [SleepDataPoint] = []
                
                for sample in samples {
                    let sleepStage = SleepStage.fromHKCategoryValue(sample.value)
                    let sleepDataPoint = SleepDataPoint(
                        startTime: sample.startDate,
                        endTime: sample.endDate,
                        sleepStage: sleepStage
                    )
                    newSleepData.append(sleepDataPoint)
                }
                
                self.sleepData = newSleepData
                self.saveData()
            }
        }
        
        healthStore.execute(query)
    }
    
    // Filter data based on current time range
    func filteredData() -> [SleepDataPoint] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate) ?? endDate
        
        return sleepData.filter { $0.startTime > startDate }
                        .sorted { $0.startTime < $1.startTime }
    }
    
    // Calculate total sleep time in hours
    func totalSleepTime() -> Double {
        let sleepStages: [SleepStage] = [.asleep, .deep, .rem, .core]
        
        return filteredData()
            .filter { sleepStages.contains($0.sleepStage) }
            .reduce(0) { $0 + $1.durationInMinutes } / 60.0
    }
    
    // Calculate average sleep time per night
    func averageSleepTimePerNight() -> Double {
        let totalHours = totalSleepTime()
        
        // Group by day to count the number of nights
        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: filteredData()) { dataPoint in
            calendar.startOfDay(for: dataPoint.startTime)
        }
        
        let numberOfNights = groupedByDay.count
        
        return numberOfNights > 0 ? totalHours / Double(numberOfNights) : 0
    }
    
    // Calculate sleep efficiency (time asleep / time in bed)
    func sleepEfficiency() -> Double {
        let inBedTime = filteredData()
            .filter { $0.sleepStage == .inBed }
            .reduce(0) { $0 + $1.durationInMinutes }
        
        let sleepStages: [SleepStage] = [.asleep, .deep, .rem, .core]
        let asleepTime = filteredData()
            .filter { sleepStages.contains($0.sleepStage) }
            .reduce(0) { $0 + $1.durationInMinutes }
        
        return inBedTime > 0 ? (asleepTime / inBedTime) * 100.0 : 0
    }
    
    // Save data to local storage
    func saveData() {
        if let encoded = try? JSONEncoder().encode(sleepData) {
            UserDefaults.standard.set(encoded, forKey: "sleepData")
        }
    }
    
    // Load data from local storage
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "sleepData"),
           let decoded = try? JSONDecoder().decode([SleepDataPoint].self, from: data) {
            sleepData = decoded
        }
    }
    
    // Clear all data
    func clearAllData() {
        sleepData = []
        saveData()
    }
    
    // Generate mock data for development testing
    func generateMockData() {
        let calendar = Calendar.current
        let now = Date()
        var mockData: [SleepDataPoint] = []
        
        // Generate sleep data for the past 30 days
        for dayOffset in stride(from: -30, through: -1, by: 1) {
            // Create bedtime (around 11 PM)
            let bedtimeHour = Int.random(in: 22...23)
            let bedtimeMinute = Int.random(in: 0...59)
            let bedtimeDay = calendar.date(byAdding: .day, value: dayOffset, to: now)!
            let bedtime = calendar.date(
                bySettingHour: bedtimeHour,
                minute: bedtimeMinute,
                second: 0,
                of: bedtimeDay
            )!
            
            // Create wake time (around 7 AM the next day)
            let wakeTimeHour = Int.random(in: 6...8)
            let wakeTimeMinute = Int.random(in: 0...59)
            let wakeTimeDay = calendar.date(byAdding: .day, value: dayOffset + 1, to: now)!
            let wakeTime = calendar.date(
                bySettingHour: wakeTimeHour,
                minute: wakeTimeMinute,
                second: 0,
                of: wakeTimeDay
            )!
            
            // Add "in bed" segment
            mockData.append(SleepDataPoint(
                startTime: bedtime,
                endTime: wakeTime,
                sleepStage: .inBed
            ))
            
            // Populate sleep segments within that timeframe
            var currentTime = bedtime.addingTimeInterval(15 * 60) // 15 minutes to fall asleep
            
            while currentTime < wakeTime.addingTimeInterval(-20 * 60) { // Wake up 20 minutes before out of bed
                // Determine sleep stage
                let stageRandomizer = Int.random(in: 0...10)
                let stage: SleepStage
                
                if stageRandomizer < 2 {
                    stage = .awake // 20% chance of brief awakening
                } else if stageRandomizer < 5 {
                    stage = .rem // 30% chance of REM
                } else if stageRandomizer < 7 {
                    stage = .deep // 20% chance of deep
                } else {
                    stage = .core // 30% chance of core
                }
                
                // Determine segment duration
                let durationMinutes = Double.random(in: 20...90) // 20-90 minutes per sleep cycle
                let endTime = currentTime.addingTimeInterval(durationMinutes * 60)
                
                // Add sleep segment
                mockData.append(SleepDataPoint(
                    startTime: currentTime,
                    endTime: min(endTime, wakeTime.addingTimeInterval(-20 * 60)),
                    sleepStage: stage
                ))
                
                currentTime = endTime
            }
            
            // Add final awakening
            mockData.append(SleepDataPoint(
                startTime: currentTime,
                endTime: wakeTime,
                sleepStage: .awake
            ))
        }
        
        sleepData = mockData
        saveData()
    }
} 
