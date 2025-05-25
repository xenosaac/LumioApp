//import SwiftUI
//
//struct DreamTrackerView: View {
//    var body: some View {
//        NavigationView {
//            VStack {
//                Text("Under Construction")
//                    .font(.largeTitle)
//                    .fontWeight(.bold)
//                    .foregroundColor(.gray)
//                
//                Spacer().frame(height: 20)
//                
//                Image(systemName: "hammer.fill")
//                    .font(.system(size: 60))
//                    .foregroundColor(.gray)
//                    .padding()
//            }
//        }
//    }
//}
//
//struct DreamTrackerView_Previews: PreviewProvider {
//    static var previews: some View {
//        DreamTrackerView()
//    }
//}

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
    @State private var searchText = ""
    @State private var selectedMoodFilter: DreamMood? = nil
    
    var filteredSessions: [DreamSession] {
        let sessions = dreamManager.dreamSessions.sorted(by: { $0.startTime > $1.startTime })
        
        var filtered = sessions
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { session in
                // Search in title, summary, tags, or message content
                let searchableContent = [
                    session.title ?? "",
                    session.dreamSummary ?? "",
                    session.tags.joined(separator: " "),
                    session.messages.map { $0.content }.joined(separator: " ")
                ].joined(separator: " ").lowercased()
                
                return searchableContent.contains(searchText.lowercased())
            }
        }
        
        // Filter by mood
        if let selectedMood = selectedMoodFilter {
            filtered = filtered.filter { $0.mood == selectedMood }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if dreamManager.dreamSessions.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "moon.stars")
                            .font(.system(size: 80))
                            .foregroundColor(.blue.opacity(0.6))
                        
                        VStack(spacing: 8) {
                            Text("Your Dream Journey Awaits")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Start your first conversation to begin tracking your dreams and building your personal dream journal")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        VStack(spacing: 12) {
                            HStack(spacing: 16) {
                                FeatureHighlight(
                                    icon: "brain.head.profile",
                                    title: "AI Analysis",
                                    description: "Get insights into your dreams"
                                )
                                
                                FeatureHighlight(
                                    icon: "heart.fill",
                                    title: "Mood Tracking",
                                    description: "Track emotional patterns"
                                )
                            }
                            
                            HStack(spacing: 16) {
                                FeatureHighlight(
                                    icon: "tag.fill",
                                    title: "Dream Elements",
                                    description: "Discover recurring symbols"
                                )
                                
                                FeatureHighlight(
                                    icon: "clock.fill",
                                    title: "Journey History",
                                    description: "Review past dreams"
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    // Search and filter section
                    VStack(spacing: 12) {
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Search dreams...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Mood filter
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // All filter
                                Button(action: { selectedMoodFilter = nil }) {
                                    Text("All")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedMoodFilter == nil ? Color.blue : Color(.systemGray5))
                                        .foregroundColor(selectedMoodFilter == nil ? .white : .primary)
                                        .cornerRadius(16)
                                }
                                
                                // Mood filters
                                ForEach(DreamMood.allCases, id: \.self) { mood in
                                    Button(action: { 
                                        selectedMoodFilter = selectedMoodFilter == mood ? nil : mood 
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(mood.emoji)
                                                .font(.caption)
                                            
                                            Text(mood.rawValue)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedMoodFilter == mood ? moodColor(for: mood) : Color(.systemGray5))
                                        .foregroundColor(selectedMoodFilter == mood ? .white : .primary)
                                        .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    
                    // Dream sessions list
                    if filteredSessions.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("No dreams found")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text("Try adjusting your search or filters")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredSessions) { session in
                                    DreamSessionRow(session: session)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }
                        .background(Color(.systemGroupedBackground))
                    }
                }
            }
            .navigationTitle("Dream Journey")
            .toolbar {
                if !dreamManager.dreamSessions.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: { 
                                searchText = ""
                                selectedMoodFilter = nil
                            }) {
                                Label("Clear Filters", systemImage: "clear")
                            }
                            
                            Button(role: .destructive, action: {
                                dreamManager.clearAllSessions()
                            }) {
                                Label("Clear All Dreams", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }
    
    private func moodColor(for mood: DreamMood) -> Color {
        switch mood {
        case .pleasant: return .green
        case .anxious: return .orange
        case .nightmare: return .red
        case .lucid: return .purple
        case .vivid: return .blue
        case .peaceful: return .mint
        case .neutral: return .gray
        }
    }
}

// MARK: - Feature Highlight

struct FeatureHighlight: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Dream Session Row

struct DreamSessionRow: View {
    let session: DreamSession
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with title and mood
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Dream Title (prominent)
                        if let title = session.title, !title.isEmpty {
                            if title == "Generating title..." {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Generating AI title...")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                }
                            } else {
                                Text(title)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                        } else {
                            Text("Untitled Dream")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                        
                        // Date and time as subtitle
                        HStack {
                            Text(session.startTime, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(session.startTime, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(session.formattedDuration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Mood indicator
                    if let mood = session.mood {
                        VStack(spacing: 2) {
                            Text(mood.emoji)
                                .font(.title2)
                            Text(mood.rawValue)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(mood.color).opacity(0.2))
                        )
                    }
                }
                
                // AI Summary preview (if available)
                if let summary = session.dreamSummary, !summary.isEmpty && summary != "No dream content recorded" {
                    if summary == "Generating AI analysis..." {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("AI is analyzing your dream...")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .italic()
                        }
                    } else {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                // Keywords/Tags
                if !session.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(session.tags.prefix(4)), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.orange.opacity(0.2))
                                    )
                                    .foregroundColor(.orange)
                            }
                            
                            if session.tags.count > 4 {
                                Text("+\(session.tags.count - 4)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
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
    @EnvironmentObject var dreamManager: DreamConversationManager
    
    @State private var isEditingTitle = false
    @State private var isEditingSummary = false
    @State private var isEditingMood = false
    @State private var isEditingKeywords = false
    
    @State private var editedTitle = ""
    @State private var editedSummary = ""
    @State private var editedMood: DreamMood?
    @State private var editedKeywords = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Dream Title (editable)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if isEditingTitle {
                                TextField("Dream title", text: $editedTitle)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button("Save") {
                                    dreamManager.updateSessionTitle(session.id, newTitle: editedTitle)
                                    isEditingTitle = false
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                
                                Button("Cancel") {
                                    editedTitle = session.title ?? ""
                                    isEditingTitle = false
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    if let title = session.title, !title.isEmpty && title != "Generating title..." {
                                        Text(title)
                                            .font(.largeTitle)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                    } else {
                                        Text("Untitled Dream")
                                            .font(.largeTitle)
                                            .fontWeight(.bold)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    editedTitle = session.title ?? ""
                                    isEditingTitle = true
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        
                        // Date and time as subtitle
                        HStack {
                            Text(session.startTime, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(session.startTime, style: .time)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // AI Dream Summary (editable)
                    if let summary = session.dreamSummary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(.purple)
                                    .font(.title2)
                                Text("AI Dream Analysis")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                if !isEditingSummary && summary != "Generating AI analysis..." {
                                    Button(action: {
                                        editedSummary = summary
                                        isEditingSummary = true
                                    }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.purple)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            
                            if isEditingSummary {
                                VStack(spacing: 8) {
                                    TextEditor(text: $editedSummary)
                                        .frame(minHeight: 100)
                                        .padding(8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                        )
                                    
                                    HStack {
                                        Button("Save") {
                                            dreamManager.updateSessionSummary(session.id, newSummary: editedSummary)
                                            isEditingSummary = false
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        
                                        Button("Cancel") {
                                            editedSummary = summary
                                            isEditingSummary = false
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        
                                        Spacer()
                                    }
                                }
                            } else {
                                Text(summary)
                                    .font(.body)
                                    .lineSpacing(4)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.purple.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Basic Information Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Dream Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            // Mood (editable)
                            VStack(spacing: 8) {
                                HStack {
                                    if let mood = session.mood {
                                        Text(mood.emoji)
                                            .font(.title2)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Mood")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(mood.rawValue)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        }
                                    } else {
                                        Image(systemName: "heart")
                                            .foregroundColor(.gray)
                                            .font(.title2)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Mood")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("Not set")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        editedMood = session.mood
                                        isEditingMood = true
                                    }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill((session.mood != nil ? Color(session.mood!.color) : Color.gray).opacity(0.1))
                                )
                                
                                if isEditingMood {
                                    VStack(spacing: 8) {
                                        Text("Select Mood:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                            ForEach(DreamMood.allCases, id: \.self) { mood in
                                                Button(action: {
                                                    editedMood = mood
                                                }) {
                                                    VStack(spacing: 4) {
                                                        Text(mood.emoji)
                                                            .font(.title2)
                                                        Text(mood.rawValue)
                                                            .font(.caption)
                                                            .fontWeight(.medium)
                                                    }
                                                    .padding(8)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(editedMood == mood ? Color(mood.color).opacity(0.3) : Color.gray.opacity(0.1))
                                                    )
                                                    .foregroundColor(editedMood == mood ? Color(mood.color) : .primary)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                        
                                        HStack {
                                            Button("Save") {
                                                dreamManager.updateSessionMood(session.id, newMood: editedMood)
                                                isEditingMood = false
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.small)
                                            
                                            Button("Cancel") {
                                                editedMood = session.mood
                                                isEditingMood = false
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            
                                            Spacer()
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.05))
                                    )
                                }
                            }
                            
                            // Duration
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Duration")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(session.formattedDuration)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.1))
                            )
                            
                            // AI Keywords/Tags (editable)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "tag")
                                        .foregroundColor(.orange)
                                    Text("Dream Keywords")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if !isEditingKeywords {
                                        Button(action: {
                                            editedKeywords = session.tags.joined(separator: ", ")
                                            isEditingKeywords = true
                                        }) {
                                            Image(systemName: "pencil")
                                                .foregroundColor(.orange)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                                
                                if isEditingKeywords {
                                    VStack(spacing: 8) {
                                        TextField("Enter keywords separated by commas", text: $editedKeywords)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                        
                                        Text("Tip: Separate keywords with commas (e.g., flying, water, family)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        
                                        HStack {
                                            Button("Save") {
                                                let newTags = editedKeywords
                                                    .components(separatedBy: ",")
                                                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).capitalized }
                                                    .filter { !$0.isEmpty }
                                                dreamManager.updateSessionTags(session.id, newTags: newTags)
                                                isEditingKeywords = false
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.small)
                                            
                                            Button("Cancel") {
                                                editedKeywords = session.tags.joined(separator: ", ")
                                                isEditingKeywords = false
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            
                                            Spacer()
                                        }
                                    }
                                } else if !session.tags.isEmpty {
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                        ForEach(session.tags, id: \.self) { tag in
                                            Text(tag)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.orange.opacity(0.2))
                                                )
                                                .foregroundColor(.orange)
                                        }
                                    }
                                } else {
                                    Text("No keywords yet")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .italic()
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.orange.opacity(0.05))
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Conversation Transcript (at the bottom)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Conversation Transcript")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(session.messages) { message in
                                HStack(alignment: .top, spacing: 12) {
                                    // Avatar
                                    Circle()
                                        .fill(message.isFromAI ? Color.blue : Color.green)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Image(systemName: message.isFromAI ? "brain" : "person")
                                                .foregroundColor(.white)
                                                .font(.caption)
                                        )
                                    
                                    // Message content
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(message.isFromAI ? "AI Dream Guide" : "You")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(message.isFromAI ? .blue : .green)
                                            
                                            Spacer()
                                            
                                            Text(message.timestamp, style: .time)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Text(message.content)
                                            .font(.body)
                                            .lineSpacing(2)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(message.isFromAI ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                                    )
                                    
                                    if !message.isFromAI {
                                        Spacer(minLength: 40)
                                    }
                                }
                                .padding(.horizontal)
                                .if(message.isFromAI) { view in
                                    HStack {
                                        view
                                        Spacer(minLength: 40)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Share functionality could be added here
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .onAppear {
            editedTitle = session.title ?? ""
            editedSummary = session.dreamSummary ?? ""
            editedMood = session.mood
            editedKeywords = session.tags.joined(separator: ", ")
        }
    }
}

// Helper extension for conditional view modifiers
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
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
