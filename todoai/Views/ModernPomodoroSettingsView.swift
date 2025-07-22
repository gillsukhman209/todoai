import SwiftUI

struct ModernPomodoroSettingsView: View {
    @ObservedObject var manager: PomodoroManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var workMinutes: Double
    @State private var shortBreakMinutes: Double
    @State private var longBreakMinutes: Double
    @State private var sessionsUntilLongBreak: Double
    
    init(manager: PomodoroManager) {
        self.manager = manager
        self._workMinutes = State(initialValue: manager.settings.workDuration / 60)
        self._shortBreakMinutes = State(initialValue: manager.settings.shortBreakDuration / 60)
        self._longBreakMinutes = State(initialValue: manager.settings.longBreakDuration / 60)
        self._sessionsUntilLongBreak = State(initialValue: Double(manager.settings.sessionsUntilLongBreak))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Settings")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Save") {
                    saveSettings()
                    dismiss()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.blue)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.black.opacity(0.9))
            
            ScrollView {
                VStack(spacing: 32) {
                    // Timer Durations Section
                    VStack(alignment: .leading, spacing: 20) {
                        sectionHeader("Timer Durations", icon: "timer")
                        
                        VStack(spacing: 16) {
                            modernSlider(
                                title: "Work Session",
                                value: $workMinutes,
                                range: 10...60,
                                step: 5,
                                color: .red,
                                icon: "brain.head.profile"
                            )
                            
                            modernSlider(
                                title: "Short Break",
                                value: $shortBreakMinutes,
                                range: 3...15,
                                step: 1,
                                color: .green,
                                icon: "cup.and.saucer.fill"
                            )
                            
                            modernSlider(
                                title: "Long Break",
                                value: $longBreakMinutes,
                                range: 15...45,
                                step: 5,
                                color: .purple,
                                icon: "bed.double.fill"
                            )
                        }
                    }
                    
                    // Break Configuration Section
                    VStack(alignment: .leading, spacing: 20) {
                        sectionHeader("Break Configuration", icon: "arrow.clockwise")
                        
                        modernSlider(
                            title: "Sessions until long break",
                            value: $sessionsUntilLongBreak,
                            range: 2...8,
                            step: 1,
                            color: .blue,
                            icon: "repeat"
                        )
                    }
                    
                    // Automation Section
                    VStack(alignment: .leading, spacing: 20) {
                        sectionHeader("Automation", icon: "bolt.fill")
                        
                        VStack(spacing: 12) {
                            modernToggle(
                                title: "Auto-start breaks",
                                subtitle: "Automatically start breaks after work sessions",
                                isOn: $manager.settings.autoStartBreaks,
                                color: .green
                            )
                            
                            modernToggle(
                                title: "Auto-start next session",
                                subtitle: "Continue with work after break ends",
                                isOn: $manager.settings.autoStartNextSession,
                                color: .blue
                            )
                        }
                    }
                    
                    // Notifications Section
                    VStack(alignment: .leading, spacing: 20) {
                        sectionHeader("Notifications", icon: "bell.fill")
                        
                        VStack(spacing: 12) {
                            modernToggle(
                                title: "Enable notifications",
                                subtitle: "Get alerts when sessions complete",
                                isOn: $manager.settings.enableNotifications,
                                color: .orange
                            )
                            
                            modernToggle(
                                title: "Enable sounds",
                                subtitle: "Play sound with notifications",
                                isOn: $manager.settings.enableSounds,
                                color: .pink
                            )
                            .disabled(!manager.settings.enableNotifications)
                            .opacity(manager.settings.enableNotifications ? 1.0 : 0.5)
                        }
                    }
                    
                    // Quick Presets Section
                    VStack(alignment: .leading, spacing: 20) {
                        sectionHeader("Quick Presets", icon: "bolt.horizontal.fill")
                        
                        VStack(spacing: 12) {
                            presetCard(
                                name: "Classic Pomodoro",
                                description: "25/5/15 minutes",
                                work: 25,
                                shortBreak: 5,
                                longBreak: 15
                            )
                            
                            presetCard(
                                name: "Extended Focus",
                                description: "45/10/30 minutes",
                                work: 45,
                                shortBreak: 10,
                                longBreak: 30
                            )
                            
                            presetCard(
                                name: "Quick Sessions",
                                description: "15/3/10 minutes",
                                work: 15,
                                shortBreak: 3,
                                longBreak: 10
                            )
                        }
                    }
                    
                    // Reset Section
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Reset", icon: "arrow.counterclockwise")
                        
                        Button {
                            resetToDefaults()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Reset to Defaults")
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.red.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(.black)
        .frame(width: 480, height: 600)
    }
    
    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func modernSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        color: Color,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(value.wrappedValue)) min")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            Slider(value: value, in: range, step: step)
                .tint(color)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.04))
                        .frame(height: 8)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private func modernToggle(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        color: Color
    ) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .toggleStyle(ModernToggleStyle(color: color))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private func presetCard(name: String, description: String, work: Double, shortBreak: Double, longBreak: Double) -> some View {
        Button {
            applyPreset(work: work, shortBreak: shortBreak, longBreak: longBreak)
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func applyPreset(work: Double, shortBreak: Double, longBreak: Double) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            workMinutes = work
            shortBreakMinutes = shortBreak
            longBreakMinutes = longBreak
        }
    }
    
    private func resetToDefaults() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            workMinutes = 25
            shortBreakMinutes = 5
            longBreakMinutes = 15
            sessionsUntilLongBreak = 4
            manager.settings.autoStartBreaks = false
            manager.settings.autoStartNextSession = false
            manager.settings.enableNotifications = true
            manager.settings.enableSounds = true
        }
    }
    
    private func saveSettings() {
        manager.updateWorkDuration(workMinutes * 60)
        manager.updateShortBreakDuration(shortBreakMinutes * 60)
        manager.updateLongBreakDuration(longBreakMinutes * 60)
        manager.settings.sessionsUntilLongBreak = Int(sessionsUntilLongBreak)
    }
}

// Custom toggle style for modern look
struct ModernToggleStyle: ToggleStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            Button {
                configuration.isOn.toggle()
            } label: {
                RoundedRectangle(cornerRadius: 16)
                    .fill(configuration.isOn ? color : .white.opacity(0.2))
                    .frame(width: 48, height: 28)
                    .overlay(
                        Circle()
                            .fill(.white)
                            .frame(width: 24, height: 24)
                            .offset(x: configuration.isOn ? 10 : -10)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ModernPomodoroSettingsView(manager: PomodoroManager())
}