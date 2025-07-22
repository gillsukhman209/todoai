import SwiftUI

struct PomodoroSettingsView: View {
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
        NavigationView {
            Form {
                // Timer Durations
                Section("Timer Durations") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.red)
                            Text("Work Session")
                            Spacer()
                            Text("\(Int(workMinutes)) min")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $workMinutes, in: 10...60, step: 5)
                            .tint(.red)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill")
                                .foregroundColor(.green)
                            Text("Short Break")
                            Spacer()
                            Text("\(Int(shortBreakMinutes)) min")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $shortBreakMinutes, in: 3...15, step: 1)
                            .tint(.green)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "bed.double.fill")
                                .foregroundColor(.purple)
                            Text("Long Break")
                            Spacer()
                            Text("\(Int(longBreakMinutes)) min")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $longBreakMinutes, in: 15...45, step: 5)
                            .tint(.purple)
                    }
                    .padding(.vertical, 4)
                }
                
                // Break Configuration
                Section("Break Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "repeat")
                                .foregroundColor(.blue)
                            Text("Sessions until long break")
                            Spacer()
                            Text("\(Int(sessionsUntilLongBreak))")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $sessionsUntilLongBreak, in: 2...8, step: 1)
                            .tint(.blue)
                    }
                    .padding(.vertical, 4)
                }
                
                // Automation Settings
                Section("Automation") {
                    Toggle(isOn: $manager.settings.autoStartBreaks) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.green)
                            Text("Auto-start breaks")
                        }
                    }
                    
                    Toggle(isOn: $manager.settings.autoStartNextSession) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                            Text("Auto-start next session")
                        }
                    }
                }
                
                // Notification Settings
                Section("Notifications") {
                    Toggle(isOn: $manager.settings.enableNotifications) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.orange)
                            Text("Enable notifications")
                        }
                    }
                    
                    Toggle(isOn: $manager.settings.enableSounds) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.pink)
                            Text("Enable sounds")
                        }
                    }
                    .disabled(!manager.settings.enableNotifications)
                }
                
                // Presets
                Section("Presets") {
                    VStack(spacing: 12) {
                        presetButton(
                            name: "Classic Pomodoro",
                            description: "25/5/15 minutes",
                            work: 25,
                            shortBreak: 5,
                            longBreak: 15
                        )
                        
                        presetButton(
                            name: "Extended Focus",
                            description: "45/10/30 minutes",
                            work: 45,
                            shortBreak: 10,
                            longBreak: 30
                        )
                        
                        presetButton(
                            name: "Quick Sessions",
                            description: "15/3/10 minutes",
                            work: 15,
                            shortBreak: 3,
                            longBreak: 10
                        )
                    }
                }
                
                // Reset Section
                Section {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Pomodoro Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func presetButton(name: String, description: String, work: Double, shortBreak: Double, longBreak: Double) -> some View {
        Button {
            applyPreset(work: work, shortBreak: shortBreak, longBreak: longBreak)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    private func applyPreset(work: Double, shortBreak: Double, longBreak: Double) {
        withAnimation(.easeInOut(duration: 0.3)) {
            workMinutes = work
            shortBreakMinutes = shortBreak
            longBreakMinutes = longBreak
        }
    }
    
    private func resetToDefaults() {
        withAnimation(.easeInOut(duration: 0.3)) {
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

#Preview {
    PomodoroSettingsView(manager: PomodoroManager())
}