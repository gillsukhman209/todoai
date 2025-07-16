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
            // Professional Header
            headerView
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Permission warning if needed
                    permissionView
                    
                    // Error message if any
                    if let errorMessage = errorMessage {
                        errorMessageView
                    }
                    
                    // Date & Time Section
                    dateTimeSection
                    
                    // Success message
                    if scheduleSuccess {
                        successMessageView
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            
            // Bottom action button
            scheduleButton
        }
        .frame(maxWidth: 480, maxHeight: 500)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
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
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Schedule Reminder")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.black)
                
                Text(todo.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.gray)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: {
                onScheduled()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.gray)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Date & Time Section
    private var dateTimeSection: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                // Date Selection
                HStack {
                    Label("Date", systemImage: "calendar")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.black)
                    
                    Spacer()
                    
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(CompactDatePickerStyle())
                }
                
                Divider()
                
                // Time Selection
                HStack {
                    Label("Time", systemImage: "clock")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.black)
                    
                    Spacer()
                    
                    DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(CompactDatePickerStyle())
                }
                
                Divider()
                
                // Repeat Toggle
                HStack {
                    Label("Repeat", systemImage: "repeat")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.black)
                    
                    Spacer()
                    
                    Toggle("", isOn: $showRecurrenceOptions)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: Color.blue))
                }
                
                // Recurrence Options
                if showRecurrenceOptions {
                    HStack {
                        Text("Frequency")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.gray)
                        
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
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.05))
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Permission View
    @ViewBuilder
    private var permissionView: some View {
        if notificationService.permissionStatus == .denied {
            VStack(spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                
                Text("Notifications Disabled")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text("Enable notifications in System Preferences to schedule reminders")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Button("Open Settings") {
                    openNotificationSettings()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.orange.opacity(0.1))
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        } else if notificationService.permissionStatus == .notRequested {
            VStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                Text("Permission Required")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text("We need permission to send you reminder notifications")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Button("Grant Permission") {
                    requestNotificationPermission()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.1))
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Error Message View
    private var errorMessageView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(errorMessage ?? "")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red.opacity(0.1))
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Success Message View
    private var successMessageView: some View {
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
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Schedule Button
    private var scheduleButton: some View {
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
                        .fill(notificationService.permissionStatus == .denied ? Color.gray : Color.blue)
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
    
    // MARK: - Helper Methods
    private func checkNotificationPermission() {
        Task {
            await notificationService.checkPermissionStatus()
        }
    }
    
    private func requestNotificationPermission() {
        Task {
            await notificationService.requestPermission()
        }
    }
    
    private func openNotificationSettings() {
        if let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(settingsURL)
        }
    }
    
    private func scheduleReminder() {
        guard notificationService.permissionStatus == .authorized else {
            showingPermissionAlert = true
            return
        }
        
        isScheduling = true
        errorMessage = nil
        
        Task {
            do {
                // Create date with selected time
                let calendar = Calendar.current
                let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
                let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
                
                guard let scheduledDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                     minute: timeComponents.minute ?? 0,
                                                     second: 0,
                                                     of: calendar.date(from: dateComponents) ?? selectedDate) else {
                    throw NSError(domain: "SchedulingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid date"])
                }
                
                // Update todo with scheduling information
                todo.dueDate = scheduledDate
                todo.dueTime = selectedTime
                
                // Create enhanced schedule for TaskScheduler
                let schedule = EnhancedSchedule(
                    type: showRecurrenceOptions ? recurrencePattern.toEnhancedRecurrenceType : .once,
                    interval: 1,
                    startDate: scheduledDate,
                    endDate: nil,
                    timezone: TimeZone.current.identifier
                )
                
                // Set up time range
                let timeRange = EnhancedTimeRange(
                    startTime: selectedTime,
                    endTime: selectedTime.addingTimeInterval(3600), // 1 hour duration
                    timezone: TimeZone.current.identifier
                )
                schedule.timeRange = timeRange
                
                // Create recurrence config for Todo model if needed
                if showRecurrenceOptions {
                    let recurrenceConfig = RecurrenceConfig(
                        type: RecurrenceType.daily, // Simplified for now
                        interval: 1,
                        specificWeekdays: [],
                        specificTimes: [],
                        timeRange: nil,
                        monthlyDay: nil,
                        endDate: nil
                    )
                    todo.recurrenceConfig = recurrenceConfig
                }
                
                // Schedule the notification using TaskScheduler
                let result = await taskScheduler.convertAndScheduleTask(todo, withSchedule: schedule)
                
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self.scheduleSuccess = true
                        self.isScheduling = false
                        
                        // Auto-dismiss after showing success
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.onScheduled()
                        }
                    case .permissionDenied:
                        self.errorMessage = "Notification permission denied"
                        self.isScheduling = false
                    case .invalidDate:
                        self.errorMessage = "Invalid date selected"
                        self.isScheduling = false
                    case .schedulingFailed(let reason):
                        self.errorMessage = "Failed to schedule: \(reason)"
                        self.isScheduling = false
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isScheduling = false
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let todo = Todo(title: "Sample Task")
    
    SchedulingView(todo: todo) {
        print("Scheduled")
    }
    .frame(width: 600, height: 700)
    .background(Color.black.opacity(0.3))
} 