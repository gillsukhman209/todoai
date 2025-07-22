import SwiftUI
import AppKit

struct PomodoroWindowView: View {
    @StateObject private var pomodoroManager = PomodoroManager()
    @Environment(\.modelContext) private var modelContext
    @State private var window: NSWindow?
    
    var body: some View {
        VStack(spacing: 0) {
            // Minimal modern header
            HStack {
                Text("Pomodoro")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    window?.close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .background(.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // Compact modern timer display
            VStack(spacing: 24) {
                // Compact progress ring with glow
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 3)
                        .frame(width: 180, height: 180)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.02))
                                .frame(width: 180, height: 180)
                        )
                    
                    Circle()
                        .trim(from: 0, to: pomodoroManager.progress)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(pomodoroManager.sessionTypeColor),
                                    Color(pomodoroManager.sessionTypeColor).opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: pomodoroManager.progress)
                        .shadow(color: Color(pomodoroManager.sessionTypeColor).opacity(0.4), radius: 8, x: 0, y: 0)
                    
                    VStack(spacing: 6) {
                        if let session = pomodoroManager.currentSession {
                            Text(session.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        
                        Text(pomodoroManager.formattedTimeRemaining)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                        
                        if pomodoroManager.isActive {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(pomodoroManager.state == .paused ? .orange : .green)
                                    .frame(width: 4, height: 4)
                                    .scaleEffect(pomodoroManager.state == .paused ? 1.0 : 1.3)
                                    .animation(.easeInOut(duration: 1).repeatForever(), value: pomodoroManager.state == .running)
                                
                                Text(pomodoroManager.state == .paused ? "Paused" : "Running")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                }
                
                // Compact modern controls
                if pomodoroManager.isActive {
                    compactActiveControls
                } else {
                    compactInactiveControls
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(.black)
        .onAppear {
            pomodoroManager.setModelContext(modelContext)
            setupWindow()
        }
        .background(WindowAccessor(window: $window))
    }
    
    @ViewBuilder
    private var compactActiveControls: some View {
        HStack(spacing: 12) {
            Button {
                if pomodoroManager.state == .running {
                    pomodoroManager.pauseSession()
                } else {
                    pomodoroManager.resumeSession()
                }
            } label: {
                Image(systemName: pomodoroManager.state == .running ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(.blue.opacity(0.9))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            Button {
                pomodoroManager.stopSession()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(.red.opacity(0.9))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var compactInactiveControls: some View {
        VStack(spacing: 16) {
            // Quick session buttons
            HStack(spacing: 8) {
                compactQuickButton("Work", type: .work, color: .red)
                compactQuickButton("Break", type: .shortBreak, color: .green)
                compactQuickButton("Long", type: .longBreak, color: .purple)
            }
            
            Button("Start Focus Session") {
                pomodoroManager.startSession(name: "Focus Session", type: .work)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.red.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .buttonStyle(.plain)
        }
    }
    
    private func compactQuickButton(_ title: String, type: PomodoroType, color: Color) -> some View {
        Button {
            pomodoroManager.startSession(name: title + " Session", type: type)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(color.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func setupWindow() {
        DispatchQueue.main.async {
            if let window = window {
                // Configure modern window properties
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.styleMask.remove(.resizable)
                window.setContentSize(NSSize(width: 320, height: 380))
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
    PomodoroWindowView()
}