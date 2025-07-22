import SwiftUI
import AppKit

struct PomodoroView: View {
    @StateObject private var pomodoroManager = PomodoroManager()
    @State private var sessionName = ""
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isNameFieldFocused: Bool
    @State private var animationTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var glowIntensity: Double = 0.5
    @State private var particleOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Futuristic animated background
            futuristicBackground
            
            VStack(spacing: 0) {
                // Modern header with futuristic styling
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text("Pomodoro")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.cyan, .blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            // Animated status indicator
                            if pomodoroManager.isActive {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(glowIntensity)
                                    .shadow(color: .green, radius: 6)
                            }
                        }
                        
                        if pomodoroManager.completedSessions > 0 {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 6, height: 6)
                                    .shadow(color: .green, radius: 3)
                                Text("\(pomodoroManager.completedSessions) sessions completed today")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        pomodoroManager.showSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.cyan)
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(.cyan.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .shadow(color: .cyan.opacity(0.3), radius: 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .padding(.bottom, 32)
                
                // Futuristic timer section
                VStack(spacing: 36) {
                    // Enhanced circular progress with multiple layers and effects
                    ZStack {
                        futuristicProgressRings
                        futuristicCenterContent
                    }
                    
                    // Enhanced controls with futuristic styling
                    if pomodoroManager.isActive {
                        futuristicActiveControls
                    } else {
                        futuristicInactiveControls
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer(minLength: 20)
                
                // Enhanced quick actions
                if !pomodoroManager.isActive {
                    futuristicQuickActionSection
                        .padding(.bottom, 120)
                }
            }
        }
        .onAppear {
            pomodoroManager.setModelContext(modelContext)
        }
        .onReceive(animationTimer) { _ in
            withAnimation(.easeInOut(duration: 1)) {
                glowIntensity = Double.random(in: 0.7...1.3)
                particleOffset += 1
            }
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
    private var futuristicProgressRings: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .stroke(
                    Color(pomodoroManager.sessionTypeColor).opacity(0.1),
                    lineWidth: 20
                )
                .frame(width: 340, height: 340)
                .blur(radius: 10)
            
            // Background ring with subtle animation
            Circle()
                .stroke(
                    backgroundRingGradient,
                    lineWidth: 4
                )
                .frame(width: 320, height: 320)
                .rotationEffect(.degrees(particleOffset))
            
            // Main progress ring
            mainProgressRing
            
            // Inner highlight ring
            innerHighlightRing
        }
    }
    
    @ViewBuilder
    private var futuristicCenterContent: some View {
        VStack(spacing: 16) {
            if let session = pomodoroManager.currentSession {
                sessionNameText(session.name)
            }
            
            timeDisplayText
            
            if pomodoroManager.isActive {
                activeSessionStatus
            }
        }
    }
    
    @ViewBuilder
    private var mainProgressRing: some View {
        Circle()
            .trim(from: 0, to: pomodoroManager.progress)
            .stroke(
                progressRingGradient,
                style: StrokeStyle(lineWidth: 6, lineCap: .round)
            )
            .frame(width: 320, height: 320)
            .rotationEffect(.degrees(-90))
            .animation(.spring(response: 0.8, dampingFraction: 0.7), value: pomodoroManager.progress)
            .shadow(color: Color(pomodoroManager.sessionTypeColor), radius: 15)
            .shadow(color: .cyan.opacity(0.5), radius: 25)
    }
    
    @ViewBuilder
    private var innerHighlightRing: some View {
        Circle()
            .trim(from: 0, to: pomodoroManager.progress * 0.7)
            .stroke(
                .white.opacity(0.4),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            .frame(width: 280, height: 280)
            .rotationEffect(.degrees(-90))
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: pomodoroManager.progress)
    }
    
    private func sessionNameText(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(sessionNameGradient)
            .multilineTextAlignment(.center)
            .lineLimit(2)
    }
    
    @ViewBuilder
    private var timeDisplayText: some View {
        Text(pomodoroManager.formattedTimeRemaining)
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .foregroundStyle(timeDisplayGradient)
            .contentTransition(.numericText())
            .shadow(color: Color(pomodoroManager.sessionTypeColor), radius: 20)
            .shadow(color: .white.opacity(0.5), radius: 10)
    }
    
    @ViewBuilder
    private var activeSessionStatus: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                statusIndicator
                statusText
            }
            
            if let session = pomodoroManager.currentSession {
                nextSessionIndicator(for: session)
            }
        }
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(pomodoroManager.state == PomodoroState.paused ? .orange : .green)
                .frame(width: 8, height: 8)
                .scaleEffect(glowIntensity)
                .shadow(
                    color: pomodoroManager.state == PomodoroState.paused ? .orange : .green,
                    radius: 8
                )
            
            Circle()
                .stroke(
                    (pomodoroManager.state == PomodoroState.paused ? Color.orange : Color.green).opacity(0.3),
                    lineWidth: 1
                )
                .frame(width: 20, height: 20)
                .scaleEffect(glowIntensity * 1.5)
        }
    }
    
    @ViewBuilder
    private var statusText: some View {
        Text(pomodoroManager.state == PomodoroState.paused ? "Paused" : "Running")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white.opacity(0.9))
    }
    
    private func nextSessionIndicator(for session: PomodoroSession) -> some View {
        Text(nextSessionText(for: session))
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(nextSessionGradient)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(nextSessionBackground)
    }
    
    @ViewBuilder
    private var futuristicBackground: some View {
        ZStack {
            // Base black background
            Color.black
                .ignoresSafeArea()
            
            // Animated gradient overlay
            LinearGradient(
                colors: [
                    .black,
                    .purple.opacity(0.1),
                    .cyan.opacity(0.05),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            floatingParticles
        }
    }
    
    @ViewBuilder
    private var floatingParticles: some View {
        ForEach(0..<15, id: \.self) { i in
            Circle()
                .fill(particleGradient)
                .frame(width: CGFloat.random(in: 2...8), height: CGFloat.random(in: 2...8))
                .position(
                    x: CGFloat.random(in: 0...1000),
                    y: CGFloat.random(in: 0...800) + particleOffset
                )
                .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: particleOffset)
        }
    }
    
    // Computed gradients to simplify complex expressions
    private var backgroundRingGradient: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(0.1), .white.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var progressRingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(pomodoroManager.sessionTypeColor),
                Color(pomodoroManager.sessionTypeColor).opacity(0.8),
                .cyan,
                .purple
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var sessionNameGradient: LinearGradient {
        LinearGradient(
            colors: [.white, .cyan.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var timeDisplayGradient: LinearGradient {
        LinearGradient(
            colors: [
                .white,
                Color(pomodoroManager.sessionTypeColor),
                .cyan
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var nextSessionGradient: LinearGradient {
        LinearGradient(
            colors: [.cyan, .blue],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var nextSessionBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.cyan.opacity(0.3), lineWidth: 1)
            )
    }
    
    private var particleGradient: LinearGradient {
        LinearGradient(
            colors: [.cyan.opacity(0.3), .purple.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    @ViewBuilder
    private var futuristicActiveControls: some View {
        HStack(spacing: 20) {
            // Enhanced pause/resume button
            pauseResumeButton
            
            // Enhanced stop button
            stopButton
            
            // Enhanced menu button
            moreActionsMenu
        }
    }
    
    @ViewBuilder
    private var futuristicInactiveControls: some View {
        VStack(spacing: 28) {
            // Enhanced input field
            VStack(alignment: .leading, spacing: 12) {
                futuristicTextField
            }
            .padding(.horizontal, 8)
            
            // Enhanced start button
            startFocusButton
        }
    }
    
    @ViewBuilder
    private var futuristicTextField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.cyan)
                Text("What are you working on?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.9), .cyan.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            
            focusSessionTextField
        }
    }
    
    @ViewBuilder
    private var futuristicQuickActionSection: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.cyan)
                Text("Quick Start")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .cyan.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Spacer()
            }
            .padding(.horizontal, 32)
            
            HStack(spacing: 16) {
                futuristicQuickActionCard(
                    title: "Quick Focus",
                    subtitle: "15 minutes",
                    icon: "timer",
                    colors: [.orange, .red],
                    duration: 15 * 60
                )
                
                futuristicQuickActionCard(
                    title: "Standard Focus",
                    subtitle: "25 minutes",
                    icon: "brain.head.profile",
                    colors: [.red, .purple],
                    duration: 25 * 60
                )
                
                futuristicQuickActionCard(
                    title: "Deep Focus",
                    subtitle: "45 minutes",
                    icon: "target",
                    colors: [.purple, .cyan],
                    duration: 45 * 60
                )
            }
            .padding(.horizontal, 32)
        }
    }
    
    private func futuristicQuickActionCard(title: String, subtitle: String, icon: String, colors: [Color], duration: TimeInterval) -> some View {
        Button {
            let name = sessionName.isEmpty ? title : sessionName
            pomodoroManager.startCustomSession(name: name, duration: duration)
            isNameFieldFocused = false
        } label: {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: colors.first?.opacity(0.5) ?? .clear, radius: 8)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: colors.map { $0.opacity(0.3) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(color: colors.first?.opacity(0.2) ?? .clear, radius: 15)
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
        pomodoroManager.startSession(name: name, type: PomodoroType.work)
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
    
    @ViewBuilder
    private var startFocusButton: some View {
        Button {
            startFocusSession()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
                Text("Start Focus Session")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(startButtonGradient)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .red.opacity(0.4), radius: 20)
            .shadow(color: .purple.opacity(0.3), radius: 30)
        }
        .buttonStyle(.plain)
        .disabled(sessionName.isEmpty)
        .opacity(sessionName.isEmpty ? 0.6 : 1.0)
    }
    
    @ViewBuilder
    private var focusSessionTextField: some View {
        TextField("Focus session name", text: $sessionName)
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(textFieldBackground)
            .focused($isNameFieldFocused)
            .textFieldStyle(.plain)
            .shadow(
                color: isNameFieldFocused ? .cyan.opacity(0.3) : .clear,
                radius: 10
            )
            .animation(.easeInOut(duration: 0.3), value: isNameFieldFocused)
            .onSubmit {
                startFocusSession()
            }
    }
    
    @ViewBuilder
    private var pauseResumeButton: some View {
        Button {
            if pomodoroManager.state == PomodoroState.running {
                pomodoroManager.pauseSession()
            } else {
                pomodoroManager.resumeSession()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: pomodoroManager.state == PomodoroState.running ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(pomodoroManager.state == PomodoroState.running ? "Pause" : "Resume")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(height: 50)
            .frame(minWidth: 130)
            .background(pauseResumeGradient)
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .blue.opacity(0.5), radius: 15)
            .shadow(color: .cyan.opacity(0.3), radius: 25)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var stopButton: some View {
        Button {
            pomodoroManager.stopSession()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Stop")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(height: 50)
            .frame(minWidth: 110)
            .background(stopButtonGradient)
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .red.opacity(0.5), radius: 15)
            .shadow(color: .orange.opacity(0.3), radius: 25)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var moreActionsMenu: some View {
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
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.cyan)
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(.cyan.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .cyan.opacity(0.3), radius: 10)
        }
        .menuStyle(.borderlessButton)
    }
    
    private var startButtonGradient: LinearGradient {
        LinearGradient(
            colors: [.red, .purple, .cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var textFieldBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        textFieldBorderGradient,
                        lineWidth: 1.5
                    )
            )
    }
    
    private var textFieldBorderGradient: LinearGradient {
        LinearGradient(
            colors: isNameFieldFocused ? 
            [.cyan.opacity(0.6), .purple.opacity(0.4)] :
            [.white.opacity(0.1), .white.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var pauseResumeGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var stopButtonGradient: LinearGradient {
        LinearGradient(
            colors: [.red, .orange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    PomodoroView()
}