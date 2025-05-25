import Foundation
import AVFoundation

// 闹钟声音管理类 - 负责播放闹钟声音并实现渐增音量效果
class SoundManager: ObservableObject {
    // 单例模式
    static let shared = SoundManager()
    
    // 可用的闹钟声音选项
    let availableSounds = [
        "Rain": "rain",
        "Ring": "ring",
        "Nature": "nature"
    ]
    
    // 当前活跃的音频播放器
    private var audioPlayer: AVAudioPlayer?
    // 音量控制定时器
    private var volumeTimer: Timer?
    // 渐增音量的步骤数
    private let fadeInSteps = 20
    // 当前音量步骤
    private var currentVolumeStep = 0
    // 最大音量
    private let maxVolume: Float = 1.0
    // 当前播放的声音文件名
    @Published var currentSoundName: String?
    // 是否正在循环播放
    private var isLooping: Bool = false
    // 是否正在预览播放
    @Published var isPreviewPlaying: Bool = false
    
    private init() {
        // 音频会话设置
        setupAudioSession()
    }
    
    // 设置音频会话
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("设置音频会话失败: \(error.localizedDescription)")
        }
    }
    
    // 播放指定的声音文件并实现渐增音量
    func playSound(_ soundName: String, withFadeIn: Bool = true) {
        // 如果同一个声音已经在播放，则暂停
        if isPreviewPlaying && currentSoundName == soundName {
            pauseSound()
            return
        }
        
        // 停止当前正在播放的所有声音
        stopSound()
        
        currentSoundName = soundName
        isLooping = false
        isPreviewPlaying = true
        
        // 从Bundle中查找声音文件
        guard let soundURL = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            print("找不到声音文件: \(soundName)")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.delegate = nil
            audioPlayer?.prepareToPlay()
            
            if withFadeIn {
                // 设置初始音量为0并开始渐增
                audioPlayer?.volume = 0.0
                audioPlayer?.play()
                currentVolumeStep = 0
                
                // 创建定时器，逐步增加音量
                volumeTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] timer in
                    guard let self = self, let player = self.audioPlayer else {
                        timer.invalidate()
                        return
                    }
                    
                    self.currentVolumeStep += 1
                    let newVolume = Float(self.currentVolumeStep) / Float(self.fadeInSteps) * self.maxVolume
                    player.volume = newVolume
                    
                    // 达到最大音量后停止定时器
                    if self.currentVolumeStep >= self.fadeInSteps {
                        timer.invalidate()
                    }
                }
            } else {
                // 不需要渐增，直接全音量播放
                audioPlayer?.volume = maxVolume
                audioPlayer?.play()
            }
        } catch {
            print("播放声音时出错: \(error.localizedDescription)")
        }
    }
    
    // 暂停当前声音播放
    func pauseSound() {
        if let player = audioPlayer, player.isPlaying {
            player.pause()
            isPreviewPlaying = false
            // 暂停时不清除currentSoundName，以便可以稍后恢复
        }
    }
    
    // 恢复播放
    func resumeSound() {
        if let player = audioPlayer, !player.isPlaying {
            player.play()
            isPreviewPlaying = true
        }
    }
    
    // 切换播放/暂停状态
    func togglePlayPause(_ soundName: String) {
        if isPreviewPlaying && currentSoundName == soundName {
            pauseSound()
        } else if currentSoundName == soundName {
            resumeSound()
        } else {
            playSound(soundName)
        }
    }
    
    // 停止当前播放的声音
    func stopSound() {
        volumeTimer?.invalidate()
        volumeTimer = nil
        
        if let player = audioPlayer, player.isPlaying {
            player.stop()
        }
        audioPlayer = nil
        isLooping = false
        currentSoundName = nil
        isPreviewPlaying = false
    }
    
    // 循环播放指定的声音
    func loopSound(_ soundName: String, withFadeIn: Bool = true) {
        stopSound()
        
        currentSoundName = soundName
        isLooping = true
        isPreviewPlaying = false  // 闹钟播放不算预览
        
        guard let soundURL = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            print("找不到声音文件: \(soundName)")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            // 设置无限循环播放
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.delegate = nil
            audioPlayer?.prepareToPlay()
            
            // 启用音频会话中断后自动恢复播放
            setupAudioInterruptionNotification()
            
            if withFadeIn {
                // 设置初始音量为0并开始渐增
                audioPlayer?.volume = 0.0
                audioPlayer?.play()
                currentVolumeStep = 0
                
                // 创建定时器，逐步增加音量
                volumeTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] timer in
                    guard let self = self, let player = self.audioPlayer else {
                        timer.invalidate()
                        return
                    }
                    
                    self.currentVolumeStep += 1
                    let newVolume = Float(self.currentVolumeStep) / Float(self.fadeInSteps) * self.maxVolume
                    player.volume = newVolume
                    
                    // 达到最大音量后停止定时器
                    if self.currentVolumeStep >= self.fadeInSteps {
                        timer.invalidate()
                    }
                }
            } else {
                // 不需要渐增，直接全音量播放
                audioPlayer?.volume = maxVolume
                audioPlayer?.play()
            }
        } catch {
            print("循环播放声音时出错: \(error.localizedDescription)")
        }
    }
    
    // 设置音频会话中断通知，以便在中断后恢复播放
    private func setupAudioInterruptionNotification() {
        NotificationCenter.default.addObserver(self, 
                                              selector: #selector(handleAudioInterruption),
                                              name: AVAudioSession.interruptionNotification,
                                              object: nil)
    }
    
    // 处理音频中断
    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeInt = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeInt) else {
            return
        }
        
        switch type {
        case .began:
            // 中断开始，音频已暂停
            print("音频播放被中断")
        case .ended:
            // 中断结束，检查是否应该恢复播放
            if let optionsInt = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsInt).contains(.shouldResume) {
                // 如果是循环播放模式，则恢复播放
                if isLooping, let soundName = currentSoundName {
                    print("恢复循环播放")
                    loopSound(soundName, withFadeIn: false)
                }
            }
        @unknown default:
            break
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 
 