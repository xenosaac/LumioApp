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
            // First save with basic analysis
            let basicSession = DreamSession(
                id: session.id,
                startTime: session.startTime,
                endTime: Date(),
                messages: messages,
                dreamSummary: "Generating AI analysis...",
                mood: analyzeDreamMood(),
                tags: extractDreamTags(),
                title: "Generating title..."
            )
            
            dreamSessions.append(basicSession)
            saveDreamSessions()
            
            // Then generate AI content and update
            let dreamText = messages.filter { !$0.isFromAI }.map { $0.content }.joined(separator: " ")
            print("🔍 Dream text for AI analysis: '\(dreamText)' (length: \(dreamText.count))")
            
            if dreamText.count > 50 {
                Task {
                    print("🚀 Starting AI content generation...")
                    do {
                        print("📝 Generating summary...")
                        let summary = try await generateGPTSummary(dreamText: dreamText)
                        print("✅ Summary generated: \(summary.prefix(50))...")
                        
                        print("🏷️ Generating title...")
                        let title = try await generateDreamTitle(dreamText: dreamText)
                        print("✅ Title generated: '\(title)'")
                        
                        print("🔖 Generating keywords...")
                        let aiKeywords = try await generateAIKeywords(dreamText: dreamText)
                        print("✅ Keywords generated: \(aiKeywords)")
                        
                        DispatchQueue.main.async {
                            // Update the session with AI-generated content
                            if let index = self.dreamSessions.firstIndex(where: { $0.id == session.id }) {
                                let updatedSession = DreamSession(
                                    id: session.id,
                                    startTime: session.startTime,
                                    endTime: basicSession.endTime,
                                    messages: self.messages,
                                    dreamSummary: summary,
                                    mood: self.analyzeDreamMood(),
                                    tags: aiKeywords,
                                    title: title
                                )
                                
                                self.dreamSessions[index] = updatedSession
                                self.saveDreamSessions()
                                print("✅ AI content generated and session updated successfully")
                                print("   📄 Title: '\(title)'")
                                print("   📝 Summary: '\(summary.prefix(100))...'")
                                print("   🏷️ Tags: \(aiKeywords)")
                            } else {
                                print("❌ Could not find session to update")
                            }
                        }
                    } catch {
                        print("❌ Failed to generate AI content: \(error)")
                        print("   Error details: \(error.localizedDescription)")
                        
                        // Try to get more specific error information
                        if let urlError = error as? URLError {
                            print("   URL Error Code: \(urlError.code)")
                            print("   URL Error Description: \(urlError.localizedDescription)")
                        }
                        
                        // Update with fallback content
                        DispatchQueue.main.async {
                            if let index = self.dreamSessions.firstIndex(where: { $0.id == session.id }) {
                                let fallbackSession = DreamSession(
                                    id: session.id,
                                    startTime: session.startTime,
                                    endTime: basicSession.endTime,
                                    messages: self.messages,
                                    dreamSummary: String(dreamText.prefix(200)),
                                    mood: self.analyzeDreamMood(),
                                    tags: self.extractDreamTags(),
                                    title: "Dream Session"
                                )
                                
                                self.dreamSessions[index] = fallbackSession
                                self.saveDreamSessions()
                                print("📝 Updated session with fallback content")
                            }
                        }
                    }
                }
            } else {
                print("⚠️ Dream text too short (\(dreamText.count) chars), skipping AI generation")
            }
        }
        
        conversationState = .completed
        currentSession = nil
        currentTranscript = ""
        resetVoiceDetection()
    }
    
    // MARK: - Session Editing Methods
    
    func updateSessionTitle(_ sessionId: UUID, newTitle: String) {
        if let index = dreamSessions.firstIndex(where: { $0.id == sessionId }) {
            let session = dreamSessions[index]
            let updatedSession = DreamSession(
                id: session.id,
                startTime: session.startTime,
                endTime: session.endTime,
                messages: session.messages,
                dreamSummary: session.dreamSummary,
                mood: session.mood,
                tags: session.tags,
                title: newTitle.isEmpty ? nil : newTitle
            )
            dreamSessions[index] = updatedSession
            saveDreamSessions()
        }
    }
    
    func updateSessionSummary(_ sessionId: UUID, newSummary: String) {
        if let index = dreamSessions.firstIndex(where: { $0.id == sessionId }) {
            let session = dreamSessions[index]
            let updatedSession = DreamSession(
                id: session.id,
                startTime: session.startTime,
                endTime: session.endTime,
                messages: session.messages,
                dreamSummary: newSummary.isEmpty ? nil : newSummary,
                mood: session.mood,
                tags: session.tags,
                title: session.title
            )
            dreamSessions[index] = updatedSession
            saveDreamSessions()
        }
    }
    
    func updateSessionMood(_ sessionId: UUID, newMood: DreamMood?) {
        if let index = dreamSessions.firstIndex(where: { $0.id == sessionId }) {
            let session = dreamSessions[index]
            let updatedSession = DreamSession(
                id: session.id,
                startTime: session.startTime,
                endTime: session.endTime,
                messages: session.messages,
                dreamSummary: session.dreamSummary,
                mood: newMood,
                tags: session.tags,
                title: session.title
            )
            dreamSessions[index] = updatedSession
            saveDreamSessions()
        }
    }
    
    func updateSessionTags(_ sessionId: UUID, newTags: [String]) {
        if let index = dreamSessions.firstIndex(where: { $0.id == sessionId }) {
            let session = dreamSessions[index]
            let updatedSession = DreamSession(
                id: session.id,
                startTime: session.startTime,
                endTime: session.endTime,
                messages: session.messages,
                dreamSummary: session.dreamSummary,
                mood: session.mood,
                tags: newTags,
                title: session.title
            )
            dreamSessions[index] = updatedSession
            saveDreamSessions()
        }
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
        print("🗣️ Attempting to speak: \(text)")
        
        // First, try to configure audio session with comprehensive debugging
        setupAudioSessionForSpeech()
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Use a more natural voice with better fallback
        if let voice = AVSpeechSynthesisVoice(language: AppConfig.speechRecognitionLocale) {
            utterance.voice = voice
            print("✅ Using voice: \(voice.name) (\(voice.language)) - Quality: \(voice.quality.rawValue)")
        } else if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
            print("✅ Using fallback voice: \(voice.name) (\(voice.language)) - Quality: \(voice.quality.rawValue)")
        } else {
            print("⚠️ No voice found, using system default")
        }
        
        utterance.rate = AppConfig.speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = AppConfig.speechVolume
        
        print("🔊 TTS Settings - Rate: \(utterance.rate), Volume: \(utterance.volume), Pitch: \(utterance.pitchMultiplier)")
        
        // Check if synthesizer is available and ready
        print("🎙️ Synthesizer state:")
        print("   - Is speaking: \(synthesizer.isSpeaking)")
        print("   - Is paused: \(synthesizer.isPaused)")
        
        if synthesizer.isSpeaking {
            print("⚠️ Synthesizer is already speaking, stopping previous speech")
            synthesizer.stopSpeaking(at: .immediate)
            
            // Wait a moment before starting new speech
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.attemptSpeechSynthesis(utterance)
            }
        } else {
            attemptSpeechSynthesis(utterance)
        }
    }
    
    private func setupAudioSessionForSpeech() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Try multiple configurations in order of preference
            let configurations: [(AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)] = [
                (.playAndRecord, .spokenAudio, [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]),
                (.playback, .spokenAudio, [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]),
                (.playAndRecord, .default, [.defaultToSpeaker]),
                (.playback, .default, [])
            ]
            
            var success = false
            
            for (category, mode, options) in configurations {
                do {
                    try audioSession.setCategory(category, mode: mode, options: options)
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    
                    print("✅ Audio session configured successfully:")
                    print("   - Category: \(category)")
                    print("   - Mode: \(mode)")
                    print("   - Options: \(options)")
                    print("   - Current route: \(audioSession.currentRoute.outputs.map { $0.portName }.joined(separator: ", "))")
                    
                    success = true
                    break
                } catch {
                    print("❌ Failed to configure audio session with \(category)/\(mode): \(error)")
                    continue
                }
            }
            
            if !success {
                print("❌ Failed to configure audio session with any configuration!")
            }
            
            // Additional audio session info
            print("📱 Final audio session state:")
            print("   - Output volume: \(audioSession.outputVolume)")
            print("   - Other audio playing: \(audioSession.isOtherAudioPlaying)")
            print("   - Available inputs: \(audioSession.availableInputs?.count ?? 0)")
            
        } catch {
            print("❌ Critical error setting up audio session: \(error)")
        }
    }
    
    private func attemptSpeechSynthesis(_ utterance: AVSpeechUtterance) {
        isAISpeaking = true
        conversationState = .speaking
        
        print("🎙️ Starting speech synthesis...")
        print("   - Text length: \(utterance.speechString.count) characters")
        print("   - Voice: \(utterance.voice?.name ?? "default")")
        
        // Start synthesis
        synthesizer.speak(utterance)
        
        // Add multiple timeout checks to verify TTS actually starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.synthesizer.isSpeaking {
                print("✅ Speech synthesis confirmed started after 0.5s")
            } else {
                print("❌ Speech synthesis may have failed - synthesizer not speaking after 0.5s")
                self.handleSpeechSynthesisFailure()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.synthesizer.isSpeaking {
                print("✅ Speech synthesis still active after 2s")
            } else {
                print("⚠️ Speech synthesis finished or failed within 2s")
            }
        }
    }
    
    private func handleSpeechSynthesisFailure() {
        print("🔧 Attempting TTS recovery...")
        
        // Try to reset the synthesizer
        isAISpeaking = false
        
        // Test with a very simple utterance
        let simpleTest = AVSpeechUtterance(string: "Test")
        simpleTest.rate = 0.5
        simpleTest.volume = 1.0
        
        print("🔧 Trying simple test utterance...")
        synthesizer.speak(simpleTest)
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
            - Give emotional validation and support but not just repeat what they said. focus and think about how to push the store further.
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
        limit your response to 30 words
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
    
    private func generateGPTSummary(dreamText: String) async throws -> String {
        guard let url = URL(string: openAIURL) else {
            throw URLError(.badURL)
        }
        
        let systemMessage = """
        You are a dream analyst. Create an insightful summary of the dream described below. 
        Focus on the main narrative, key symbols, emotions, and any notable patterns or themes. make sure to keep all the information as detailed as possible. always use a second person perspective
        """
        
        let userPrompt = "Please summarize this dream: \(dreamText)"
        
        let requestBody: [String: Any] = [
            "model": AppConfig.openAIModel,
            "messages": [
                ["role": "system", "content": systemMessage],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 150,
            "temperature": 0.7
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
    
    private func generateDreamTitle(dreamText: String) async throws -> String {
        print("🏷️ Starting title generation for text: '\(dreamText.prefix(100))...'")
        
        guard let url = URL(string: openAIURL) else {
            print("❌ Invalid OpenAI URL")
            throw URLError(.badURL)
        }
        
        let systemMessage = """
        You are a creative dream interpreter. Generate a short, evocative title for the dream described below.
        The title should be 2-6 words that capture the essence, main theme, or most memorable element of the dream.
        Make it poetic, intriguing, and memorable. Avoid generic titles.
        
        Examples of good titles:
        - "The Flying Library"
        - "Underwater Tea Party"
        - "Chasing Purple Shadows"
        - "The Singing Forest"
        - "Lost in Mirror Maze"
        """
        
        let userPrompt = "Create a creative title for this dream: \(dreamText)"
        
        let requestBody: [String: Any] = [
            "model": AppConfig.openAIModel,
            "messages": [
                ["role": "system", "content": systemMessage],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 50,
            "temperature": 0.8
        ]
        
        print("🌐 Making API request to OpenAI for title generation...")
        print("   Model: \(AppConfig.openAIModel)")
        print("   Max tokens: 50")
        print("   User prompt length: \(userPrompt.count)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(AppConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Failed to serialize request body: \(error)")
            throw error
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 API Response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    print("❌ Non-200 status code received")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("   Response body: \(responseString)")
                    }
                }
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ Failed to parse JSON response")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   Raw response: \(responseString)")
                }
                throw URLError(.cannotParseResponse)
            }
            
            print("📄 JSON response keys: \(json.keys)")
            
            if let error = json["error"] as? [String: Any] {
                print("❌ OpenAI API error: \(error)")
                throw URLError(.badServerResponse)
            }
            
            guard let choices = json["choices"] as? [[String: Any]] else {
                print("❌ No choices in response")
                print("   Full JSON: \(json)")
                throw URLError(.cannotParseResponse)
            }
            
            guard let firstChoice = choices.first else {
                print("❌ Empty choices array")
                throw URLError(.cannotParseResponse)
            }
            
            guard let message = firstChoice["message"] as? [String: Any] else {
                print("❌ No message in first choice")
                print("   First choice: \(firstChoice)")
                throw URLError(.cannotParseResponse)
            }
            
            guard let content = message["content"] as? String else {
                print("❌ No content in message")
                print("   Message: \(message)")
                throw URLError(.cannotParseResponse)
            }
            
            let cleanTitle = content.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
            print("✅ Title generation successful: '\(cleanTitle)'")
            return cleanTitle
            
        } catch {
            print("❌ Network error during title generation: \(error)")
            print("   Error type: \(type(of: error))")
            print("   Error description: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func generateAIKeywords(dreamText: String) async throws -> [String] {
        guard let url = URL(string: openAIURL) else {
            throw URLError(.badURL)
        }
        
        let systemMessage = """
        You are a dream analyst. Extract 5-8 key themes, symbols, emotions, and elements from the dream described below.
        Focus on the most significant and searchable aspects that would help someone find this dream later.
        Return only the keywords separated by commas, no explanations.
        
        Examples: flying, water, family, anxiety, childhood home, purple light, transformation, chase
        """
        
        let userPrompt = "Extract key searchable elements from this dream: \(dreamText)"
        
        let requestBody: [String: Any] = [
            "model": AppConfig.openAIModel,
            "messages": [
                ["role": "system", "content": systemMessage],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 100,
            "temperature": 0.5
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
            let keywords = content.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).capitalized }
                .filter { !$0.isEmpty }
            return Array(keywords.prefix(8))
        }
        
        throw URLError(.cannotParseResponse)
    }
    
    private func analyzeDreamMood() -> DreamMood {
        let dreamText = messages.filter { !$0.isFromAI }.map { $0.content }.joined(separator: " ").lowercased()
        
        // Enhanced mood analysis with more keywords
        let moodKeywords: [DreamMood: [String]] = [
            .nightmare: ["nightmare", "scary", "afraid", "terrified", "horror", "monster", "chase", "trapped", "falling", "death", "dark", "evil"],
            .anxious: ["anxious", "worried", "stress", "nervous", "panic", "overwhelmed", "lost", "confused", "pressure", "urgent"],
            .peaceful: ["peaceful", "calm", "serene", "tranquil", "relaxed", "gentle", "soft", "quiet", "still", "meditation"],
            .lucid: ["lucid", "control", "aware", "conscious", "realize", "knew I was dreaming", "could control"],
            .vivid: ["vivid", "bright", "colorful", "clear", "detailed", "realistic", "intense", "sharp"],
            .pleasant: ["happy", "joy", "pleasant", "wonderful", "beautiful", "amazing", "love", "fun", "exciting", "magical"]
        ]
        
        var moodScores: [DreamMood: Int] = [:]
        
        for (mood, keywords) in moodKeywords {
            let score = keywords.reduce(0) { count, keyword in
                count + dreamText.components(separatedBy: keyword).count - 1
            }
            moodScores[mood] = score
        }
        
        // Return the mood with the highest score, or neutral if no matches
        let topMood = moodScores.max { $0.value < $1.value }
        return topMood?.value ?? 0 > 0 ? topMood!.key : .neutral
    }
    
    private func extractDreamTags() -> [String] {
        let dreamText = messages.filter { !$0.isFromAI }.map { $0.content }.joined(separator: " ").lowercased()
        
        // Common dream symbols and themes
        let dreamSymbols = [
            // People
            "family", "mother", "father", "friend", "stranger", "child", "baby", "teacher", "boss",
            // Animals
            "dog", "cat", "bird", "snake", "spider", "horse", "fish", "lion", "bear", "wolf",
            // Places
            "house", "school", "work", "beach", "forest", "mountain", "city", "car", "airplane", "train",
            // Objects
            "water", "fire", "mirror", "door", "window", "phone", "computer", "book", "money", "key",
            // Actions
            "flying", "falling", "running", "swimming", "driving", "climbing", "dancing", "singing",
            // Emotions/States
            "lost", "trapped", "free", "powerful", "weak", "invisible", "giant", "small",
            // Colors
            "red", "blue", "green", "yellow", "black", "white", "purple", "orange", "pink",
            // Weather/Nature
            "rain", "snow", "sun", "storm", "wind", "ocean", "river", "tree", "flower"
        ]
        
        var foundTags: [String] = []
        
        for symbol in dreamSymbols {
            if dreamText.contains(symbol) {
                foundTags.append(symbol.capitalized)
            }
        }
        
        // Also extract any words that appear multiple times (potential important themes)
        let words = dreamText.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { $0.count > 3 } // Only words longer than 3 characters
            .map { $0.lowercased() }
        
        let wordCounts = words.reduce(into: [:]) { counts, word in
            counts[word, default: 0] += 1
        }
        
        let repeatedWords = wordCounts.filter { $0.value > 1 && $0.key.count > 4 }
            .map { $0.key.capitalized }
        
        foundTags.append(contentsOf: repeatedWords)
        
        // Remove duplicates and limit to 10 tags
        return Array(Set(foundTags)).prefix(10).map { String($0) }
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use playAndRecord category with improved options for TTS
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers])
            try audioSession.setActive(true)
            print("✅ Audio session configured successfully for TTS")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
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
        dreamSessions.removeAll()
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
    
    // MARK: - Debug/Test Methods
    
    func testTextToSpeech() {
        print("🧪 Testing text-to-speech functionality...")
        
        // Check device audio state first
        checkAudioSystemState()
        
        // Simple test message
        let testMessage = "Hello! This is a test of the text to speech system. Can you hear me?"
        
        // Ensure we're not in a conversation
        isConversationActive = false
        stopContinuousListening()
        
        // Test the speech synthesis
        speakText(testMessage)
    }
    
    private func checkAudioSystemState() {
        print("🔍 === AUDIO SYSTEM DIAGNOSTICS ===")
        
        let audioSession = AVAudioSession.sharedInstance()
        
        // Check volume
        do {
            try audioSession.setActive(true)
            print("📱 System volume: \(audioSession.outputVolume)")
            if audioSession.outputVolume == 0.0 {
                print("⚠️ WARNING: System volume is at 0!")
            }
        } catch {
            print("❌ Failed to check system volume: \(error)")
        }
        
        // Check audio session category and options
        print("🔊 Audio session category: \(audioSession.category)")
        print("🔊 Audio session mode: \(audioSession.mode)")
        print("🔊 Audio session options: \(audioSession.categoryOptions)")
        
        // Check current route
        let currentRoute = audioSession.currentRoute
        print("🎧 Current audio route:")
        for output in currentRoute.outputs {
            print("   - Output: \(output.portName) (\(output.portType))")
        }
        for input in currentRoute.inputs {
            print("   - Input: \(input.portName) (\(input.portType))")
        }
        
        // Check if other audio is playing
        print("🎵 Other audio playing: \(audioSession.isOtherAudioPlaying)")
        
        // Check silent mode (iOS doesn't provide direct API, but we can check some indicators)
        print("🔇 Audio session allows recording: \(audioSession.recordPermission == .granted)")
        
        // Test system sound to verify basic audio output
        print("🔔 Testing system sound...")
        AudioServicesPlaySystemSound(SystemSoundID(1322)) // Modern notification sound
        
        print("=== END AUDIO DIAGNOSTICS ===")
    }
    
    func testSystemSound() {
        print("🔔 Testing basic system sound...")
        // Play a simple system sound to test if audio output works at all
        AudioServicesPlaySystemSound(SystemSoundID(1322)) // Modern notification sound
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🔔 System sound should have played. If you didn't hear it, check:")
            print("   1. Device is not in silent mode (check side switch)")
            print("   2. Volume is turned up")
            print("   3. Audio is not routed to disconnected Bluetooth device")
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension DreamConversationManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            print("🤖 AI finished speaking: '\(utterance.speechString)'")
            
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
            print("🤖 AI started speaking: '\(utterance.speechString)'")
            
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
            print("🤖 AI paused speaking: '\(utterance.speechString)'")
            // Don't start listening during pauses - wait for complete finish
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            print("🤖 AI continued speaking: '\(utterance.speechString)'")
            // Ensure we're still not recording
            if self.isRecording {
                self.stopContinuousListening()
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            print("🤖 AI speech was cancelled: '\(utterance.speechString)'")
            self.isAISpeaking = false
            self.speechRecognitionState = .idle
            
            // If conversation is still active, try to continue
            if self.isConversationActive && self.conversationState != .completed {
                self.conversationState = .idle
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if self.isConversationActive && !self.isAISpeaking && !self.synthesizer.isSpeaking {
                        self.startContinuousListening()
                    }
                }
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // Optional: Add word-by-word tracking if needed
        let spokenText = (utterance.speechString as NSString).substring(with: characterRange)
        print("🔤 Speaking: '\(spokenText)'")
    }
} 

