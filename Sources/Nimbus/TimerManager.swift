import Foundation
import Combine
import AppKit
import UserNotifications

enum PomodoroStage: String {
    case work = "Work Session"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    
    var defaultDuration: TimeInterval {
        switch self {
        case .work: return 25 * 60 // 25 mins
        case .shortBreak: return 5 * 60 // 5 mins
        case .longBreak: return 15 * 60 // 15 mins
        }
    }
}

class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    @Published var isActive: Bool = false
    @Published var timeRemaining: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isPaused: Bool = false
    
    // Pomodoro extensions
    @Published var isPomodoroMode: Bool = false
    @Published var pomodoroStage: PomodoroStage = .work
    @Published var pomodoroCyclesCompleted: Int = 0
    
    private var timer: Timer?
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return Double(timeRemaining) / Double(duration)
    }
    
    var timeFormatted: String {
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private init() {
        requestNotificationPermission()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            // Handle outcome silently or print for debugging
        }
    }
    
    func start(seconds: TimeInterval) {
        self.duration = seconds
        self.timeRemaining = seconds
        self.isActive = true
        self.isPaused = false
        self.isPomodoroMode = false
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        
        AppState.shared.objectWillChange.send()
    }
    
    func startPomodoro() {
        self.isPomodoroMode = true
        self.pomodoroStage = .work
        self.duration = pomodoroStage.defaultDuration
        self.timeRemaining = duration
        self.isActive = true
        self.isPaused = false
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        
        AppState.shared.objectWillChange.send()
    }
    
    func pause() {
        isPaused = true
        timer?.invalidate()
    }
    
    func resume() {
        isPaused = false
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func reset() {
        isActive = false
        isPaused = false
        isPomodoroMode = false
        timeRemaining = 0
        duration = 0
        timer?.invalidate()
        
        AppState.shared.objectWillChange.send()
    }
    
    private func tick() {
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            if isPomodoroMode {
                transitionPomodoro()
            } else {
                triggerAlert(title: "Timer Finished", subtitle: "Your Dynamic Island timer has completed.")
                reset()
            }
        }
    }
    
    private func transitionPomodoro() {
        NSSound.beep()
        
        switch pomodoroStage {
        case .work:
            pomodoroCyclesCompleted += 1
            triggerAlert(title: "Pomodoro Session Completed!", subtitle: "Time for a well-deserved break.")
            if pomodoroCyclesCompleted % 4 == 0 {
                pomodoroStage = .longBreak
            } else {
                pomodoroStage = .shortBreak
            }
        case .shortBreak, .longBreak:
            triggerAlert(title: "Break Over!", subtitle: "Let's get back to focus.")
            pomodoroStage = .work
        }
        
        // Start next phase automatically
        self.duration = pomodoroStage.defaultDuration
        self.timeRemaining = duration
        
        AppState.shared.objectWillChange.send()
    }
    
    private func triggerAlert(title: String, subtitle: String) {
        NSSound.beep()
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = subtitle
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
