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
    

    
    /// Main entry point for creating todos - now directly creates after parsing
    func createTodo() async {
        // Parse the natural language input
        await parseNaturalLanguageTask()
        
        // If parsing was successful, immediately create the todo
        if case .parsed(let parsedData) = state {
            await createTodoFromParsedData(parsedData)
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
        
        do {
            // Create enhanced schedule from parsed data
            let schedule = createEnhancedSchedule(from: parsedData)
            
            // Use TaskScheduler to schedule the notification
            let taskScheduler = TaskScheduler.shared
            let result = await taskScheduler.convertAndScheduleTask(todo, withSchedule: schedule)
            
            switch result {
            case .success:
                logger.info("Successfully auto-scheduled notification for: '\(todo.title)'")
            case .permissionDenied:
                logger.warning("Notification permission denied for: '\(todo.title)'")
            case .invalidDate:
                logger.error("Invalid date for auto-scheduling: '\(todo.title)'")
            case .schedulingFailed(let reason):
                logger.error("Auto-scheduling failed for '\(todo.title)': \(reason)")
            }
        } catch {
            logger.error("Error auto-scheduling notification for '\(todo.title)': \(error.localizedDescription)")
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
            scheduleType = .weekly  // Use weekly instead of weekdays
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
            // For one-time tasks, use today with the specified time
            if let dueTimeString = parsedData.dueTime,
               let dueTime = Date.from(timeString: dueTimeString) {
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: dueTime)
                startDate = calendar.date(
                    bySettingHour: timeComponents.hour ?? 0,
                    minute: timeComponents.minute ?? 0,
                    second: 0,
                    of: Date()
                ) ?? Date()
                
                // If the time has already passed today, schedule for tomorrow
                if startDate <= Date() {
                    startDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
                }
            } else {
                startDate = Date()
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
            return "Todo created successfully!"
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

 