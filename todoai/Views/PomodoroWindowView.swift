import SwiftUI
import AppKit

struct PomodoroWindowView: View {
    @ObservedObject var pomodoroManager: PomodoroManager
    @Environment(\.modelContext) private var modelContext
    @State private var window: NSWindow?
    @State private var glowIntensity: Double = 0.8
    @State private var particleOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Futuristic background
            futuristicBackground
            
            VStack(spacing: 0) {
                // Futuristic header
                HStack {
                    Text("Pomodoro")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Spacer()
                    
                    Button {
                        window?.close()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cyan)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(.cyan.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .shadow(color: .cyan.opacity(0.3), radius: 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // Futuristic compact timer
                VStack(spacing: 20) {
                    // Enhanced progress ring with multiple layers
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .stroke(
                                Color(pomodoroManager.sessionTypeColor).opacity(0.1),
                                lineWidth: 12
                            )
                            .frame(width: 200, height: 200)
                            .blur(radius: 6)
                        
                        // Background ring with subtle animation
                        Circle()
                            .stroke(
                                backgroundRingGradient,
                                lineWidth: 2
                            )
                            .frame(width: 180, height: 180)
                            .rotationEffect(.degrees(particleOffset))
                        
                        // Main progress ring
                        Circle()
                            .trim(from: 0, to: pomodoroManager.progress)
                            .stroke(
                                progressRingGradient,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 180, height: 180)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: pomodoroManager.progress)
                            .shadow(color: Color(pomodoroManager.sessionTypeColor), radius: 10)
                            .shadow(color: .cyan.opacity(0.3), radius: 15)
                        
                        // Inner highlight ring
                        Circle()
                            .trim(from: 0, to: pomodoroManager.progress * 0.7)
                            .stroke(
                                .white.opacity(0.3),
                                style: StrokeStyle(lineWidth: 1, lineCap: .round)
                            )
                            .frame(width: 160, height: 160)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.4, dampingFraction: 0.9), value: pomodoroManager.progress)
                        
                        // Center content with futuristic styling
                        VStack(spacing: 8) {
                            if let session = pomodoroManager.currentSession {
                                Text(session.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(sessionNameGradient)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            
                            // Enhanced time display
                            Text(pomodoroManager.formattedTimeRemaining)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(timeDisplayGradient)
                                .contentTransition(.numericText())
                                .shadow(color: Color(pomodoroManager.sessionTypeColor), radius: 8)
                                .shadow(color: .white.opacity(0.3), radius: 4)
                            
                            // Status indicator
                            if pomodoroManager.isActive {
                                HStack(spacing: 8) {
                                    statusIndicator
                                    statusText
                                }
                            }
                        }
                    }
                    
                    // Futuristic controls
                    if pomodoroManager.isActive {
                        futuristicActiveControls
                    } else {
                        futuristicInactiveControls
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            setupWindow()
            startAnimations()
        }
        .background(WindowAccessor(window: $window))
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
                    .purple.opacity(0.08),
                    .cyan.opacity(0.04),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Compact floating particles
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(particleGradient)
                    .frame(width: CGFloat.random(in: 1...4), height: CGFloat.random(in: 1...4))
                    .position(
                        x: CGFloat.random(in: 0...320),
                        y: CGFloat.random(in: 0...400) + particleOffset
                    )
                    .animation(.linear(duration: 15).repeatForever(autoreverses: false), value: particleOffset)
            }
        }
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(pomodoroManager.state == PomodoroState.paused ? Color.orange : Color.green)
                .frame(width: 6, height: 6)
                .scaleEffect(glowIntensity)
                .shadow(
                    color: pomodoroManager.state == PomodoroState.paused ? .orange : .green,
                    radius: 6
                )
            
            Circle()
                .stroke(
                    (pomodoroManager.state == PomodoroState.paused ? Color.orange : Color.green).opacity(0.3),
                    lineWidth: 0.5
                )
                .frame(width: 12, height: 12)
                .scaleEffect(glowIntensity * 1.3)
        }
    }
    
    @ViewBuilder
    private var statusText: some View {
        Text(pomodoroManager.state == PomodoroState.paused ? "Paused" : "Running")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
    }
    
    @ViewBuilder
    private var futuristicActiveControls: some View {
        HStack(spacing: 12) {
            // Pause/Resume button
            Button {
                if pomodoroManager.state == PomodoroState.running {
                    pomodoroManager.pauseSession()
                } else {
                    pomodoroManager.resumeSession()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: pomodoroManager.state == PomodoroState.running ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(pomodoroManager.state == PomodoroState.running ? "Pause" : "Resume")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(height: 36)
                .frame(minWidth: 80)
                .background(pauseResumeGradient)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .blue.opacity(0.4), radius: 8)
                .shadow(color: .cyan.opacity(0.2), radius: 12)
            }
            .buttonStyle(.plain)
            
            // Stop button
            Button {
                pomodoroManager.stopSession()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Stop")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(height: 36)
                .frame(minWidth: 70)
                .background(stopButtonGradient)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .red.opacity(0.4), radius: 8)
                .shadow(color: .orange.opacity(0.2), radius: 12)
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var futuristicInactiveControls: some View {
        VStack(spacing: 12) {
            // Quick start buttons
            HStack(spacing: 8) {
                compactQuickButton("15m", duration: 15 * 60, colors: [.orange, .red])
                compactQuickButton("25m", duration: 25 * 60, colors: [.red, .purple])
                compactQuickButton("45m", duration: 45 * 60, colors: [.purple, .cyan])
            }
            
            // Main start button
            Button("Start Focus Session") {
                pomodoroManager.startSession(name: "Focus Session", type: PomodoroType.work)
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .frame(height: 36)
            .frame(maxWidth: .infinity)
            .background(startButtonGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .red.opacity(0.3), radius: 10)
            .shadow(color: .purple.opacity(0.2), radius: 15)
            .buttonStyle(.plain)
        }
    }
    
    private func compactQuickButton(_ title: String, duration: TimeInterval, colors: [Color]) -> some View {
        Button {
            pomodoroManager.startCustomSession(name: "Quick Focus", duration: duration)
        } label: {
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 50, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: colors.map { $0.opacity(0.4) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: colors.first?.opacity(0.2) ?? .clear, radius: 6)
        }
        .buttonStyle(.plain)
    }
    
    // Computed gradients
    private var backgroundRingGradient: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(0.08), .white.opacity(0.04)],
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
    
    private var particleGradient: LinearGradient {
        LinearGradient(
            colors: [.cyan.opacity(0.2), .purple.opacity(0.1)],
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
    
    private var startButtonGradient: LinearGradient {
        LinearGradient(
            colors: [.red, .purple, .cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func startAnimations() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1)) {
                glowIntensity = Double.random(in: 0.6...1.2)
                particleOffset += 0.5
            }
        }
    }
    
    private func setupWindow() {
        DispatchQueue.main.async {
            if let window = window {
                // Configure modern window properties
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.styleMask.remove(.resizable)
                window.setContentSize(NSSize(width: 280, height: 360))
                window.title = "Pomodoro Timer"
                
                // Make window more modern
                window.titlebarAppearsTransparent = true
                window.isMovableByWindowBackground = true
                
                // Center the window
                if let screen = NSScreen.main {
                    let screenFrame = screen.visibleFrame
                    let windowFrame = window.frame
                    let x = screenFrame.midX - windowFrame.width / 2
                    let y = screenFrame.midY - windowFrame.height / 2
                    window.setFrameOrigin(NSPoint(x: x, y: y))
                }
            }
        }
    }
}

// Helper to access the NSWindow
struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

#Preview {
    PomodoroWindowView(pomodoroManager: PomodoroManager())
}