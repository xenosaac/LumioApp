import SwiftUI

struct DreamTrackerView: View {
    @StateObject private var dreamManager = DreamConversationManager.shared
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Main Conversation Tab
                ConversationView()
                    .tabItem {
                        Image(systemName: "message.circle")
                        Text("Chat")
                    }
                    .tag(0)
                
                // Dream History Tab
                DreamHistoryView()
                    .tabItem {
                        Image(systemName: "book.circle")
                        Text("History")
                    }
                    .tag(1)
            }
            .navigationTitle("Dream Tracker")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                DreamSettingsView()
            }
        }
        .environmentObject(dreamManager)
        .onChange(of: dreamManager.conversationState) {
            if dreamManager.conversationState == .completed {
                selectedTab = 1 // Switch to History tab
            }
        }
    }
}

// MARK: - Conversation View

struct ConversationView: View {
    @EnvironmentObject var dreamManager: DreamConversationManager
    @State private var showingPermissionAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Conversation Status Header
            ConversationStatusHeader()
            
            // Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(dreamManager.messages) { message in
                            MessageBubble(message: message)
                        }
                        
                        // Typing indicator
                        if dreamManager.conversationState == .processing {
                            TypingIndicator()
                        }
                    }
                    .padding()
                }
                .onChange(of: dreamManager.messages.count) {
                    scrollToBottom(proxy: proxy)
                }
            }
            
            Spacer()
            
            // Control Panel
            ConversationControlPanel()
        }
        .background(Color(.systemGroupedBackground))
        .alert("Permissions Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable microphone and speech recognition permissions in Settings to use voice conversations.")
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = dreamManager.messages.last {
            withAnimation(.easeInOut(duration: 0.5)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Conversation Status Header

struct ConversationStatusHeader: View {
    @EnvironmentObject var dreamManager: DreamConversationManager
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text(statusText)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let session = dreamManager.currentSession {
                    Text(session.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if dreamManager.conversationState != .idle && dreamManager.conversationState != .completed {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var statusColor: Color {
        switch dreamManager.conversationState {
        case .idle:
            return .gray
        case .listening:
            return .blue
        case .processing:
            return .orange
        case .speaking:
            return .green
        case .completed:
            return .purple
        case .error:
            return .red
        }
    }
    
    private var statusText: String {
        switch dreamManager.conversationState {
        case .idle:
            return "Ready to Chat"
        case .listening:
            return "Your Turn - Speak Now"
        case .processing:
            return "Processing Your Response..."
        case .speaking:
            return "AI's Turn - Listen"
        case .completed:
            return "Session Complete"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ConversationMessage
    
    var body: some View {
        HStack {
            if message.isFromAI {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                        Text("Dream AI")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    
                    Text(message.content)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                        .foregroundColor(.primary)
                }
                Spacer()
            } else {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Spacer()
                        Text("You")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Image(systemName: "person.circle")
                            .foregroundColor(.white)
                    }
                    
                    Text(message.content)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(16)
                        .foregroundColor(.white)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: message.id)
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.blue)
                    Text("Dream AI")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Spacer()
                }
                
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 8, height: 8)
                            .offset(y: animationOffset)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: animationOffset
                            )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
            }
            Spacer()
        }
        .onAppear {
            animationOffset = -5
        }
    }
}

// MARK: - Conversation Control Panel

struct ConversationControlPanel: View {
    @EnvironmentObject var dreamManager: DreamConversationManager
    @State private var showingManualMode = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Voice Activity Indicator
            if dreamManager.conversationState != .idle && dreamManager.conversationState != .completed {
                VoiceActivityIndicator()
            }
            
