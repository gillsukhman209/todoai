import SwiftUI

struct PomodoroPopupNotification: View {
    @ObservedObject var manager: PomodoroManager
    @State private var animationScale: CGFloat = 0.8
    @State private var animationOpacity: Double = 0
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(Color(manager.sessionTypeColor))
                        .background(
                            Circle()
                                .fill(Color(manager.sessionTypeColor).opacity(0.1))
                                .frame(width: 36, height: 36)
                        )
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notificationTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(notificationMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Quick action buttons
                    if manager.state == .stopped && manager.currentSession?.isCompleted == true {
                        HStack(spacing: 8) {
                            Button("Break") {
                                startBreak()
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Button("Work") {
                                startWork()
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Close button
                    Button {
                        dismissNotification()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(4)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(manager.sessionTypeColor).opacity(0.2), lineWidth: 1)
                )
                .scaleEffect(animationScale)
                .opacity(animationOpacity)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                animationScale = 1.0
                animationOpacity = 1.0
            }
            
            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                if manager.showPopup {
                    dismissNotification()
                }
            }
        }
        .onTapGesture {
            dismissNotification()
        }
    }
    
    private var iconName: String {
        if let session = manager.currentSession {
            if session.isCompleted {
                return "checkmark.circle.fill"
            }
            
            switch manager.state {
            case .running:
                return "play.circle.fill"
            case .paused:
                return "pause.circle.fill"
            default:
                return "timer"
            }
        }
        return "timer"
    }
    
    private var notificationTitle: String {
        guard let session = manager.currentSession else {
            return "Pomodoro Timer"
        }
        
        if session.isCompleted {
            switch session.pomodoroType {
            case .work:
                return "Work Session Complete!"
            case .shortBreak:
                return "Break Complete!"
            case .longBreak:
                return "Long Break Complete!"
            }
        }
        
        switch manager.state {
        case .running:
            return "Session Started"
        case .paused:
            return "Session Paused"
        case .stopped:
            return "Session Stopped"
        default:
            return "Pomodoro"
        }
    }
    
    private var notificationMessage: String {
        guard let session = manager.currentSession else {
            return "Ready to start a new session"
        }
        
        if session.isCompleted {
            switch session.pomodoroType {
            case .work:
                return "Great job! Time for a break."
            case .shortBreak:
                return "Break's over! Ready to work?"
            case .longBreak:
                return "Refreshed and ready to go!"
            }
        }
        
        switch manager.state {
        case .running:
            return "\(session.name) • \(manager.formattedTimeRemaining) remaining"
        case .paused:
            return "\(session.name) • \(manager.formattedTimeRemaining) remaining"
        case .stopped:
            return session.name
        default:
            return session.name
        }
    }
    
    private func dismissNotification() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            animationScale = 0.8
            animationOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            manager.showPopup = false
        }
    }
    
    private func startBreak() {
        let breakType: PomodoroType = (manager.completedSessions % manager.settings.sessionsUntilLongBreak == 0) ? .longBreak : .shortBreak
        manager.startSession(name: "Break Time", type: breakType)
        dismissNotification()
    }
    
    private func startWork() {
        manager.startSession(name: "Focus Session", type: .work)
        dismissNotification()
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        PomodoroPopupNotification(manager: {
            let manager = PomodoroManager()
            manager.showPopup = true
            return manager
        }())
    }
}