import SwiftUI
import AppKit

struct PomodoroView: View {
    @StateObject private var pomodoroManager = PomodoroManager()
    @State private var sessionName = ""
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern header with minimal design
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pomodoro")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if pomodoroManager.completedSessions > 0 {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text("\(pomodoroManager.completedSessions) sessions completed today")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    pomodoroManager.showSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 32)
            
            // Modern timer section
            VStack(spacing: 36) {
                // Circular progress with modern styling
                ZStack {
                    // Background ring with subtle glow
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 3)
                        .frame(width: 300, height: 300)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.02))
                                .frame(width: 300, height: 300)
                        )
                    
                    // Progress ring with gradient and glow
                    Circle()
                        .trim(from: 0, to: pomodoroManager.progress)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(pomodoroManager.sessionTypeColor),
                                    Color(pomodoroManager.sessionTypeColor).opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 300, height: 300)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: pomodoroManager.progress)
                        .shadow(color: Color(pomodoroManager.sessionTypeColor).opacity(0.5), radius: 12, x: 0, y: 0)
                    
                    // Central content with modern typography
                    VStack(spacing: 12) {
                        if let session = pomodoroManager.currentSession {
                            Text(session.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        
                        Text(pomodoroManager.formattedTimeRemaining)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                        
                        if pomodoroManager.isActive {
                            VStack(spacing: 4) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(pomodoroManager.state == .paused ? .orange : .green)
                                        .frame(width: 6, height: 6)
                                        .scaleEffect(pomodoroManager.state == .paused ? 1.0 : 1.2)
                                        .animation(.easeInOut(duration: 1).repeatForever(), value: pomodoroManager.state == .running)
                                    
                                    Text(pomodoroManager.state == .paused ? "Paused" : "Running")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                // Show what's next
                                if let session = pomodoroManager.currentSession {
                                    Text(nextSessionText(for: session))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                }
                
                // Modern controls
                if pomodoroManager.isActive {
                    activeControls
                } else {
                    inactiveControls
                }
            }
            .padding(.horizontal, 32)
            
            Spacer(minLength: 20)
            
            // Quick actions with modern cards - moved up more from bottom
            if !pomodoroManager.isActive {
                quickActionSection
                    .padding(.bottom, 120) // Much more bottom padding to clear todo input area
            }
        }
        .background(.black)
        .onAppear {
            pomodoroManager.setModelContext(modelContext)
        }
        .sheet(isPresented: $pomodoroManager.showSettings) {
            ModernPomodoroSettingsView(manager: pomodoroManager)
        }
        .onChange(of: pomodoroManager.showPopup) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    pomodoroManager.showPopup = false
                }
            }
        }
        .overlay {
            if pomodoroManager.showPopup {
                PomodoroPopupNotification(manager: pomodoroManager)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: pomodoroManager.showPopup)
            }
        }
    }
    
    @ViewBuilder
    private var activeControls: some View {
        HStack(spacing: 16) {
            // Modern pause/resume button
            Button {
                if pomodoroManager.state == .running {
                    pomodoroManager.pauseSession()
                } else {
                    pomodoroManager.resumeSession()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: pomodoroManager.state == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(pomodoroManager.state == .running ? "Pause" : "Resume")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(height: 44)
                .frame(minWidth: 120)
                .background(.blue.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Modern stop button
            Button {
                pomodoroManager.stopSession()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Stop")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(height: 44)
                .frame(minWidth: 100)
                .background(.red.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.red.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Modern menu button
            Menu {
                Button("Restart Session") {
                    pomodoroManager.restartSession()
                }
                Button("Open in Window") {
                    openPomodoroWindow()
                }
                Divider()
                Button("Delete Session", role: .destructive) {
                    pomodoroManager.deleteSession()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .menuStyle(.borderlessButton)
        }
    }
    
    @ViewBuilder
    private var inactiveControls: some View {
        VStack(spacing: 24) {
            // Modern borderless input field - simplified
            VStack(alignment: .leading, spacing: 12) {
                modernTextField
            }
            .padding(.horizontal, 8)
            
            // Modern start button - always starts work session
            Button {
                startFocusSession()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Start Focus Session")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(height: 52)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color.red, Color.red.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Color.red.opacity(0.3), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(sessionName.isEmpty)
            .opacity(sessionName.isEmpty ? 0.5 : 1.0)
        }
    }
    
    @ViewBuilder
    private var modernTextField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Text("What are you working on?")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Completely borderless input with clean background
            TextField("Focus session name", text: $sessionName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.white.opacity(isNameFieldFocused ? 0.08 : 0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .focused($isNameFieldFocused)
                .textFieldStyle(.plain)
                .onSubmit {
                    startFocusSession()
                }
        }
    }
    
    @ViewBuilder
    private var quickActionSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Text("Quick Start")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 32)
            
            HStack(spacing: 12) {
                quickActionCard(
                    title: "Quick Focus",
                    subtitle: "15 minutes",
                    icon: "timer",
                    color: .orange,
                    duration: 15 * 60
                )
                
                quickActionCard(
                    title: "Standard Focus",
                    subtitle: "25 minutes",
                    icon: "brain.head.profile",
                    color: .red,
                    duration: 25 * 60
                )
                
                quickActionCard(
                    title: "Deep Focus",
                    subtitle: "45 minutes",
                    icon: "target",
                    color: .purple,
                    duration: 45 * 60
                )
            }
            .padding(.horizontal, 32)
        }
    }
    
    private func quickActionCard(title: String, subtitle: String, icon: String, color: Color, duration: TimeInterval) -> some View {
        Button {
            let name = sessionName.isEmpty ? title : sessionName
            pomodoroManager.startCustomSession(name: name, duration: duration)
            isNameFieldFocused = false
        } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func nextSessionText(for session: PomodoroSession) -> String {
        switch session.pomodoroType {
        case .work:
            let breakDuration = (pomodoroManager.completedSessions + 1) % pomodoroManager.settings.sessionsUntilLongBreak == 0 ? 
                Int(pomodoroManager.settings.longBreakDuration / 60) : 
                Int(pomodoroManager.settings.shortBreakDuration / 60)
            return "Next: \(breakDuration) min break"
        case .shortBreak:
            return "Next: Work session"
        case .longBreak:
            return "Next: Work session"
        }
    }
    
    private func startFocusSession() {
        let name = sessionName.isEmpty ? "Focus Session" : sessionName
        pomodoroManager.startSession(name: name, type: .work)
        isNameFieldFocused = false
    }
    
    private func openPomodoroWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 350),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Pomodoro Timer"
        window.contentView = NSHostingView(rootView: PomodoroWindowView().environment(\.modelContext, modelContext))
        window.center()
        window.orderFront(nil)
        window.makeKey()
    }
}

#Preview {
    PomodoroView()
}