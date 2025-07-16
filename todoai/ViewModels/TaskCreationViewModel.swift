import Foundation
import SwiftData
import OSLog

// MARK: - Task Creation State
enum TaskCreationState: Equatable {
    case idle
    case parsing
    case parsed(ParsedTaskData)
    case creating
    case completed
    case error(String)
    
    static func == (lhs: TaskCreationState, rhs: TaskCreationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.parsing, .parsing), (.creating, .creating), (.completed, .completed):
            return true
        case (.parsed(let lhsData), .parsed(let rhsData)):
            return lhsData.cleanTitle == rhsData.cleanTitle
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

// MARK: - Task Creation ViewModel
@MainActor
final class TaskCreationViewModel: ObservableObject {
    @Published var state: TaskCreationState = .idle
    @Published var input: String = ""
    
    private let openAIService: OpenAIService
    private var modelContext: ModelContext
    private let logger = Logger(subsystem: "com.todoai.app", category: "TaskCreationViewModel")
    
    init(openAIService: OpenAIService, modelContext: ModelContext) {
        self.openAIService = openAIService
        self.modelContext = modelContext
    }
    
    // MARK: - Public Methods
    
    /// Detect if input contains scheduling keywords
    private func containsSchedulingKeywords(_ input: String) -> Bool {
        let schedulingKeywords = [
            // Time indicators
            "at", "by", "before", "after", "around", "pm", "am", "p.m.", "a.m.",
            // Date indicators  
            "today", "tomorrow", "tonight", "morning", "afternoon", "evening", "night",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "mon", "tue", "wed", "thu", "fri", "sat", "sun",
            "next", "this", "last", "week", "month", "year",
            // Recurrence indicators
            "every", "each", "daily", "weekly", "monthly", "yearly",
            "repeat", "recurring", "regularly", "schedule",
            // Reminder indicators
            "remind", "reminder", "alert", "notify", "notification",
            // Due date indicators
            "due", "deadline", "expires", "until", "through"
        ]
        
        let lowercased = input.lowercased()
        
        // Use word boundaries to avoid false positives
        // e.g., "category" shouldn't match "at" 
        for keyword in schedulingKeywords {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: lowercased.count)
                if regex.firstMatch(in: lowercased, options: [], range: range) != nil {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Create a simple todo instantly without OpenAI parsing
    private func createSimpleTodo() -> Todo {
        let cleanTitle = input.trimmingCharacters(in: .whitespaces)
        return Todo(title: cleanTitle, originalInput: input)
    }
    
    /// Convert weekday strings to integers (1 = Sunday, 2 = Monday, etc.)
    private func convertWeekdaysToIntegers(_ weekdays: [String]) -> [Int] {
        return weekdays.compactMap { weekday in
            switch weekday.lowercased() {
            case "sunday", "sun":
                return 1
            case "monday", "mon":
                return 2
            case "tuesday", "tue":
                return 3
            case "wednesday", "wed":
                return 4
            case "thursday", "thu":
                return 5
            case "friday", "fri":
                return 6
            case "saturday", "sat":
                return 7
            default:
                return nil
            }
        }
    }
    
    /// Convert time strings to Date objects
    private func convertTimesToDates(_ times: [String]) -> [Date] {
        return times.compactMap { timeString in
            Date.from(timeString: timeString)
        }
    }
    
    /// Parse natural language input using OpenAI
    func parseNaturalLanguageTask() async {
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        logger.info("🎯 TaskCreationViewModel: Starting to parse input: '\(self.input)'")
        
        // Check if API key is set up
        let apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        if apiKey.isEmpty {
            let errorMessage = "OpenAI API key not set. Please go to Settings to configure your API key."
            logger.error("❌ TaskCreationViewModel: \(errorMessage)")
            state = .error(errorMessage)
            return
        }
        
        state = .parsing
        
        do {
            logger.info("🔄 TaskCreationViewModel: Calling OpenAI service...")
            let parsedData = try await openAIService.parseTask(self.input)
            logger.info("🎉 TaskCreationViewModel: Successfully parsed: '\(self.input)' -> '\(parsedData.cleanTitle)'")
            state = .parsed(parsedData)
        } catch {
            let errorMessage = "Failed to parse task: \(error.localizedDescription)"
            logger.error("❌ TaskCreationViewModel: \(errorMessage)")
            logger.error("❌ TaskCreationViewModel: Error type: \(type(of: error))")
            state = .error(errorMessage)
        }
    }
    
    /// Create todo from parsed data
    func createTodoFromParsedData(_ parsedData: ParsedTaskData) async {
        state = .creating
        
        do {
            let todo = Todo.from(parsedData: parsedData, originalInput: self.input)
            modelContext.insert(todo)
            
            try modelContext.save()
            
            // Auto-schedule notification if there's timing data
            await autoScheduleNotificationIfNeeded(for: todo, parsedData: parsedData)
            
            state = .completed
            // Don't reset state immediately - let ContentView react to .completed first
            
            logger.info("Successfully created todo: '\(todo.title)'")
        } catch {
            let errorMessage = "Failed to create todo: \(error.localizedDescription)"
            state = .error(errorMessage)
            logger.error("\(errorMessage)")
        }
    }
    

    
    /// Main entry point for creating todos - instant creation with background processing
    func createTodo() async {
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        logger.info("🚀 TaskCreationViewModel: Processing input: '\(self.input)'")
        
        // Check if this is a simple todo (no scheduling keywords)
        if !containsSchedulingKeywords(input) {
            logger.info("⚡ TaskCreationViewModel: No scheduling keywords detected, creating simple todo instantly")
            await createSimpleTodoInstantly()
        } else {
            logger.info("🔄 TaskCreationViewModel: Scheduling keywords detected, creating todo instantly then processing in background")
            await createTodoWithBackgroundProcessing()
        }
    }
    
    /// Create a simple todo instantly without OpenAI processing
    private func createSimpleTodoInstantly() async {
        state = .creating
        
        do {
            let todo = createSimpleTodo()
            modelContext.insert(todo)
            try modelContext.save()
            
            state = .completed
            logger.info("⚡ Successfully created simple todo instantly: '\(todo.title)'")
        } catch {
            let errorMessage = "Failed to create simple todo: \(error.localizedDescription)"
            state = .error(errorMessage)
            logger.error("❌ \(errorMessage)")
        }
    }
    
    /// Create todo instantly, then process with OpenAI in background
    private func createTodoWithBackgroundProcessing() async {
        state = .creating
        
        do {
            // Phase 1: Create todo instantly with raw text
            let todo = createSimpleTodo()
            todo.isProcessing = true
            modelContext.insert(todo)
            try modelContext.save()
            
            state = .completed
            logger.info("⚡ Successfully created todo instantly: '\(todo.title)' - processing in background")
            
            // Phase 2: Process with OpenAI in background
            Task {
                await processExistingTodoWithOpenAI(todo)
            }
            
        } catch {
            let errorMessage = "Failed to create todo: \(error.localizedDescription)"
            state = .error(errorMessage)
            logger.error("❌ \(errorMessage)")
        }
    }
    
    /// Process an existing todo with OpenAI and update it
    private func processExistingTodoWithOpenAI(_ todo: Todo) async {
        logger.info("🔄 Processing todo with OpenAI: '\(todo.title)'")
        
        // Check if API key is set up
        let apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        if apiKey.isEmpty {
            logger.error("❌ OpenAI API key not set, cannot process todo")
            await MainActor.run {
                todo.isProcessing = false
                todo.processingError = "OpenAI API key not set"
                try? modelContext.save()
            }
            return
        }
        
        do {
            // Parse with OpenAI using the original input
            let parsedData = try await openAIService.parseTask(todo.originalInput ?? todo.title)
            
            await MainActor.run {
                // Update todo with parsed data
                todo.title = parsedData.cleanTitle
                todo.aiDescription = parsedData.description
                
                // Set due date/time for one-time tasks
                if let dueDateString = parsedData.dueDate {
                    if let date = Date.from(dateString: dueDateString) {
                        todo.dueDate = date
                    } else {
                        todo.dueDate = ISO8601DateFormatter().date(from: dueDateString)
                    }
                }
                
                if let dueTimeString = parsedData.dueTime {
                    todo.dueTime = Date.from(timeString: dueTimeString)
                }
                
                // Set recurrence configuration
                if parsedData.recurrenceType != "none" {
                    let config = RecurrenceConfig()
                    
                    // Map recurrence type properly
                    switch parsedData.recurrenceType {
                    case "daily":
                        config.type = .daily
                    case "weekly":
                        config.type = .weekly
                    case "monthly":
                        config.type = .monthly
                    default:
                        if let recurrenceType = RecurrenceType(rawValue: parsedData.recurrenceType) {
                            config.type = recurrenceType
                        }
                    }
                    
                    // Set specific weekdays for "specific_days" recurrence type
                    if parsedData.recurrenceType == "specific_days",
                       let weekdays = parsedData.specificWeekdays {
                        config.specificWeekdays = convertWeekdaysToIntegers(weekdays)
                    }
                    
                    // Set specific times
                    if let times = parsedData.specificTimes {
                        config.specificTimes = convertTimesToDates(times)
                    }
                    
                    // Set time range
                    if let startTime = parsedData.timeRangeStart,
                       let endTime = parsedData.timeRangeEnd,
                       let startTimeDate = Date.from(timeString: startTime),
                       let endTimeDate = Date.from(timeString: endTime) {
                        config.timeRange = TimeRange(startTime: startTimeDate, endTime: endTimeDate)
                    }
                    
                    // Set monthly day
                    if let monthlyDay = parsedData.monthlyDay {
                        config.monthlyDay = monthlyDay
                    }
                    
                    // Set interval
                    if let interval = parsedData.interval {
                        config.interval = interval
                    }
                    
                    todo.recurrenceConfig = config
                }
                
                // Clear processing state
                todo.isProcessing = false
                todo.processingError = nil
                
                try? modelContext.save()
                logger.info("✅ Successfully processed todo with OpenAI: '\(todo.title)'")
                
                // Auto-schedule notification if needed
                Task {
                    await autoScheduleNotificationIfNeeded(for: todo, parsedData: parsedData)
                }
            }
            
        } catch {
            logger.error("❌ Failed to process todo with OpenAI: \(error.localizedDescription)")
            await MainActor.run {
                todo.isProcessing = false
                todo.processingError = "Failed to process: \(error.localizedDescription)"
                try? modelContext.save()
            }
        }
    }
    
    /// Reset the view model state
    func resetState() {
        input = ""
        state = .idle
    }
    
    /// Update model context (needed for environment integration)
    func updateModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    /// Auto-schedule notification if timing data is present
    private func autoScheduleNotificationIfNeeded(for todo: Todo, parsedData: ParsedTaskData) async {
        // Check if there's any timing data that warrants a notification
        let hasTimingData = parsedData.dueTime != nil || 
                           parsedData.recurrenceType != "none" ||
                           parsedData.specificTimes != nil ||
                           parsedData.timeRangeStart != nil
        
        guard hasTimingData else {
            logger.info("No timing data found, skipping auto-scheduling for: '\(todo.title)'")
            return
        }
        
        logger.info("Auto-scheduling notification for: '\(todo.title)'")
        logger.info("Parsed data: recurrenceType=\(parsedData.recurrenceType), specificTimes=\(parsedData.specificTimes ?? []), specificWeekdays=\(parsedData.specificWeekdays ?? [])")
        
        do {
            // Request notification permissions if needed
            let taskScheduler = TaskScheduler.shared
            let hasPermission = await taskScheduler.requestNotificationPermissionIfNeeded()
            
            if !hasPermission {
                logger.warning("Notification permission denied, cannot schedule for: '\(todo.title)'")
                return
            }
            
            // Create enhanced schedule from parsed data
            let schedule = createEnhancedSchedule(from: parsedData)
      
            
            // Schedule the notification
            let result = await taskScheduler.convertAndScheduleTask(todo, withSchedule: schedule)
            
            switch result {
            case .success:
                logger.info("✅ Successfully auto-scheduled notification for: '\(todo.title)'")
            case .permissionDenied:
                logger.warning("⚠️ Notification permission denied for: '\(todo.title)'")
            case .invalidDate:
                logger.error("❌ Invalid date for auto-scheduling: '\(todo.title)'")
            case .schedulingFailed(let reason):
                logger.error("❌ Auto-scheduling failed for '\(todo.title)': \(reason)")
            }
        } catch {
            logger.error("❌ Error auto-scheduling notification for '\(todo.title)': \(error.localizedDescription)")
        }
    }
    
    /// Create EnhancedSchedule from parsed data
    private func createEnhancedSchedule(from parsedData: ParsedTaskData) -> EnhancedSchedule {
        let scheduleType: EnhancedRecurrenceType
        
        switch parsedData.recurrenceType {
        case "none":
            scheduleType = .once
        case "daily":
            scheduleType = .daily
        case "weekly":
            scheduleType = .weekly
        case "monthly":
            scheduleType = .monthly
        case "yearly":
            scheduleType = .yearly
        case "specific_days":
            scheduleType = .weekdays  // Use weekdays for specific day scheduling
        case "custom_interval":
            scheduleType = .custom
        case "multiple_daily_times":
            scheduleType = .daily
        default:
            scheduleType = .once
        }
        
        // Determine the start date
        var startDate: Date
        if scheduleType == .once {
            // For one-time tasks, use the specified date and time
            let calendar = Calendar.current
            
            // Determine the target date
            var targetDate: Date
            if let dueDateString = parsedData.dueDate,
               let dueDate = Date.from(dateString: dueDateString) {
                targetDate = dueDate
            } else {
                targetDate = Date() // Default to today if no specific date
            }
            
            // Apply the specified time if available
            if let dueTimeString = parsedData.dueTime,
               let dueTime = Date.from(timeString: dueTimeString) {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: dueTime)
                startDate = calendar.date(
                    bySettingHour: timeComponents.hour ?? 0,
                    minute: timeComponents.minute ?? 0,
                    second: 0,
                    of: targetDate
                ) ?? targetDate
                
                // If the calculated time has already passed, schedule for the next day
                if startDate <= Date() {
                    startDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
                }
            } else {
                startDate = targetDate
            }
        } else {
            // For recurring tasks, start from today
            startDate = Date()
        }
        
        let schedule = EnhancedSchedule(
            type: scheduleType,
            interval: parsedData.interval ?? 1,
            startDate: startDate,
            endDate: nil,
            timezone: TimeZone.current.identifier
        )
        
        // Set specific weekdays for "specific_days" recurrence type
        if parsedData.recurrenceType == "specific_days",
           let weekdayStrings = parsedData.specificWeekdays {
            schedule.weekdays = weekdayStrings.compactMap { dayString in
                switch dayString.lowercased() {
                case "monday": return EnhancedWeekday.monday
                case "tuesday": return EnhancedWeekday.tuesday
                case "wednesday": return EnhancedWeekday.wednesday
                case "thursday": return EnhancedWeekday.thursday
                case "friday": return EnhancedWeekday.friday
                case "saturday": return EnhancedWeekday.saturday
                case "sunday": return EnhancedWeekday.sunday
                default: return nil
                }
            }
        }
        
        // Set up time range if there's specific time data
        if let dueTimeString = parsedData.dueTime,
           let dueTime = Date.from(timeString: dueTimeString) {
            let timeRange = EnhancedTimeRange(
                startTime: dueTime,
                endTime: dueTime.addingTimeInterval(3600), // 1 hour duration
                timezone: TimeZone.current.identifier
            )
            schedule.timeRange = timeRange
        } else if let startTimeString = parsedData.timeRangeStart,
                  let endTimeString = parsedData.timeRangeEnd,
                  let startTime = Date.from(timeString: startTimeString),
                  let endTime = Date.from(timeString: endTimeString) {
            let timeRange = EnhancedTimeRange(
                startTime: startTime,
                endTime: endTime,
                timezone: TimeZone.current.identifier
            )
            schedule.timeRange = timeRange
        } else if let specificTimes = parsedData.specificTimes,
                  let firstTime = specificTimes.first,
                  let time = Date.from(timeString: firstTime) {
            let timeRange = EnhancedTimeRange(
                startTime: time,
                endTime: time.addingTimeInterval(3600), // 1 hour duration
                timezone: TimeZone.current.identifier
            )
            schedule.timeRange = timeRange
        }
        
        return schedule
    }
    
    /// Dismiss any error state
    func dismissError() {
        if case .error = state {
            state = .idle
        }
    }
    
    // MARK: - Computed Properties
    
    var isLoading: Bool {
        switch state {
        case .parsing, .creating:
            return true
        default:
            return false
        }
    }
    
    var canCreateTodo: Bool {
        return !input.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }
    
    var statusMessage: String {
        switch state {
        case .idle:
            return ""
        case .parsing:
            return "Parsing natural language..."
        case .parsed(let data):
            return "Parsed: \(data.cleanTitle)"
        case .creating:
            return "Creating todo..."
        case .completed:
            return ""
        case .error(let message):
            return message
        }
    }
    
    // MARK: - Helper Methods
    
    /// Automatically detect if input requires natural language processing
    private func requiresNaturalLanguageProcessing(_ input: String) -> Bool {
        // For now, all inputs go through AI processing
        return !input.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

 
