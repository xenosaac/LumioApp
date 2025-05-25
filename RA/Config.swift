import Foundation
import AVFoundation

// MARK: - App Configuration

struct AppConfig {
    // MARK: - OpenAI Configuration
    // Replace with your actual OpenAI API key
    // Get your API key from: https://platform.openai.com/api-keys
    static let openAIAPIKey = "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"
    
    // OpenAI API settings
    static let openAIModel = "gpt-3.5-turbo"
    static let maxTokens = 100
    static let temperature = 0.7
    
    // MARK: - Dream Conversation Settings
    static let maxConversationSteps = 10
    static let speechRate: Float = 0.45  // Slightly slower for better comprehension
    static let speechVolume: Float = 0.9  // Increased volume
    
    // MARK: - Audio Settings
    static let audioBufferSize: AVAudioFrameCount = 4096  // Larger buffer for better quality
    static let speechRecognitionLocale = "en-US"
    
    // MARK: - Voice Activity Detection
    static let silenceThreshold: TimeInterval = 2.5  // Seconds of silence before processing
    static let minimumSpeechDuration: TimeInterval = 0.5  // Minimum speech duration to process
    static let audioLevelThreshold: Float = 0.01  // Minimum audio level to consider as speech
    
    // MARK: - UI Settings
    static let animationDuration = 0.3
    static let typingAnimationDuration = 0.6
    
    // MARK: - Speech Recognition Settings
    static let speechRecognitionTimeout: TimeInterval = 60.0  // Max recognition time
    static let partialResultsEnabled = true
    static let offlineRecognitionEnabled = false  // Use online for better accuracy
}

// MARK: - API Key Validation

extension AppConfig {
    static var isOpenAIConfigured: Bool {
        return !openAIAPIKey.isEmpty && openAIAPIKey != "YOUR_OPENAI_API_KEY_HERE"
    }
    
    static var configurationInstructions: String {
        return """
        To use the Dream Tracker AI features:
        
        1. Get an OpenAI API key from https://platform.openai.com/api-keys
        2. Open Config.swift in Xcode
        3. Replace "YOUR_OPENAI_API_KEY_HERE" with your actual API key
        4. Rebuild the app
        
        Note: API usage will incur charges based on OpenAI's pricing.
        """
    }
} 
