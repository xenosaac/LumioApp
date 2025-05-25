import Foundation

// Model representing a user-configurable alarm
// with a time window and randomly generated trigger time
struct Alarm: Identifiable, Codable {
    let id: UUID
    var name: String  // user-specified alarm name
    var startTime: Date  // window start (hour/minute)
    var endTime: Date    // window end (hour/minute)
    var isActive: Bool   // whether the alarm is currently enabled
    var repeatDays: Set<Weekday>  // selected weekdays for repeating
    var isRepeating: Bool  // if true, alarm will reschedule itself after firing
    var randomTime: Date?  // actual computed trigger time for the next ring
    var soundName: String  // name of the sound to play when alarm triggers
    
    init(id: UUID = UUID(), name: String, startTime: Date, endTime: Date, isActive: Bool = true, repeatDays: Set<Weekday> = [], isRepeating: Bool = false, soundName: String = "beep") {
        // Initialize properties
        self.id = id
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.isActive = isActive
        self.repeatDays = repeatDays
        self.isRepeating = isRepeating
        self.soundName = soundName
        // If alarm is enabled at creation, compute an initial random trigger time
        if isActive {
            generateRandomTime()
        }
    }
    
    mutating func generateRandomTime() {
        // Generate and assign a new randomTime based on the configured window
        let calendar = Calendar.current
        let now = Date()
        // 1. Extract the hour/minute components from user start/end settings
        let startComps = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComps = calendar.dateComponents([.hour, .minute], from: endTime)
        guard let startHour = startComps.hour, let startMinute = startComps.minute,
              let endHour = endComps.hour, let endMinute = endComps.minute else {
            // Invalid component extraction: clear randomTime
            randomTime = nil
            return
        }
        // 2. Construct full Date objects for start/end today
        let todayStart = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: now)!
        let todayEnd = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: now)!
        var windowStart: Date
        var windowEnd: Date
        // 3. Determine whether to schedule in today's window or roll to tomorrow
        if now > todayEnd {
            windowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
            windowEnd = calendar.date(byAdding: .day, value: 1, to: todayEnd)!
        } else if now > todayStart {
            windowStart = now  // start from now if within window
            windowEnd = todayEnd
        } else {
            // window hasn't started yet today
            windowStart = todayStart
            windowEnd = todayEnd
        }
        // 4. Randomly pick an interval within the computed window
        let interval = windowEnd.timeIntervalSince(windowStart)
        let offset = Double.random(in: 0...interval)
        randomTime = windowStart.addingTimeInterval(offset)
    }
}

// Weekday enum to support repeat selection by day of week
enum Weekday: Int, Codable, CaseIterable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    
    var name: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
} 