            // Current Transcript Display
            if !dreamManager.currentTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You're saying:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(dreamManager.currentTranscript)
                        .font(.body)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .transition(.opacity.combined(with: .scale))
            }
            
            // Status and Action Buttons
            HStack(spacing: 20) {
                if dreamManager.conversationState == .idle {
                    Button("Start Dream Chat") {
                        dreamManager.startConversation()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if dreamManager.conversationState != .completed {
                    Button("End Session") {
                        dreamManager.stopConversation()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .controlSize(.large)
                    
                    // Manual speak button for troubleshooting
                    if dreamManager.conversationState == .listening {
                        Button(action: {
                            showingManualMode = true
                        }) {
                            Image(systemName: "mic.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.blue)
                    }
                }
                
                if dreamManager.conversationState == .completed {
                    Button("New Session") {
                        dreamManager.conversationState = .idle
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            
            // Conversation Instructions
            if dreamManager.conversationState == .idle {
                VStack(spacing: 8) {
                    Text("Tap 'Start Dream Chat' to begin. The AI will speak first, then it's your turn to respond.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("💡 Tip: Say \"that's all I remember\" or \"I'm done\" when you've finished sharing your dream")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal)
            } else if dreamManager.conversationState == .listening {
                VStack(spacing: 4) {
                    Text("🎤 Your turn - Speak about your dreams")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                    
                    if dreamManager.audioLevel > 0.1 {
                        Text("✅ Voice detected - keep speaking!")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else {
                        Text("Speak clearly or tap the mic button if having issues")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            } else if dreamManager.conversationState == .processing {
                Text("🤔 Processing your response and preparing AI reply...")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            } else if dreamManager.conversationState == .speaking {
                Text("🗣️ AI is speaking - Listen, then you can respond when it finishes")
                    .font(.caption)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 5)
        .padding()
        .animation(.easeInOut(duration: 0.3), value: dreamManager.conversationState)
        .animation(.easeInOut(duration: 0.3), value: dreamManager.currentTranscript)
        .sheet(isPresented: $showingManualMode) {
            ManualSpeechView()
        }
    }
}

// MARK: - Voice Activity Indicator

struct VoiceActivityIndicator: View {
    @EnvironmentObject var dreamManager: DreamConversationManager
    @State private var animationScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Outer ring that pulses with voice activity
                Circle()
                    .stroke(indicatorColor.opacity(0.3), lineWidth: 4)
                    .frame(width: 100, height: 100)
                    .scaleEffect(1.0 + (CGFloat(dreamManager.audioLevel) * 0.5))
                    .animation(.easeInOut(duration: 0.1), value: dreamManager.audioLevel)
                
                // Inner circle
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 60, height: 60)
                    .scaleEffect(animationScale)
                
                // Icon
                Image(systemName: indicatorIcon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Audio level bars
            if dreamManager.conversationState == .listening {
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(dreamManager.audioLevel > Float(index) * 0.2 ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 4, height: CGFloat(8 + index * 4))
                            .animation(.easeInOut(duration: 0.1), value: dreamManager.audioLevel)
                    }
                }
            }
        }
        .onAppear {
            startAnimation()
        }
        .onChange(of: dreamManager.conversationState) { _ in
            startAnimation()
        }
    }
    
    private var indicatorColor: Color {
        switch dreamManager.conversationState {
        case .listening:
            return .blue
        case .processing:
            return .orange
        case .speaking:
            return .green
        default:
            return .gray
        }
    }
    
    private var indicatorIcon: String {
        switch dreamManager.conversationState {
        case .listening:
            return "waveform"
        case .processing:
            return "brain.head.profile"
        case .speaking:
            return "speaker.wave.2"
        default:
            return "moon.stars"
        }
    }
    
    private func startAnimation() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            animationScale = dreamManager.conversationState == .listening ? 1.1 : 1.0
        }
    }
}

// MARK: - Dream History View

struct DreamHistoryView: View {
    @EnvironmentObject var dreamManager: DreamConversationManager
    
    var body: some View {
        NavigationView {
            List {
                if dreamManager.dreamSessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "moon.stars")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                        
                        Text("No Dream Sessions Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        
                        Text("Start your first conversation to track your dreams")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(dreamManager.dreamSessions.sorted(by: { $0.startTime > $1.startTime })) { session in
                        DreamSessionRow(session: session)
                    }
                    .onDelete(perform: deleteSessions)
                }
            }
            .navigationTitle("Dream History")
            .toolbar {
                if !dreamManager.dreamSessions.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
            }
        }
    }
    
    private func deleteSessions(offsets: IndexSet) {
        let sortedSessions = dreamManager.dreamSessions.sorted(by: { $0.startTime > $1.startTime })
        for index in offsets {
            if let sessionIndex = dreamManager.dreamSessions.firstIndex(where: { $0.id == sortedSessions[index].id }) {
                dreamManager.dreamSessions.remove(at: sessionIndex)
            }
        }
        dreamManager.saveDreamSessions()
    }
}

// MARK: - Dream Session Row

struct DreamSessionRow: View {
    let session: DreamSession
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(session.startTime, style: .date)
                        .font(.headline)
                    
                    Spacer()
                    
                    if let mood = session.mood {
                        Text(mood.emoji)
                            .font(.title2)
                    }
                }
                
                if let summary = session.dreamSummary, !summary.isEmpty {
                    Text(summary)
                        .font(.body)
                        .lineLimit(2)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(session.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(session.messages.count) messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !session.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(session.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            DreamSessionDetailView(session: session)
        }
    }
}

// MARK: - Dream Session Detail View

struct DreamSessionDetailView: View {
    let session: DreamSession
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Session Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Details")
                            .font(.headline)
                        
                        HStack {
                            Text("Date:")
                                .fontWeight(.semibold)
                            Text(session.startTime, style: .date)
                        }
                        
                        HStack {
                            Text("Duration:")
                                .fontWeight(.semibold)
                            Text(session.formattedDuration)
                        }
                        
                        if let mood = session.mood {
                            HStack {
                                Text("Mood:")
                                    .fontWeight(.semibold)
                                Text("\(mood.emoji) \(mood.rawValue)")
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Tags
                    if !session.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dream Elements")
                                .font(.headline)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                ForEach(session.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Conversation Transcript
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Conversation")
                            .font(.headline)
                        
                        ForEach(session.messages) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(message.isFromAI ? "Dream AI" : "You")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(message.isFromAI ? .blue : .green)
                                    
                                    Spacer()
                                    
                                    Text(message.timestamp, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(message.content)
                                    .font(.body)
                                    .padding()
                                    .background(message.isFromAI ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Dream Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Dream Settings View

struct DreamSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dreamManager: DreamConversationManager
    @State private var showingConfigInstructions = false
    
    var body: some View {
        NavigationView {
            List {
                Section("API Configuration") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("OpenAI API Status")
                                .fontWeight(.semibold)
                            Text(AppConfig.isOpenAIConfigured ? "✅ Configured" : "❌ Not Configured")
                                .foregroundColor(AppConfig.isOpenAIConfigured ? .green : .red)
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        if !AppConfig.isOpenAIConfigured {
                            Button("Setup") {
                                showingConfigInstructions = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    if !AppConfig.isOpenAIConfigured {
                        Text("AI conversations require an OpenAI API key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Conversation Settings") {
                    HStack {
                        Text("Max Conversation Steps")
                        Spacer()
                        Text("\(AppConfig.maxConversationSteps)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Speech Rate")
                        Spacer()
                        Text(String(format: "%.1f", AppConfig.speechRate))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("AI Model")
                        Spacer()
                        Text(AppConfig.openAIModel)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Data Management") {
                    HStack {
                        Text("Dream Sessions")
                        Spacer()
                        Text("\(dreamManager.dreamSessions.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Clear All Dream Sessions") {
                        dreamManager.clearAllSessions()
                    }
                    .foregroundColor(.red)
                }
                
                Section("About") {
                    Text("Dream Tracker uses AI to help you explore and understand your dreams through natural conversation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Version 1.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingConfigInstructions) {
                ConfigurationInstructionsView()
            }
        }
    }
}

// MARK: - Configuration Instructions View

struct ConfigurationInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Setup Instructions")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("To enable AI-powered dream conversations, you need to configure an OpenAI API key.")
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        StepView(
                            number: 1,
                            title: "Get OpenAI API Key",
                            description: "Visit https://platform.openai.com/api-keys and create a new API key",
                            action: {
                                if let url = URL(string: "https://platform.openai.com/api-keys") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        )
                        
                        StepView(
                            number: 2,
                            title: "Open Config.swift",
                            description: "In Xcode, navigate to RA > Config.swift"
                        )
                        
                        StepView(
                            number: 3,
                            title: "Replace API Key",
                            description: "Replace \"YOUR_OPENAI_API_KEY_HERE\" with your actual API key"
                        )
                        
                        StepView(
                            number: 4,
                            title: "Rebuild App",
                            description: "Build and run the app again to apply changes"
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Important Notes")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("• API usage will incur charges based on OpenAI's pricing")
                        Text("• Keep your API key secure and never share it")
                        Text("• The app stores conversations locally on your device")
                        Text("• Internet connection is required for AI responses")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("API Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Step View

struct StepView: View {
    let number: Int
    let title: String
    let description: String
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
                
                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if let action = action {
                        Button("Open") {
                            action()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Manual Speech View

struct ManualSpeechView: View {
    @EnvironmentObject var dreamManager: DreamConversationManager
    @Environment(\.dismiss) private var dismiss
    @State private var isRecording = false
    @State private var recordedText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Manual Speech Input")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("If automatic detection isn't working, use this manual mode:")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Recording Button
                Button(action: {
                    if isRecording {
                        stopManualRecording()
                    } else {
                        startManualRecording()
                    }
                }) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(isRecording ? Color.red : Color.blue)
                                .frame(width: 100, height: 100)
                                .scaleEffect(isRecording ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.1), value: isRecording)
                            
                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Text(isRecording ? "Tap to Stop" : "Tap to Speak")
                            .font(.headline)
                            .foregroundColor(isRecording ? .red : .blue)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Recorded text display
                if !recordedText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recorded:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(recordedText)
                            .font(.body)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button("Send This") {
                            sendRecordedText()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Manual Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func startManualRecording() {
        isRecording = true
        recordedText = ""
        // Use the existing speech recognition but in manual mode
        dreamManager.startManualRecording { text in
            recordedText = text
            isRecording = false
        }
    }
    
    private func stopManualRecording() {
        isRecording = false
        dreamManager.stopManualRecording()
    }
    
    private func sendRecordedText() {
        if !recordedText.isEmpty {
            dreamManager.processManualInput(recordedText)
            dismiss()
        }
    }
}

// MARK: - Preview

struct DreamTrackerView_Previews: PreviewProvider {
    static var previews: some View {
        DreamTrackerView()
    }
} 
