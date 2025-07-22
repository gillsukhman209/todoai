import Foundation
import SwiftData

enum PomodoroState: String, CaseIterable {
    case stopped = "stopped"
    case running = "running"
    case paused = "paused"
    case onBreak = "break"
}

enum PomodoroType: String, CaseIterable {
    case work = "work"
    case shortBreak = "short_break"
    case longBreak = "long_break"
}

@Model
class PomodoroSession {
    var id: UUID
    var name: String
    var startTime: Date
    var endTime: Date?
    var totalDuration: TimeInterval
    var completedDuration: TimeInterval
    var type: String
    var isCompleted: Bool
    var createdAt: Date
    
    init(name: String, totalDuration: TimeInterval, type: PomodoroType) {
        self.id = UUID()
        self.name = name
        self.startTime = Date()
        self.totalDuration = totalDuration
        self.completedDuration = 0
        self.type = type.rawValue
        self.isCompleted = false
        self.createdAt = Date()
    }
    
    var pomodoroType: PomodoroType {
        PomodoroType(rawValue: type) ?? .work
    }
    
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(completedDuration / totalDuration, 1.0)
    }
    
    var remainingDuration: TimeInterval {
        max(totalDuration - completedDuration, 0)
    }
}

@Model
class PomodoroSettings {
    var workDuration: TimeInterval = 25 * 60 // 25 minutes
    var shortBreakDuration: TimeInterval = 5 * 60 // 5 minutes
    var longBreakDuration: TimeInterval = 15 * 60 // 15 minutes
    var sessionsUntilLongBreak: Int = 4
    var enableNotifications: Bool = true
    var enableSounds: Bool = true
    var autoStartBreaks: Bool = false
    var autoStartNextSession: Bool = false
    
    init() {}
    
    func duration(for type: PomodoroType) -> TimeInterval {
        switch type {
        case .work:
            return workDuration
        case .shortBreak:
            return shortBreakDuration
        case .longBreak:
            return longBreakDuration
        }
    }
}