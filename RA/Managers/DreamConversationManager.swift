import Foundation
import Speech
import AVFoundation
import AudioToolbox
import Combine

class DreamConversationManager: NSObject, ObservableObject {
    static let shared = DreamConversationManager()
    
    // MARK: - Published Properties
    @Published var currentSession: DreamSession?
    @Published var messages: [ConversationMessage] = []
    @Published var conversationState: ConversationState = .idle
    @Published var speechRecognitionState: SpeechRecognitionState = .idle
    @Published var isRecording = false
    @Published var isAISpeaking = false
    @Published var dreamSessions: [DreamSession] = []
    @Published var currentTranscript = ""
    @Published var audioLevel: Float = 0.0
    
    // MARK: - Private Properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: AppConfig.speechRecognitionLocale))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    
    // Voice Activity Detection
    private var silenceTimer: Timer?
    private var lastSpeechTime: Date?
    private var speechStartTime: Date?
    private var hasDetectedSpeech = false
    private var audioLevelTimer: Timer?
    private var consecutiveSilenceCount = 0
    
    // OpenAI API Configuration
    private let openAIURL = "https://api.openai.com/v1/chat/completions"
    
    // Conversation flow
    private var conversationStep = 0
    private var isConversationActive = false
    
    // Initial AI prompts for guiding the conversation
    private let initialPrompts = [
        "Hi there! How was your night? Did you have any dreams you'd like to share?",
        "That's interesting! Can you tell me more about what happened in your dream?",
        "How did that make you feel? What emotions did you experience?",
        "Were there any specific people, places, or objects that stood out to you?",
        "Did anything in the dream remind you of something from your waking life?",
        "Was this dream similar to any other dreams you've had recently?",
        "How vivid was this dream? Could you see colors, hear sounds, or feel sensations?",
        "Thank you for sharing your dream with me. Is there anything else about it you'd like to add?"
    ]
    
    // MARK: - Manual Recording Support
    
    private var manualRecordingCompletion: ((String) -> Void)?
    
    // MARK: - Stop Word Detection
    
    private let stopPhrases = [
        "that's all i have",
        "that's all i remember",
        "that's everything",
        "that's it",
        "nothing else",
        "no more",
        "i'm done",
        "that's the end",
        "that's all",
        "i don't remember anything else",
        "i can't remember more",
        "that's the whole dream",
        "end of dream",
        "that's my dream"
    ]
    
    // Add this property to track if we should end after speaking
    private var shouldEndAfterSpeaking = false
    
    override init() {
        super.init()
        setupAudioSession()
        loadDreamSessions()
        synthesizer.delegate = self
    }
    
    // MARK: - Public Methods
    
    func startConversation() {
        guard conversationState == .idle else { return }
        
        // Check if OpenAI is configured
        guard AppConfig.isOpenAIConfigured else {
            conversationState = .error("OpenAI API key not configured. Please check Config.swift")
            return
        }
        
        currentSession = DreamSession()
        messages = []
        conversationStep = 0
        isConversationActive = true
        shouldEndAfterSpeaking = false // Reset the end session flag
        conversationState = .processing
        
        // Start with AI greeting - DO NOT start listening yet
        let greeting = initialPrompts[0]
        addAIMessage(greeting)
        speakText(greeting)
        // Listening will start automatically after AI finishes speaking
    }
    
    func stopConversation() {
        isConversationActive = false
        stopContinuousListening()
        synthesizer.stopSpeaking(at: .immediate)
        
        if let session = currentSession {
            let completedSession = DreamSession(
                id: session.id,
                startTime: session.startTime,
                endTime: Date(),
                messages: messages,
                dreamSummary: generateDreamSummary(),
                mood: analyzeDreamMood(),
                tags: extractDreamTags()
            )
            
            dreamSessions.append(completedSession)
            saveDreamSessions()
        }
        
        conversationState = .completed
        currentSession = nil
        currentTranscript = ""
        resetVoiceDetection()
    }
    
    // MARK: - Voice Detection Reset
    
    private func resetVoiceDetection() {
        hasDetectedSpeech = false
        speechStartTime = nil
        lastSpeechTime = nil
        consecutiveSilenceCount = 0
        audioLevel = 0.0
    }
    
    // MARK: - Continuous Speech Recognition
    
