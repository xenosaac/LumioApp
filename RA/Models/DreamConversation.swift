import Foundation

// MARK: - Conversation Message

struct ConversationMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let isFromAI: Bool
    let timestamp: Date
    
    init(content: String, isFromAI: Bool) {
        self.id = UUID()
        self.content = content
        self.isFromAI = isFromAI
        self.timestamp = Date()
    }
}

// MARK: - Dream Session

struct DreamSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date?
    let messages: [ConversationMessage]
    let dreamSummary: String?
    let mood: DreamMood?
    let tags: [String]
    
    init() {
        self.id = UUID()
        self.startTime = Date()
        self.endTime = nil
        self.messages = []
        self.dreamSummary = nil
        self.mood = nil
        self.tags = []
    }
    
    init(id: UUID = UUID(), startTime: Date, endTime: Date?, messages: [ConversationMessage], dreamSummary: String?, mood: DreamMood?, tags: [String]) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.messages = messages
        self.dreamSummary = dreamSummary
        self.mood = mood
        self.tags = tags
    }
    
    var formattedDuration: String {
        guard let endTime = endTime else {
            return "In progress..."
        }
        
        let duration = endTime.timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Dream Mood

enum DreamMood: String, CaseIterable, Codable {
    case pleasant = "Pleasant"
    case anxious = "Anxious"
    case nightmare = "Nightmare"
    case lucid = "Lucid"
    case vivid = "Vivid"
    case peaceful = "Peaceful"
    case neutral = "Neutral"
    
    var emoji: String {
        switch self {
        case .pleasant: return "😊"
        case .anxious: return "😰"
        case .nightmare: return "😱"
        case .lucid: return "🧠"
        case .vivid: return "🌈"
        case .peaceful: return "😌"
        case .neutral: return "😐"
        }
    }
    
    var color: String {
        switch self {
        case .pleasant: return "green"
        case .anxious: return "orange"
        case .nightmare: return "red"
        case .lucid: return "purple"
        case .vivid: return "blue"
        case .peaceful: return "mint"
        case .neutral: return "gray"
        }
    }
}

// MARK: - Conversation State

enum ConversationState: Equatable {
    case idle
    case listening
    case processing
    case speaking
    case completed
    case error(String)
    
    var description: String {
        switch self {
        case .idle: return "Ready to listen"
        case .listening: return "Listening..."
        case .processing: return "Thinking..."
        case .speaking: return "Speaking..."
        case .completed: return "Conversation completed"
        case .error(let message): return "Error: \(message)"
        }
    }
}

// MARK: - Speech Recognition State

enum SpeechRecognitionState: Equatable {
    case idle
    case listening
    case processing
    case error(String)
    
    var description: String {
        switch self {
        case .idle: return "Ready"
        case .listening: return "Listening..."
        case .processing: return "Processing..."
        case .error(let message): return "Error: \(message)"
        }
    }
} 