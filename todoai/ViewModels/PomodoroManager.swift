import Foundation
import SwiftData
import Combine

@MainActor
class PomodoroManager: ObservableObject {
    @Published var currentSession: PomodoroSession?
    @Published var state: PomodoroState = .stopped
    @Published var settings: PomodoroSettings
    @Published var completedSessions: Int = 0
    @Published var currentTime: Date = Date()
    @Published var showPopup: Bool = false
    @Published var showSettings: Bool = false
    
    private var modelContext: ModelContext?
    private var timer: Timer?
    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()
    private let notificationService = NotificationService.shared
    
    init(settings: PomodoroSettings = PomodoroSettings()) {
        self.settings = settings
        startClockTimer()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadSettings()
    }
    
    private func startClockTimer() {
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] time in
                self?.currentTime = time
                self?.updateCurrentSession()
            }
            .store(in: &cancellables)
    }
    
    private func loadSettings() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<PomodoroSettings>()
        if let existingSettings = try? context.fetch(descriptor).first {
            self.settings = existingSettings
        } else {
            let newSettings = PomodoroSettings()
            context.insert(newSettings)
            self.settings = newSettings
            try? context.save()
        }
    }
    
    private func saveSettings() {
        guard let context = modelContext else { return }
        try? context.save()
    }
    
    func startSession(name: String = "Focus Session", type: PomodoroType = .work) {
        let duration = settings.duration(for: type)
        let session = PomodoroSession(name: name, totalDuration: duration, type: type)
        
        currentSession = session
        state = .running
        startTime = Date()
        pausedDuration = 0
        showPopup = true
        
        modelContext?.insert(session)
        try? modelContext?.save()
        
        // Schedule notification
        NotificationCenter.default.post(
            name: NSNotification.Name("PomodoroSessionStarted"),
            object: session
        )
        
        // Schedule completion notification if enabled
        if settings.enableNotifications {
            let completionDate = Date().addingTimeInterval(duration)
            Task {
                do {
                    try await notificationService.schedulePomodoroCompletionNotification(
                        sessionName: session.name,
                        completionDate: completionDate,
                        sessionId: session.id,
                        isWorkSession: session.pomodoroType == .work
                    )
                } catch {
                    print("Failed to schedule Pomodoro completion notification: \(error)")
                }
            }
        }
    }
    
    func startCustomSession(name: String, duration: TimeInterval) {
        let session = PomodoroSession(name: name, totalDuration: duration, type: .work)
        
        currentSession = session
        state = .running
        startTime = Date()
        pausedDuration = 0
        showPopup = true
        
        modelContext?.insert(session)
        try? modelContext?.save()
        
        // Schedule notification
        NotificationCenter.default.post(
            name: NSNotification.Name("PomodoroSessionStarted"),
            object: session
        )
        
        // Schedule completion notification if enabled
        if settings.enableNotifications {
            let completionDate = Date().addingTimeInterval(duration)
            Task {
                do {
                    try await notificationService.schedulePomodoroCompletionNotification(
                        sessionName: session.name,
                        completionDate: completionDate,
                        sessionId: session.id,
                        isWorkSession: true
                    )
                } catch {
                    print("Failed to schedule Pomodoro completion notification: \(error)")
                }
            }
        }
    }
    
    func pauseSession() {
        guard let session = currentSession, state == .running else { return }
        
        state = .paused
        if let start = startTime {
            pausedDuration += Date().timeIntervalSince(start)
        }
        
        NotificationCenter.default.post(
            name: NSNotification.Name("PomodoroSessionPaused"),
            object: session
        )
    }
    
    func resumeSession() {
        guard currentSession != nil, state == .paused else { return }
        
        state = .running
        startTime = Date()
        
        NotificationCenter.default.post(
            name: NSNotification.Name("PomodoroSessionResumed"),
            object: currentSession
        )
    }
    
    func stopSession() {
        guard let session = currentSession else { return }
        
        // Cancel any scheduled notifications
        notificationService.cancelPomodoroNotifications(sessionId: session.id)
        
        // Mark as completed if finished
        if session.progress >= 1.0 {
            session.isCompleted = true
            session.endTime = Date()
            completedSessions += 1
            
            // Auto-start break if enabled
            if settings.autoStartBreaks && session.pomodoroType == .work {
                let breakType: PomodoroType = (completedSessions % settings.sessionsUntilLongBreak == 0) ? .longBreak : .shortBreak
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.startSession(name: "Break Time", type: breakType)
                }
            }
        }
        
        resetTimer()
        try? modelContext?.save()
        
        NotificationCenter.default.post(
            name: NSNotification.Name("PomodoroSessionStopped"),
            object: session
        )
    }
    
    func deleteSession() {
        guard let session = currentSession else { return }
        
        // Cancel any scheduled notifications
        notificationService.cancelPomodoroNotifications(sessionId: session.id)
        
        modelContext?.delete(session)
        resetTimer()
        try? modelContext?.save()
    }
    
    func restartSession() {
        guard let session = currentSession else { return }
        
        session.completedDuration = 0
        pausedDuration = 0
        startTime = Date()
        state = .running
        
        try? modelContext?.save()
    }
    
    private func resetTimer() {
        currentSession = nil
        state = .stopped
        startTime = nil
        pausedDuration = 0
    }
    
    private func updateCurrentSession() {
        guard let session = currentSession,
              let start = startTime,
              state == .running else { return }
        
        let elapsed = Date().timeIntervalSince(start) + pausedDuration
        session.completedDuration = min(elapsed, session.totalDuration)
        
        // Check if session is complete
        if session.completedDuration >= session.totalDuration {
            completeSession()
        }
    }
    
    private func completeSession() {
        guard let session = currentSession else { return }
        
        session.isCompleted = true
        session.endTime = Date()
        completedSessions += 1
        
        state = .stopped
        showPopup = true
        
        try? modelContext?.save()
        
        NotificationCenter.default.post(
            name: NSNotification.Name("PomodoroSessionCompleted"),
            object: session
        )
        
        // Send completion notification if enabled
        if settings.enableNotifications {
            Task {
                let title = session.pomodoroType == .work ? "Work Session Complete!" : "Break Complete!"
                let body = session.pomodoroType == .work ? 
                    "Great job on '\(session.name)'! Time for a break." :
                    "Break's over! Ready to get back to work?"
                
                do {
                    try await notificationService.sendPomodoroNotification(
                        title: title,
                        body: body,
                        sessionId: session.id,
                        isWorkSession: session.pomodoroType == .work
                    )
                } catch {
                    print("Failed to send Pomodoro notification: \(error)")
                }
            }
        }
        
        // Auto-start next session if enabled
        if settings.autoStartNextSession {
            if session.pomodoroType == .work {
                let breakType: PomodoroType = (completedSessions % settings.sessionsUntilLongBreak == 0) ? .longBreak : .shortBreak
                startSession(name: "Break Time", type: breakType)
            } else if settings.autoStartNextSession {
                startSession(name: "Focus Session", type: .work)
            }
        }
    }
    
    // Settings management
    func updateWorkDuration(_ duration: TimeInterval) {
        settings.workDuration = duration
        saveSettings()
    }
    
    func updateShortBreakDuration(_ duration: TimeInterval) {
        settings.shortBreakDuration = duration
        saveSettings()
    }
    
    func updateLongBreakDuration(_ duration: TimeInterval) {
        settings.longBreakDuration = duration
        saveSettings()
    }
    
    // Helper computed properties
    var isActive: Bool {
        state == .running || state == .paused
    }
    
    var progress: Double {
        currentSession?.progress ?? 0
    }
    
    var timeRemaining: TimeInterval {
        currentSession?.remainingDuration ?? 0
    }
    
    var formattedTimeRemaining: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var sessionTypeColor: String {
        guard let session = currentSession else { return "blue" }
        
        switch session.pomodoroType {
        case .work:
            return "red"
        case .shortBreak:
            return "green"
        case .longBreak:
            return "purple"
        }
    }
}