    private func startContinuousListening() {
        // CRITICAL: Never start listening while AI is speaking
        guard isConversationActive && !isAISpeaking else {
            print("Cannot start listening: AI is speaking or conversation not active")
            return
        }
        
        // Double check that synthesizer is not speaking
        guard !synthesizer.isSpeaking else {
            print("Cannot start listening: Synthesizer is still speaking")
            return
        }
        
        requestSpeechRecognitionPermission { [weak self] granted in
            if granted {
                DispatchQueue.main.async {
                    // Check again before starting (state might have changed)
                    if let self = self, self.isConversationActive && !self.isAISpeaking && !self.synthesizer.isSpeaking {
                        self.startSpeechRecognition()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.speechRecognitionState = .error("Speech recognition permission denied")
                }
            }
        }
    }
    
    private func stopContinuousListening() {
        stopRecording()
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        resetVoiceDetection()
    }
    
    // MARK: - Speech Recognition
    
    private func requestSpeechRecognitionPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }
    
    private func startSpeechRecognition() {
        // CRITICAL: Final check before starting speech recognition
        guard isConversationActive && !isAISpeaking && !synthesizer.isSpeaking else {
            print("Aborting speech recognition: AI is speaking or conversation not active")
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            speechRecognitionState = .error("Speech recognition not available")
            return
        }
        
        do {
            // Cancel previous task
            recognitionTask?.cancel()
            recognitionTask = nil
            
            // Reset audio engine if needed
            if audioEngine.isRunning {
                audioEngine.stop()
                audioEngine.inputNode.removeTap(onBus: 0)
            }
            
            // Configure audio session with better settings
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Create recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                speechRecognitionState = .error("Unable to create recognition request")
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = false // Use cloud for better accuracy
            
            // Configure audio engine
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                // CRITICAL: Check if AI started speaking while we're recording
                guard let self = self, !self.isAISpeaking && !self.synthesizer.isSpeaking else {
                    print("Stopping audio processing: AI started speaking")
                    return
                }
                
                recognitionRequest.append(buffer)
                
                // Calculate audio level for visual feedback
                DispatchQueue.main.async {
                    self.updateAudioLevel(from: buffer)
                }
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            conversationState = .listening
            speechRecognitionState = .listening
            resetVoiceDetection()
            
            print("✅ Started listening for user speech")
            
            // Start recognition task
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    // CRITICAL: Stop processing if AI starts speaking
                    if self.isAISpeaking || self.synthesizer.isSpeaking {
                        print("Stopping speech recognition: AI started speaking")
                        self.stopRecording()
                        return
                    }
                    
                    if let result = result {
                        let transcribedText = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if !transcribedText.isEmpty {
                            self.currentTranscript = transcribedText
                            
                            // Mark that we've detected speech
                            if !self.hasDetectedSpeech {
                                self.hasDetectedSpeech = true
                                self.speechStartTime = Date()
                                print("🎤 User speech detected: \(transcribedText)")
                            }
                            
                            self.lastSpeechTime = Date()
                            self.consecutiveSilenceCount = 0
                            
                            // Reset silence timer
                            self.resetSilenceTimer()
                        }
                        
                        if result.isFinal && self.hasDetectedSpeech {
                            print("📝 Final transcript: \(transcribedText)")
                            self.processFinalTranscript(transcribedText)
                        }
                    }
                    
                    if let error = error {
                        print("Speech recognition error: \(error.localizedDescription)")
                        self.handleSpeechRecognitionError(error)
                    }
                }
            }
            
