//
//  SchedulingView.swift
//  todoai
//
//  Created by AI Assistant on 1/4/25.
//

import SwiftUI
import SwiftData

// MARK: - RecurrencePattern enum for UI
enum RecurrencePattern: String, CaseIterable {
    case once = "once"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    case weekdays = "weekdays"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .once: return "Once"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .weekdays: return "Weekdays"
        case .custom: return "Custom"
        }
    }
    
    var toEnhancedRecurrenceType: EnhancedRecurrenceType {
        switch self {
        case .once: return .once
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .yearly: return .yearly
        case .weekdays: return .weekdays
        case .custom: return .custom
        }
    }
}

struct SchedulingView: View {
    let todo: Todo
    let onScheduled: () -> Void
    
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var selectedPriority: TaskPriority = .medium
    @State private var selectedType: TaskType = .reminder
    @State private var recurrencePattern: RecurrencePattern = .once
    @State private var showRecurrenceOptions = false
    @State private var isScheduling = false
    @State private var showingPermissionAlert = false
    @State private var scheduleSuccess = false
    @State private var errorMessage: String?
    
    @ObservedObject private var notificationService = NotificationService.shared
    @ObservedObject private var taskScheduler = TaskScheduler.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schedule Reminder")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.primaryText)
                    
                    Text(todo.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.secondaryText)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Button(action: {
                    onScheduled() // This will dismiss the view
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.secondaryText)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Permission warning if needed
                    permissionView
                    
                    // Error message if any
                    if let errorMessage = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.red.opacity(0.1))
                        )
                    }
                    
                    // Date & Time Section
                    sectionCard("Date & Time", systemImage: "calendar") {
                        VStack(spacing: 16) {
                            HStack {
                                Label("Date", systemImage: "calendar")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color.primaryText)
                                
                                Spacer()
                                
                                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(CompactDatePickerStyle())
                            }
                            
                            HStack {
                                Label("Time", systemImage: "clock")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color.primaryText)
                                
                                Spacer()
                                
                                DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(CompactDatePickerStyle())
                            }
                            
                            // Optional recurrence toggle
                            VStack(spacing: 12) {
                                HStack {
                                    Label("Repeat", systemImage: "repeat")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color.primaryText)
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $showRecurrenceOptions)
                                        .labelsHidden()
                                        .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                                }
                                
                                if showRecurrenceOptions {
                                    HStack {
                                        Text("Recurrence")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color.secondaryText)
                                        
                                        Spacer()
                                        
                                        Picker("Recurrence", selection: $recurrencePattern) {
                                            ForEach(RecurrencePattern.allCases.filter { $0 != .once }, id: \.self) { pattern in
                                                Text(pattern.displayName).tag(pattern)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .frame(maxWidth: 120)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Priority Section
                    sectionCard("Priority", systemImage: "flag") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                            ForEach(TaskPriority.allCases, id: \.self) { priority in
                                priorityButton(priority)
                            }
                        }
                    }
                    
                    // Type Section
                    sectionCard("Type", systemImage: "tag") {
                        Picker("Task Type", selection: $selectedType) {
                            ForEach(TaskType.allCases, id: \.self) { type in
                                HStack {
                                    Image(systemName: type.systemImage)
                                        .foregroundColor(Color.accentColor)
                                    Text(type.displayName)
                                        .foregroundColor(Color.primaryText)
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Success message
                    if scheduleSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Reminder scheduled successfully!")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.green.opacity(0.1))
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            
            // Bottom action button
            VStack(spacing: 16) {
                Button(action: scheduleReminder) {
                    HStack {
                        if isScheduling {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        Text(isScheduling ? "Scheduling..." : "Schedule Reminder")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor)
                    )
                    .foregroundColor(.white)
                }
                .disabled(isScheduling || notificationService.permissionStatus == .denied)
                .scaleEffect(isScheduling ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isScheduling)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: 500, maxHeight: 600)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primaryBackground)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 15)
        .alert("Notification Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openNotificationSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable notifications in System Preferences to schedule reminders.")
        }
        .onAppear {
            checkNotificationPermission()
        }
        .onChange(of: showRecurrenceOptions) { _, newValue in
            if !newValue {
                recurrencePattern = .once
            } else if recurrencePattern == .once {
                recurrencePattern = .daily
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func sectionCard<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.accentColor)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.primaryText)
            }
            
            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var permissionView: some View {
        if notificationService.permissionStatus == .denied {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Notification Permission Required")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                }
                
                Text("Please enable notifications in System Preferences to receive reminders.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.secondaryText)
                    .multilineTextAlignment(.center)
                
                Button("Open Settings") {
                    openNotificationSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    private func priorityButton(_ priority: TaskPriority) -> some View {
        Button(action: {
            selectedPriority = priority
        }) {
            VStack(spacing: 6) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(priority.color)
                
                Text(priority.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(selectedPriority == priority ? Color.primaryText : Color.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedPriority == priority ? priority.color.opacity(0.15) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(selectedPriority == priority ? priority.color : Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(selectedPriority == priority ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: selectedPriority == priority)
    }
    
    // MARK: - Actions
    
    private func scheduleReminder() {
        // Prevent multiple rapid clicks
        guard !isScheduling else { return }
        
        // Clear previous error message
        errorMessage = nil
        isScheduling = true
        
        Task {
            do {
                // Check permissions first
                if notificationService.permissionStatus != .authorized {
                    await requestPermission()
                    if notificationService.permissionStatus != .authorized {
                        await MainActor.run {
                            self.isScheduling = false
                            self.showingPermissionAlert = true
                        }
                        return
                    }
                }
                
                // Create schedule with proper date validation
                let scheduledDate = createScheduledDate()
                
                // Validate the date is sufficiently in the future
                let now = Date()
                if scheduledDate <= now {
                    await MainActor.run {
                        self.isScheduling = false
                        self.errorMessage = "Please select a future date and time"
                    }
                    return
                } else if scheduledDate <= now.addingTimeInterval(30) {
                    await MainActor.run {
                        self.isScheduling = false
                        self.errorMessage = "Please select a time at least 30 seconds in the future"
                    }
                    return
                }
                
                let recurrenceType = showRecurrenceOptions ? recurrencePattern.toEnhancedRecurrenceType : .once
                let schedule = EnhancedSchedule(
                    type: recurrenceType,
                    interval: 1,
                    startDate: scheduledDate,
                    endDate: nil,
                    timezone: TimeZone.current.identifier
                )
                
                // Set up time range
                let timeRange = EnhancedTimeRange(
                    startTime: scheduledDate,
                    endTime: scheduledDate.addingTimeInterval(3600), // 1 hour duration
                    timezone: TimeZone.current.identifier
                )
                schedule.timeRange = timeRange
                
                // Convert Todo to EnhancedTask and schedule
                let result = await taskScheduler.convertAndScheduleTask(todo, withSchedule: schedule)
                
                await MainActor.run {
                    self.isScheduling = false
                    
                    switch result {
                    case .success:
                        self.scheduleSuccess = true
                        self.errorMessage = nil
                        // Auto-dismiss after success
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.onScheduled()
                        }
                    case .permissionDenied:
                        self.showingPermissionAlert = true
                    case .invalidDate:
                        self.errorMessage = "The selected date and time is invalid. Please choose a future date."
                    case .schedulingFailed(let reason):
                        self.errorMessage = "Failed to schedule reminder: \(reason)"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isScheduling = false
                    self.errorMessage = "Error scheduling reminder: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func createScheduledDate() -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        
        if !showRecurrenceOptions {
            // For one-time reminders, use selected date with selected time
            return calendar.date(
                bySettingHour: timeComponents.hour ?? 0,
                minute: timeComponents.minute ?? 0,
                second: 0,
                of: selectedDate
            ) ?? selectedDate
        } else {
            // For recurring reminders, use today with selected time
            let baseDate = calendar.date(
                bySettingHour: timeComponents.hour ?? 0,
                minute: timeComponents.minute ?? 0,
                second: 0,
                of: Date()
            ) ?? Date()
            
            // For recurring reminders, if the time has already passed today, start tomorrow
            if baseDate <= Date() {
                return calendar.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate
            }
            
            return baseDate
        }
    }
    
    private func requestPermission() async {
        let granted = await notificationService.requestPermission()
        if !granted {
            showingPermissionAlert = true
        }
    }
    
    private func openNotificationSettings() {
        if let settingsUrl = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(settingsUrl)
        }
    }
    
    private func checkNotificationPermission() {
        if notificationService.permissionStatus == .denied {
            showingPermissionAlert = true
        }
    }
}

// MARK: - Extensions
extension TaskPriority {
    var color: Color {
        switch self {
        case .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .urgent:
            return .red
        }
    }
}

#Preview {
    SchedulingView(
        todo: Todo(title: "Sample Task"),
        onScheduled: {}
    )
} 