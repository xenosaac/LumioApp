import Foundation
import HealthKit
import CoreMotion

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
    
    // Depth value for chart visualization
    var depthValue: Double {
        switch self {
        case .inBed: return -0.5
        case .awake: return 0.0
        case .rem: return 1.0
        case .asleep: return 1.5
        case .core: return 2.0
        case .deep: return 3.0
        }
    }
    
    static func fromHKCategoryValue(_ value: Int) -> SleepStage {
        switch value {
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            return .inBed
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
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

// Motion data record for sleep analysis
struct MotionRecord {
    let timestamp: Date
    let motionLevel: Int // 0 = still, 1 = light movement, 2 = significant movement
    let accelerationVariance: Double
}

// Heart rate data record
struct HeartRateRecord {
    let timestamp: Date
    let heartRate: Double
}

// HRV data record
struct HRVRecord {
    let timestamp: Date
    let hrv: Double
}

// 30-second epoch data for sleep stage inference
struct SleepEpoch {
    let startTime: Date
    let endTime: Date
    let averageHeartRate: Double?
    let averageHRV: Double?
    let motionLevel: Int
    let officialStage: SleepStage?
    let inferredStage: SleepStage?
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
    
    // CoreMotion manager for motion data
    private let motionManager = CMMotionManager()
    private let activityManager = CMMotionActivityManager()
    
    // Observer query
    private var observerQuery: HKObserverQuery?
    
    // Last fetch timestamp for incremental updates
    @Published var lastFetchTime: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    
    // Raw sensor data storage
    private var heartRateData: [HeartRateRecord] = []
    private var hrvData: [HRVRecord] = []
    private var motionData: [MotionRecord] = []
    
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
                self.fetchSleepDataSync()
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
    
    // Request authorization for all required health data
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }
        
        // Define all required health types
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion(false, nil)
            return
        }
        
        let typesToRead: Set<HKObjectType> = [sleepType, heartRateType, hrvType]
        
        // Request authorization
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            completion(success, error)
        }
    }
    
    // Comprehensive sleep data fetching with sensor fusion
    func fetchSleepData() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate) ?? endDate
        
        // Fetch all data types concurrently
        async let officialSleep = fetchOfficialSleepData(from: lastFetchTime, to: endDate)
        async let heartRate = fetchHeartRateData(from: startDate, to: endDate)
        async let hrv = fetchHRVData(from: startDate, to: endDate)
        
        // Start motion monitoring if available
        await startMotionMonitoring()
        
        do {
            let (sleepSamples, hrSamples, hrvSamples) = await (officialSleep, heartRate, hrv)
            
            // Store raw data
            self.heartRateData = hrSamples
            self.hrvData = hrvSamples
            
            // Process and merge data
            let processedSleepData = await processSleepData(
                officialSleep: sleepSamples,
                heartRate: hrSamples,
                hrv: hrvSamples,
                motion: motionData,
                from: startDate,
                to: endDate
            )
            
            DispatchQueue.main.async {
                self.sleepData = processedSleepData
                self.lastFetchTime = endDate
                self.saveData()
            }
            
        } catch {
            print("Error fetching comprehensive sleep data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Individual Data Fetching Methods
    
    // Fetch official sleep analysis data from HealthKit
    private func fetchOfficialSleepData(from startDate: Date, to endDate: Date) async -> [HKCategorySample] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("Error fetching official sleep data: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                } else {
                    continuation.resume(returning: samples as? [HKCategorySample] ?? [])
                }
            }
            healthStore.execute(query)
        }
    }
    
    // Fetch heart rate data from HealthKit
    private func fetchHeartRateData(from startDate: Date, to endDate: Date) async -> [HeartRateRecord] {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("Error fetching heart rate data: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                } else {
                    let heartRateRecords = (samples as? [HKQuantitySample])?.compactMap { sample in
                        HeartRateRecord(
                            timestamp: sample.startDate,
                            heartRate: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        )
                    } ?? []
                    continuation.resume(returning: heartRateRecords)
                }
            }
            healthStore.execute(query)
        }
    }
    
    // Fetch HRV data from HealthKit
    private func fetchHRVData(from startDate: Date, to endDate: Date) async -> [HRVRecord] {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("Error fetching HRV data: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                } else {
                    let hrvRecords = (samples as? [HKQuantitySample])?.compactMap { sample in
                        HRVRecord(
                            timestamp: sample.startDate,
                            hrv: sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                        )
                    } ?? []
                    continuation.resume(returning: hrvRecords)
                }
            }
            healthStore.execute(query)
        }
    }
    
    // Start motion monitoring using CoreMotion
    private func startMotionMonitoring() async {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available")
            return
        }
        
        // Clear existing motion data
        motionData.removeAll()
        
        // Start device motion updates for sleep period detection
        if !motionManager.isDeviceMotionActive {
            motionManager.deviceMotionUpdateInterval = 0.1 // 10 Hz
            motionManager.startDeviceMotionUpdates()
        }
        
        // Also try to get historical motion activity if available
        await fetchHistoricalMotionActivity()
    }
    
    // Fetch historical motion activity
    private func fetchHistoricalMotionActivity() async {
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("Motion activity not available")
            return
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -1, to: endDate) ?? endDate
        
        return await withCheckedContinuation { continuation in
            activityManager.queryActivityStarting(from: startDate, to: endDate, to: OperationQueue.main) { activities, error in
                if let error = error {
                    print("Error fetching motion activity: \(error.localizedDescription)")
                } else if let activities = activities {
                    // Convert motion activities to motion records
                    let motionRecords = activities.compactMap { activity -> MotionRecord? in
                        let motionLevel: Int
                        if activity.running || activity.walking {
                            motionLevel = 2 // Significant movement
                        } else if activity.automotive {
                            motionLevel = 1 // Light movement
                        } else {
                            motionLevel = 0 // Still
                        }
                        
                        return MotionRecord(
                            timestamp: activity.startDate,
                            motionLevel: motionLevel,
                            accelerationVariance: 0.0 // Not available from CMMotionActivity
                        )
                    }
                    
                    self.motionData.append(contentsOf: motionRecords)
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - Data Processing Methods
    
    // Process and merge all sleep data using sensor fusion
    private func processSleepData(
        officialSleep: [HKCategorySample],
        heartRate: [HeartRateRecord],
        hrv: [HRVRecord],
        motion: [MotionRecord],
        from startDate: Date,
        to endDate: Date
    ) async -> [SleepDataPoint] {
        
        // Convert to epochs (30-second intervals)
        let epochs = await epochize(
            officialSleep: officialSleep,
            heartRate: heartRate,
            hrv: hrv,
            motion: motion,
            from: startDate,
            to: endDate
        )
        
        // Process epochs into sleep data points
        var sleepDataPoints: [SleepDataPoint] = []
        var currentStage: SleepStage?
        var currentStartTime: Date?
        
        for epoch in epochs {
            let finalStage = epoch.officialStage ?? epoch.inferredStage ?? .asleep
            
            if finalStage != currentStage {
                // Stage change detected
                if let startTime = currentStartTime, let stage = currentStage {
                    sleepDataPoints.append(SleepDataPoint(
                        startTime: startTime,
                        endTime: epoch.startTime,
                        sleepStage: stage
                    ))
                }
                currentStage = finalStage
                currentStartTime = epoch.startTime
            }
        }
        
        // Add final segment
        if let startTime = currentStartTime, let stage = currentStage {
            sleepDataPoints.append(SleepDataPoint(
                startTime: startTime,
                endTime: endDate,
                sleepStage: stage
            ))
        }
        
        return sleepDataPoints.sorted { $0.startTime < $1.startTime }
    }
    
    // Convert raw data into 30-second epochs
    private func epochize(
        officialSleep: [HKCategorySample],
        heartRate: [HeartRateRecord],
        hrv: [HRVRecord],
        motion: [MotionRecord],
        from startDate: Date,
        to endDate: Date
    ) async -> [SleepEpoch] {
        
        var epochs: [SleepEpoch] = []
        let epochDuration: TimeInterval = 30 // 30 seconds
        
        var currentTime = startDate
        while currentTime < endDate {
            let epochEnd = min(currentTime.addingTimeInterval(epochDuration), endDate)
            
            // Find official sleep stage for this epoch
            let officialStage = officialSleep.first { sample in
                sample.startDate <= currentTime && sample.endDate > currentTime
            }.map { SleepStage.fromHKCategoryValue($0.value) }
            
            // Calculate average heart rate for this epoch
            let epochHeartRates = heartRate.filter { record in
                record.timestamp >= currentTime && record.timestamp < epochEnd
            }
            let avgHeartRate = epochHeartRates.isEmpty ? nil : epochHeartRates.map(\ .heartRate).average()
            
            // Calculate average HRV for this epoch
            let epochHRV = hrv.filter { record in
                record.timestamp >= currentTime && record.timestamp < epochEnd
            }
            let avgHRV = epochHRV.isEmpty ? nil : epochHRV.map(\ .hrv).average()
            
            // Determine motion level for this epoch
            let epochMotion = motion.filter { record in
                record.timestamp >= currentTime && record.timestamp < epochEnd
            }
            let motionLevel = epochMotion.isEmpty ? 0 : (epochMotion.map(\ .motionLevel).max() ?? 0)
            
            // Infer sleep stage if no official stage available
            let inferredStage = (officialStage == nil && avgHeartRate != nil) ? 
                inferSleepStage(heartRate: avgHeartRate!, hrv: avgHRV ?? 0, motionLevel: motionLevel) : nil
            
            let epoch = SleepEpoch(
                startTime: currentTime,
                endTime: epochEnd,
                averageHeartRate: avgHeartRate,
                averageHRV: avgHRV,
                motionLevel: motionLevel,
                officialStage: officialStage,
                inferredStage: inferredStage
            )
            
            epochs.append(epoch)
            currentTime = epochEnd
        }
        
        return epochs
    }
    
    // Backup rule algorithm for sleep stage inference
    private func inferSleepStage(heartRate: Double, hrv: Double, motionLevel: Int) -> SleepStage {
        // Large movement indicates awakening
        if motionLevel == 2 {
            return .awake
        }
        
        // Deep sleep: low HR, low HRV, no movement
        if heartRate < 55 && hrv < 30 && motionLevel == 0 {
            return .deep
        }
        
        // REM sleep: higher HR, higher HRV, no movement
        if heartRate > 65 && hrv > 50 && motionLevel == 0 {
            return .rem
        }
        
        // Default to core sleep for other combinations
        return .core
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
    
    // MARK: - Utility Methods
    
    // Get heart rate data for external access (e.g., SmartWakeManager)
    func getHeartRateData() -> [HeartRateRecord] {
        return heartRateData
    }
    
    // Get motion data for external access
    func getMotionData() -> [MotionRecord] {
        return motionData
    }
    
    // Update the wrapper for async fetchSleepData to maintain compatibility
    func fetchSleepDataSync() {
        Task {
            await fetchSleepData()
        }
    }
}

// MARK: - Extensions

extension Optional {
    func `let`<U>(_ transform: (Wrapped) -> U) -> U? {
        return self.map(transform)
    }
}

extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0.0 }
        return reduce(0, +) / Double(count)
    }
} 