            // Set a timeout to prevent getting stuck
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
                if self.isRecording && self.conversationState == .listening {
                    if self.hasDetectedSpeech && !self.currentTranscript.isEmpty {
                        print("⏰ Timeout reached, processing current transcript")
                        self.processFinalTranscript(self.currentTranscript)
                    } else {
                        print("⏰ Timeout reached, no speech detected, restarting")
                        self.restartListening()
                    }
                }
            }
            
        } catch {
            speechRecognitionState = .error(error.localizedDescription)
            print("Failed to start speech recognition: \(error.localizedDescription)")
        }
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleSilenceDetected()
            }
        }
    }
    
    private func handleSilenceDetected() {
        consecutiveSilenceCount += 1
        
        if hasDetectedSpeech && !currentTranscript.isEmpty {
            // We have speech, process it
            processFinalTranscript(currentTranscript)
        } else if consecutiveSilenceCount >= 3 {
            // Too much silence without speech, restart
            restartListening()
        } else {
            // Continue waiting for speech
            resetSilenceTimer()
        }
    }
    
    private func processFinalTranscript(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanText.isEmpty && cleanText.count > 2 else {
            // Text too short, continue listening
            restartListening()
            return
        }
        
        // Stop listening and process the speech
        stopContinuousListening()
        handleUserSpeech(cleanText)
    }
    
    private func handleSpeechRecognitionError(_ error: Error) {
        // Don't show error for common interruptions, just restart
        if isConversationActive && !isAISpeaking {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.restartListening()
            }
        }
    }
    
    private func restartListening() {
        // CRITICAL: Never restart listening while AI is speaking
        guard isConversationActive && !isAISpeaking && !synthesizer.isSpeaking else {
            print("Cannot restart listening: AI is speaking or conversation not active")
            return
        }
        
        print("🔄 Restarting speech recognition...")
        stopRecording()
        resetVoiceDetection()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Check again after delay to ensure AI hasn't started speaking
            if self.isConversationActive && !self.isAISpeaking && !self.synthesizer.isSpeaking {
                self.startSpeechRecognition()
            } else {
                print("Cancelled restart: AI started speaking during delay")
            }
        }
    }
    
    private func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        currentTranscript = ""
        audioLevel = 0.0
        
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
    }
    
    // MARK: - Audio Level Monitoring
    
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0.0
        
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        
        let averageLevel = sum / Float(frameLength)
        let normalizedLevel = min(averageLevel * 20, 1.0) // Increased sensitivity
        
        DispatchQueue.main.async {
            self.audioLevel = normalizedLevel
        }
    }
    
    // MARK: - Text-to-Speech
    
    private func speakText(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        
        // Use a more natural voice
        if let voice = AVSpeechSynthesisVoice(language: AppConfig.speechRecognitionLocale) {
            utterance.voice = voice
        } else {
            // Fallback to default voice
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        utterance.rate = AppConfig.speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = AppConfig.speechVolume
        
        isAISpeaking = true
        conversationState = .speaking
        synthesizer.speak(utterance)
    }
    
    // MARK: - OpenAI Integration
    
    private func handleUserSpeech(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Empty text, continue listening only if AI is not speaking
            if isConversationActive && !isAISpeaking && !synthesizer.isSpeaking {
                startContinuousListening()
            }
            return
        }
        
        print("👤 User said: \(text)")
        
        // CRITICAL: Stop all recording immediately when processing user input
        stopContinuousListening()
        
        // Add user message
        addUserMessage(text)
        
        // Check for stop words before generating AI response
        if detectStopWords(in: text) {
            handleStopWordDetected()
            return
        }
        
        // Generate AI response - this will prevent any recording until AI finishes
        conversationState = .processing
        speechRecognitionState = .processing
        generateAIResponse(for: text)
    }
    
    private func generateAIResponse(for userInput: String) {
        // Ensure we're not recording while generating response
        if isRecording {
            stopContinuousListening()
        }
        
        Task {
            do {
                let response = try await callOpenAIAPI(userInput: userInput)
                
                DispatchQueue.main.async {
                    print("🤖 AI responding: \(response)")
                    
                    // Check if AI response contains end session marker
                    if response.contains("[END_SESSION]") {
                        // Remove the marker from the displayed message
                        let cleanResponse = response.replacingOccurrences(of: "[END_SESSION]", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        self.addAIMessage(cleanResponse)
                        
                        // CRITICAL: Set AI speaking state BEFORE starting speech
                        self.isAISpeaking = true
                        self.speakText(cleanResponse)
                        
                        // Mark that we should end after this speech
                        self.shouldEndAfterSpeaking = true
                        
                        print("🛑 AI detected end session - will end after speaking")
                    } else {
                        self.addAIMessage(response)
                        
                        // CRITICAL: Set AI speaking state BEFORE starting speech
                        self.isAISpeaking = true
                        self.speakText(response)
                        self.conversationStep += 1
                        
                        // Check if conversation should continue
                        if self.conversationStep >= AppConfig.maxConversationSteps {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                self.stopConversation()
                            }
                        }
                    }
                    // Listening will start automatically after AI finishes speaking (in delegate)
                }
            } catch {
                DispatchQueue.main.async {
                    self.conversationState = .error("Failed to generate AI response: \(error.localizedDescription)")
                    print("OpenAI API Error: \(error.localizedDescription)")
                    
                    // Try to continue conversation despite error, but only if AI is not speaking
                    if self.isConversationActive && !self.isAISpeaking && !self.synthesizer.isSpeaking {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            if !self.isAISpeaking && !self.synthesizer.isSpeaking {
                                self.startContinuousListening()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func callOpenAIAPI(userInput: String) async throws -> String {
        guard let url = URL(string: openAIURL) else {
            throw URLError(.badURL)
        }
        
        // Build conversation context
        let systemMessage = """
        you first have to greet the user. 
        You are a partner who is genuinely interested in your significant other's dreams. You're lying in bed together in the morning, and they're sharing their dreams with you. and you wouldn't want to bother too much. once they finished, you should stop asking not useful information. give a summary once the conversation ends
            
            PERSONALITY:
            - Warm, intimate, and emotionally supportive
            - Use casual, loving language like, "honey", "that's so interesting"
            - Show genuine curiosity and emotional connection
            - React with appropriate emotions (excitement, concern, wonder)
            - Be encouraging and make them feel heard and valued
            
            CONVERSATION STYLE:
            - Keep responses very brief (50 words max)
            - Use natural, intimate conversation patterns
            - Ask follow-up questions that show you care
            - Give emotional validation and support
            - Use expressions like "wow", "oh my", "that sounds amazing/scary/beautiful"
            
            RESPONSE EXAMPLES:
            - "Oh wow babe, that sounds so vivid! What happened next?"
            - "That must have felt scary honey. Tell me more about that part."
            - "How beautiful! I love how your mind works. What else do you remember?"
            - "That's so interesting! How did you feel in the dream?"
            - "Aww, that sounds peaceful. I'm so glad you had that dream."
            
            RULES:
            - ONLY discuss dreams and sleep - gently redirect other topics
            - When they say "that's it", "done", etc. - lovingly acknowledge and wrap up
            - Don't repeat their story back, just respond emotionally and ask for more
            - Be present and engaged like a caring partner would be
        limit your response to 50 words
        """
        
        let conversationHistory = messages.map { message in
            [
                "role": message.isFromAI ? "assistant" : "user",
                "content": message.content
            ]
        }
        
        var requestMessages: [[String: String]] = [
            ["role": "system", "content": systemMessage]
        ]
        requestMessages.append(contentsOf: conversationHistory)
        requestMessages.append(["role": "user", "content": userInput])
        
        let requestBody: [String: Any] = [
            "model": AppConfig.openAIModel,
            "messages": requestMessages,
            "max_tokens": AppConfig.maxTokens,
            "temperature": AppConfig.temperature
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(AppConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        throw URLError(.cannotParseResponse)
    }
    
    // MARK: - Message Management
    
    private func addUserMessage(_ content: String) {
        let message = ConversationMessage(content: content, isFromAI: false)
        messages.append(message)
    }
    
    private func addAIMessage(_ content: String) {
        let message = ConversationMessage(content: content, isFromAI: true)
        messages.append(message)
    }
    
    // MARK: - Dream Analysis
    
    private func generateDreamSummary() -> String {
        let userMessages = messages.filter { !$0.isFromAI }.map { $0.content }
        return userMessages.joined(separator: " ")
    }
    
    private func analyzeDreamMood() -> DreamMood {
        let dreamText = generateDreamSummary().lowercased()
        
        if dreamText.contains("nightmare") || dreamText.contains("scary") || dreamText.contains("afraid") {
            return .nightmare
        } else if dreamText.contains("peaceful") || dreamText.contains("calm") || dreamText.contains("serene") {
            return .peaceful
        } else if dreamText.contains("anxious") || dreamText.contains("worried") || dreamText.contains("stress") {
            return .anxious
        } else if dreamText.contains("lucid") || dreamText.contains("control") || dreamText.contains("aware") {
            return .lucid
        } else if dreamText.contains("vivid") || dreamText.contains("bright") || dreamText.contains("colorful") {
            return .vivid
        } else if dreamText.contains("happy") || dreamText.contains("joy") || dreamText.contains("pleasant") {
            return .pleasant
        }
        
        return .neutral
    }
    
    private func extractDreamTags() -> [String] {
        let dreamText = generateDreamSummary().lowercased()
        var tags: [String] = []
        
        let commonDreamElements = [
            "flying", "falling", "water", "animals", "family", "friends", "school", "work",
            "house", "car", "death", "birth", "wedding", "travel", "food", "money",
            "chase", "lost", "late", "naked", "teeth", "hair", "blood", "fire"
        ]
        
        for element in commonDreamElements {
            if dreamText.contains(element) {
                tags.append(element.capitalized)
            }
        }
        
        return Array(Set(tags)).sorted()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Data Persistence
    
    func saveDreamSessions() {
        if let encoded = try? JSONEncoder().encode(dreamSessions) {
            UserDefaults.standard.set(encoded, forKey: "dreamSessions")
        }
    }
    
    private func loadDreamSessions() {
        if let data = UserDefaults.standard.data(forKey: "dreamSessions"),
           let decoded = try? JSONDecoder().decode([DreamSession].self, from: data) {
            dreamSessions = decoded
        }
    }
    
    func clearAllSessions() {
        dreamSessions = []
        saveDreamSessions()
    }
    
    // MARK: - Manual Recording Support
    
    func startManualRecording(completion: @escaping (String) -> Void) {
        manualRecordingCompletion = completion
        
        // Use similar setup but for manual recording
        do {
            // Cancel any existing tasks
            recognitionTask?.cancel()
            recognitionTask = nil
            
            if audioEngine.isRunning {
                audioEngine.stop()
                audioEngine.inputNode.removeTap(onBus: 0)
            }
            
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            
            recognitionRequest.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                DispatchQueue.main.async {
                    if let result = result {
                        let text = result.bestTranscription.formattedString
                        self?.currentTranscript = text
                    }
                }
            }
            
        } catch {
            print("Failed to start manual recording: \(error)")
        }
    }
    
    func stopManualRecording() {
        let finalText = currentTranscript
        
        // Stop recording
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Return the recorded text
        manualRecordingCompletion?(finalText)
        manualRecordingCompletion = nil
        currentTranscript = ""
    }
    
    func processManualInput(_ text: String) {
        handleUserSpeech(text)
    }
    
    // MARK: - Stop Word Detection
    
    private func detectStopWords(in text: String) -> Bool {
        let lowercaseText = text.lowercased()
        
        // Check for exact phrase matches
        for phrase in stopPhrases {
            if lowercaseText.contains(phrase) {
                print("🛑 Stop phrase detected: '\(phrase)'")
                return true
            }
        }
        
        // Check for pattern-based stop indicators
        let stopPatterns = [
            "that.*all.*remember",
            "that.*all.*have",
            "nothing.*else",
            "don't.*remember.*more",
            "can't.*remember.*more",
            "that.*it.*dream"
        ]
        
        for pattern in stopPatterns {
            if lowercaseText.range(of: pattern, options: .regularExpression) != nil {
                print("🛑 Stop pattern detected: '\(pattern)'")
                return true
            }
        }
        
        return false
    }
    
    private func handleStopWordDetected() {
        print("🛑 Stop word detected - preparing to end session")
        
        // Add a final AI message acknowledging the end
        let closingMessage = "Thank you for sharing your dream with me. It sounds like a fascinating experience! I hope our conversation helped you reflect on it. Sweet dreams!"
        addAIMessage(closingMessage)
        
        // Speak the closing message, then end the session
        isAISpeaking = true
        conversationState = .speaking
        speakText(closingMessage)
        
        // Mark that we should end after this speech
        shouldEndAfterSpeaking = true
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension DreamConversationManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            print("🤖 AI finished speaking")
            
            // CRITICAL: Mark AI as no longer speaking
            self.isAISpeaking = false
            self.speechRecognitionState = .idle
            
            // Check if we should end the session after this speech
            if self.shouldEndAfterSpeaking {
                print("🛑 Ending session as requested")
                self.shouldEndAfterSpeaking = false
                self.stopConversation()
                return
            }
            
            // Only start listening if conversation is still active and we're not in error state
            if self.isConversationActive && self.conversationState != .completed {
                // Check if we're not in an error state
                switch self.conversationState {
                case .error:
                    break // Don't start listening if in error state
                default:
                    self.conversationState = .idle
                    
                    // Wait a moment for audio to settle, then start listening for user
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // Double-check state hasn't changed
                        if self.isConversationActive && !self.isAISpeaking && !self.synthesizer.isSpeaking {
                            print("🎤 Starting to listen for user response...")
                            self.startContinuousListening()
                        }
                    }
                }
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            print("🤖 AI started speaking")
            
            // CRITICAL: Ensure we're not recording while AI speaks
            if self.isRecording {
                print("⚠️ Stopping recording because AI started speaking")
                self.stopContinuousListening()
            }
            
            self.conversationState = .speaking
            self.isAISpeaking = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            print("🤖 AI paused speaking")
            // Don't start listening during pauses - wait for complete finish
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            print("🤖 AI continued speaking")
            // Ensure we're still not recording
            if self.isRecording {
                self.stopContinuousListening()
            }
        }
    }
} 
