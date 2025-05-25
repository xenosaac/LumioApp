# Dream Tracker - Voice-Based AI Conversation Feature

## Overview

The Dream Tracker feature enables users to have natural voice conversations with an AI assistant to record and analyze their dreams. The AI guides users through thoughtful questions to help them explore and understand their dream experiences.

## Features

### 🎙️ Voice Conversation
- **Speech Recognition**: Real-time speech-to-text conversion
- **Text-to-Speech**: AI responses are spoken aloud
- **Natural Flow**: Conversational interface that feels like talking to a therapist
- **Real-time Transcript**: See the conversation as it happens

### 🤖 AI-Powered Analysis
- **Guided Questions**: AI asks thoughtful follow-up questions
- **Dream Analysis**: Automatic mood detection and element extraction
- **Personalized Responses**: Context-aware conversation flow
- **Session Management**: Automatic conversation length management

### 📱 User Interface
- **Chat Interface**: WhatsApp-style message bubbles
- **Status Indicators**: Visual feedback for conversation state
- **Voice Controls**: Large, intuitive voice recording button
- **Session History**: Browse and review past dream conversations

### 📊 Dream Analytics
- **Mood Classification**: Pleasant, Anxious, Nightmare, Lucid, etc.
- **Element Tagging**: Automatic extraction of dream symbols and themes
- **Session Metrics**: Duration, message count, and timestamps
- **Data Persistence**: All conversations saved locally

## Setup Instructions

### 1. OpenAI API Configuration

The dream tracker requires an OpenAI API key to function:

1. **Get API Key**:
   - Visit [OpenAI Platform](https://platform.openai.com/api-keys)
   - Create a new API key
   - Copy the key securely

2. **Configure App**:
   - Open `RA/Config.swift` in Xcode
   - Replace `"YOUR_OPENAI_API_KEY_HERE"` with your actual API key
   - Rebuild the app

3. **Verify Setup**:
   - Open Dream Tracker → Settings
   - Check that API Status shows "✅ Configured"

### 2. Permissions

The app requires the following permissions:

- **Microphone Access**: For voice recording
- **Speech Recognition**: For transcribing speech to text

These permissions are requested automatically when you first use the voice features.

## Usage Guide

### Starting a Conversation

1. **Open Dream Tracker**: Tap the "Dream Tracker" tab
2. **Start Session**: Tap "Start Conversation"
3. **Listen to AI**: The AI will greet you and ask about your night
4. **Respond**: Tap the microphone button and speak your response
5. **Continue**: The AI will ask follow-up questions to explore your dream

### Voice Controls

- **🎤 Blue Button**: Tap to start recording your voice
- **🛑 Red Button**: Tap to stop recording (while recording)
- **Automatic Stop**: Recording stops automatically when you finish speaking

### Conversation Flow

The AI follows a structured approach:

1. **Opening**: "How was your night? Did you have any dreams?"
2. **Exploration**: Questions about dream content, emotions, and details
3. **Analysis**: Questions about symbols, people, and connections
4. **Closure**: Summary and final thoughts

### Viewing History

1. **History Tab**: Switch to the "History" tab
2. **Browse Sessions**: See all past dream conversations
3. **View Details**: Tap any session to see the full transcript
4. **Session Info**: View duration, mood, and extracted elements

## Technical Architecture

### Core Components

```
RA/
├── Models/
│   └── DreamConversation.swift     # Data models for conversations
├── Managers/
│   └── DreamConversationManager.swift  # Core conversation logic
├── Views/
│   └── DreamTrackerView.swift     # UI components
└── Config.swift                   # Configuration settings
```

### Key Classes

#### `DreamConversationManager`
- Manages speech recognition and synthesis
- Handles OpenAI API communication
- Coordinates conversation flow
- Persists session data

#### `ConversationMessage`
- Represents individual messages in the conversation
- Tracks sender (AI vs User) and timestamp
- Supports real-time typing indicators

#### `DreamSession`
- Complete conversation session data
- Includes analysis results (mood, tags)
- Provides duration and summary information

### Data Flow

1. **User Speech** → Speech Recognition → Text
2. **Text** → OpenAI API → AI Response
3. **AI Response** → Text-to-Speech → Audio
4. **Session Data** → Local Storage → UserDefaults

## Configuration Options

### `Config.swift` Settings

```swift
// OpenAI Configuration
static let openAIAPIKey = "your-api-key"
static let openAIModel = "gpt-3.5-turbo"
static let maxTokens = 100
static let temperature = 0.7

// Conversation Settings
static let maxConversationSteps = 10
static let speechRate: Float = 0.5
static let speechVolume: Float = 0.8

// Audio Settings
static let audioBufferSize: AVAudioFrameCount = 1024
static let speechRecognitionLocale = "en-US"
```

## Privacy & Security

### Data Storage
- **Local Only**: All conversations stored locally on device
- **No Cloud Sync**: Data never leaves your device (except API calls)
- **User Control**: Users can delete all data anytime

### API Communication
- **Secure HTTPS**: All API calls use encrypted connections
- **Minimal Data**: Only conversation context sent to OpenAI
- **No Personal Info**: No device or user identification sent

### Permissions
- **Microphone**: Only used during active recording
- **Speech Recognition**: Only processes speech during conversations
- **No Background Access**: No data collection when app is closed

## Troubleshooting

### Common Issues

#### "Speech recognition not available"
- **Solution**: Check device language settings
- **Requirement**: iOS device with speech recognition support

#### "OpenAI API key not configured"
- **Solution**: Follow setup instructions to configure API key
- **Check**: Verify key is correctly set in `Config.swift`

#### "Failed to generate AI response"
- **Causes**: Network connection, API quota, invalid key
- **Solution**: Check internet connection and API key validity

#### Permission Denied
- **Solution**: Go to Settings → Privacy → Microphone/Speech Recognition
- **Enable**: Allow access for the RA app

### Performance Tips

- **Stable Internet**: Ensure good internet connection for AI responses
- **Quiet Environment**: Use in quiet spaces for better speech recognition
- **Clear Speech**: Speak clearly and at normal pace
- **Wait for AI**: Let AI finish speaking before responding

## API Costs

### OpenAI Pricing (as of 2024)
- **GPT-3.5-turbo**: ~$0.002 per 1K tokens
- **Typical Session**: 5-10 minutes ≈ $0.01-0.05
- **Monthly Usage**: 10 sessions ≈ $0.10-0.50

### Cost Management
- **Short Responses**: AI responses limited to 50 words
- **Session Limits**: Conversations auto-end after 10 exchanges
- **Local Storage**: No ongoing costs for stored conversations

## Future Enhancements

### Planned Features
- **Dream Pattern Analysis**: Long-term trend analysis
- **Custom AI Personalities**: Different conversation styles
- **Export Options**: Share or export dream journals
- **Offline Mode**: Basic functionality without internet
- **Multi-language Support**: Support for other languages

### Technical Improvements
- **Background Processing**: Continue conversations in background
- **Voice Activity Detection**: Automatic start/stop recording
- **Noise Cancellation**: Better audio processing
- **Conversation Branching**: More dynamic conversation flows

## Support

For technical issues or questions:

1. **Check Settings**: Verify API configuration and permissions
2. **Review Logs**: Check Xcode console for error messages
3. **Test Components**: Try individual features (speech, TTS, API)
4. **Reset Data**: Clear all sessions if experiencing data issues

---

*Last Updated: December 2024*
*Version: 1.0* 
 