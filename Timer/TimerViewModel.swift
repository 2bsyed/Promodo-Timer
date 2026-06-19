import Foundation
import Combine
import AVFoundation

class TimerViewModel: ObservableObject {
    @Published var remainingTime: Int
    @Published var timerDuration: Double
    @Published var timerState: TimerState = .stopped
    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?

    init(duration: Double) {
        self.remainingTime = Int(duration * 60)
        self.timerDuration = duration
        prepareAlarmSound()
    }

    var displayTime: Double {
        get {
            if timerState == .stopped {
                return timerDuration
            } else {
                return Double(remainingTime) / 60.0
            }
        }
        set {
            timerDuration = newValue
            resetTimer()
        }
    }

    func toggleTimer() {
        switch timerState {
        case .running:
            pauseTimer()
        case .paused:
            resumeTimer()
        case .stopped:
            startTimer()
        }
    }

    func startTimer() {
        timer?.invalidate()
        timerState = .running
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.remainingTime > 0 {
                self.remainingTime -= 1
            } else {
                TimerHistoryManager.shared.recordSession(durationMinutes: self.timerDuration)
                self.resetTimer()
                self.playAlarmSound()
            }
        }
    }

    func pauseTimer() {
        timer?.invalidate()
        timerState = .paused
    }

    func resumeTimer() {
        timerState = .running
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.remainingTime > 0 {
                self.remainingTime -= 1
            } else {
                TimerHistoryManager.shared.recordSession(durationMinutes: self.timerDuration)
                self.resetTimer()
                self.playAlarmSound()
            }
        }
    }

    func resetTimer() {
        timerState = .stopped
        timer?.invalidate()
        updateRemainingTime()
    }

    func setPresetTimer(minutes: Int) {
        timer?.invalidate()
        timerState = .stopped
        timerDuration = Double(minutes)
        updateRemainingTime()
    }

    func updateRemainingTime() {
        remainingTime = Int(timerDuration * 60)
    }

    func timeString(from seconds: Int) -> String {
        if seconds >= 3600 {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            let secs = seconds % 60
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            let minutes = seconds / 60
            let secs = seconds % 60
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    private func prepareAlarmSound() {
        if let soundURL = Bundle.main.url(forResource: "alarm", withExtension: "mp3") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.prepareToPlay()
            } catch {
                print("Failed to initialize audio player: \(error)")
            }
        }
    }

    func playAlarmSound() {
        audioPlayer?.play()
    }
}

