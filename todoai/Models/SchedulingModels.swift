import Foundation
import SwiftData

// MARK: - Recurrence Pattern
enum RecurrenceType: String, Codable, CaseIterable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    case hourly = "hourly"
    case customInterval = "custom_interval"
    case specificDays = "specific_days"
    case multipleDailyTimes = "multiple_daily_times"
}

// MARK: - Weekday Support
enum Weekday: Int, Codable, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    
    var name: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
    
    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

// MARK: - Time Range
@Model
final class TimeRange {
    var startTime: Date
    var endTime: Date
    
    init(startTime: Date, endTime: Date) {
        self.startTime = startTime
        self.endTime = endTime
    }
    
    // Helper for parsing time strings like "9am" or "17:30"
    static func time(from timeString: String) -> Date? {
        let cleanedString = timeString.trimmingCharacters(in: .whitespaces)
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        
        // Try 12-hour format with colon and space (9:30 AM, 6:30 PM)
        formatter.dateFormat = "h:mm a"
        if let date = formatter.date(from: cleanedString) {
            return date
        }
        
        // Try 12-hour format without space (9:30AM, 6:30PM)
        formatter.dateFormat = "h:mma"
        if let date = formatter.date(from: cleanedString.replacingOccurrences(of: " ", with: "")) {
            return date
        }
        
        // Try hour only with space (9 AM, 6 PM)
        formatter.dateFormat = "h a"
        if let date = formatter.date(from: cleanedString) {
            return date
        }
        
        // Try hour only without space (9AM, 6PM)
        formatter.dateFormat = "ha"
        if let date = formatter.date(from: cleanedString.replacingOccurrences(of: " ", with: "")) {
            return date
        }
        
        // Try 24-hour format (17:30, 09:00)
        formatter.dateFormat = "HH:mm"
        if let date = formatter.date(from: cleanedString) {
            return date
        }
        
        // Try 24-hour format without leading zero (7:30, 17:30)
        formatter.dateFormat = "H:mm"
        if let date = formatter.date(from: cleanedString) {
            return date
        }
        
        // Try hour only 24-hour (17, 09)
        formatter.dateFormat = "HH"
        if let date = formatter.date(from: cleanedString) {
            return date
        }
        
        // Try hour only 24-hour without leading zero (7, 17)
        formatter.dateFormat = "H"
        if let date = formatter.date(from: cleanedString) {
            return date
        }
        
        return nil
    }
}

// MARK: - Recurrence Configuration
@Model
final class RecurrenceConfig {
    var type: RecurrenceType
    var interval: Int // For custom intervals (every 2 hours, every 3 days)
    var specificWeekdaysString: String // Comma-separated weekday raw values
    var specificTimesString: String // Comma-separated time strings
    var timeRange: TimeRange? // For "from 9am to 5pm" scenarios
    var monthlyDay: Int? // For monthly recurrence (1st, 15th, etc.)
    var endDate: Date? // Optional end date for recurrence
    
    init(
        type: RecurrenceType = .none,
        interval: Int = 1,
        specificWeekdays: [Int] = [],
        specificTimes: [Date] = [],
        timeRange: TimeRange? = nil,
        monthlyDay: Int? = nil,
        endDate: Date? = nil
    ) {
        self.type = type
        self.interval = interval
        self.specificWeekdaysString = specificWeekdays.map { String($0) }.joined(separator: ",")
        self.specificTimesString = specificTimes.map { String($0.timeIntervalSince1970) }.joined(separator: ",")
        self.timeRange = timeRange
        self.monthlyDay = monthlyDay
        self.endDate = endDate
    }
    
    // Helper computed properties
    var specificWeekdays: [Int] {
        get {
            guard !specificWeekdaysString.isEmpty else { return [] }
            return specificWeekdaysString.split(separator: ",").compactMap { Int($0) }
        }
        set {
            specificWeekdaysString = newValue.map { String($0) }.joined(separator: ",")
        }
    }
    
    var specificTimes: [Date] {
        get {
            guard !specificTimesString.isEmpty else { return [] }
            return specificTimesString.split(separator: ",").compactMap { 
                if let timeInterval = TimeInterval($0) {
                    return Date(timeIntervalSince1970: timeInterval)
                }
                return nil
            }
        }
        set {
            specificTimesString = newValue.map { String($0.timeIntervalSince1970) }.joined(separator: ",")
        }
    }
    
    var weekdays: [Weekday] {
        return specificWeekdays.compactMap { Weekday(rawValue: $0) }
    }
    
    var isRecurring: Bool {
        return type != .none
    }
    
    var hasTimeRange: Bool {
        return timeRange != nil
    }
    
    var hasMultipleTimes: Bool {
        return !specificTimes.isEmpty
    }
    
    /// Calculate the next occurrence after the given date
    func calculateNextOccurrence(after date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        
        switch type {
        case .none:
            return nil
            
        case .daily:
            if !specificTimes.isEmpty {
                return calculateNextDailyTimeOccurrence(after: date, calendar: calendar)
            } else {
                return calendar.date(byAdding: .day, value: interval, to: date)
            }
            
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: interval, to: date)
            
        case .monthly:
            if let day = monthlyDay {
                return calculateNextMonthlyDayOccurrence(after: date, calendar: calendar, day: day)
            } else {
                return calendar.date(byAdding: .month, value: interval, to: date)
            }
            
        case .yearly:
            return calendar.date(byAdding: .year, value: interval, to: date)
            
        case .hourly:
            if let timeRange = timeRange {
                return calculateNextHourlyInRangeOccurrence(after: date, calendar: calendar)
            } else {
                return calendar.date(byAdding: .hour, value: interval, to: date)
            }
            
        case .customInterval:
            return calendar.date(byAdding: .hour, value: interval, to: date)
            
        case .specificDays:
            return calculateNextSpecificDaysOccurrence(after: date, calendar: calendar)
            
        case .multipleDailyTimes:
            return calculateNextMultipleDailyTimesOccurrence(after: date, calendar: calendar)
        }
    }
    
    /// Get the next N occurrences starting from the given date
    func getNextOccurrences(count: Int, after date: Date = Date()) -> [Date] {
        var occurrences: [Date] = []
        var currentDate = date
        
        for _ in 0..<count {
            if let nextOccurrence = calculateNextOccurrence(after: currentDate) {
                occurrences.append(nextOccurrence)
                currentDate = nextOccurrence
            } else {
                break
            }
        }
        
        return occurrences
    }
    
    /// Get the next N occurrences formatted as display strings
    func getNextOccurrencesFormatted(count: Int, after date: Date = Date()) -> [String] {
        let occurrences = getNextOccurrences(count: count, after: date)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
        formatter.timeZone = TimeZone.current
        
        return occurrences.map { occurrence in
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE, MMM d"
            dayFormatter.timeZone = TimeZone.current
            let dayString = dayFormatter.string(from: occurrence)
            
            // Get the time component
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            timeFormatter.timeZone = TimeZone.current
            let timeString = timeFormatter.string(from: occurrence)
            
            return "\(dayString) at \(timeString)"
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func calculateNextDailyTimeOccurrence(after date: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: date)
        
        // Check if any of today's times are still in the future
        for time in specificTimes {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
            if let todayTime = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: today) {
                if todayTime > date {
                    return todayTime
                }
            }
        }
        
        // If no time today is in the future, get the first time tomorrow
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           let firstTime = specificTimes.first {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: firstTime)
            let tomorrowStart = calendar.startOfDay(for: tomorrow)
            return calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: tomorrowStart)
        }
        
        return nil
    }
    
    private func calculateNextMonthlyDayOccurrence(after date: Date, calendar: Calendar, day: Int) -> Date? {
        let currentMonth = calendar.component(.month, from: date)
        let currentYear = calendar.component(.year, from: date)
        
        // Try this month first
        if let thisMonthDate = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: day)),
           thisMonthDate > date {
            return thisMonthDate
        }
        
        // Try next month
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) {
            let nextMonthComponents = calendar.dateComponents([.year, .month], from: nextMonth)
            return calendar.date(from: DateComponents(year: nextMonthComponents.year, month: nextMonthComponents.month, day: day))
        }
        
        return nil
    }
    
    private func calculateNextHourlyInRangeOccurrence(after date: Date, calendar: Calendar) -> Date? {
        guard let timeRange = timeRange else { return nil }
        
        let startHour = calendar.component(.hour, from: timeRange.startTime)
        let endHour = calendar.component(.hour, from: timeRange.endTime)
        let currentHour = calendar.component(.hour, from: date)
        
        // Find next hour within range
        for hour in stride(from: currentHour + 1, through: endHour, by: interval) {
            if let nextTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) {
                return nextTime
            }
        }
        
        // If no more hours today, start from beginning of range tomorrow
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) {
            return calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: tomorrow)
        }
        
        return nil
    }
    
    private func calculateNextSpecificDaysOccurrence(after date: Date, calendar: Calendar) -> Date? {
        guard !specificWeekdays.isEmpty else { return nil }
        
        let sortedWeekdays = specificWeekdays.sorted()
        
        // First, check if today is one of the target weekdays
        let todayWeekday = calendar.component(.weekday, from: date)
        if sortedWeekdays.contains(todayWeekday) {
            // Check if today's scheduled time is still in the future
            if let firstTime = specificTimes.first {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: firstTime)
                let today = calendar.startOfDay(for: date)
                if let todayScheduledTime = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: today) {
                    if todayScheduledTime > date {
                        return todayScheduledTime
                    }
                }
            }
        }
        
        // If today doesn't work, look for the next occurrence
        var nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        
        // Find the next occurrence that falls on one of the specified weekdays
        for _ in 0..<14 { // Check up to 2 weeks ahead
            let weekday = calendar.component(.weekday, from: nextDate)
            
            if sortedWeekdays.contains(weekday) {
                // Apply the time if specified
                if let firstTime = specificTimes.first {
                    let timeComponents = calendar.dateComponents([.hour, .minute], from: firstTime)
                    let nextDayStart = calendar.startOfDay(for: nextDate)
                    if let scheduledTime = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: nextDayStart) {
                        return scheduledTime
                    }
                }
                return nextDate
            }
            
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
        }
        
        return nil
    }
    
    private func calculateNextMultipleDailyTimesOccurrence(after date: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: date)
        
        // Check if any of today's times are still in the future
        for time in specificTimes.sorted(by: { $0 < $1 }) {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
            if let todayTime = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: today) {
                if todayTime > date {
                    return todayTime
                }
            }
        }
        
        // If no time today is in the future, get the first time tomorrow
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           let firstTime = specificTimes.sorted(by: { $0 < $1 }).first {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: firstTime)
            let tomorrowStart = calendar.startOfDay(for: tomorrow)
            return calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: tomorrowStart)
        }
        
        return nil
    }
}

// MARK: - Natural Language Parse Result
struct ParsedTaskData: Codable, Equatable {
    let cleanTitle: String
    let dueDate: String? // ISO date string
    let dueTime: String? // Time string like "9:00 AM"
    let recurrenceType: String
    let interval: Int?
    let specificWeekdays: [String]? // ["monday", "wednesday", "friday"]
    let specificTimes: [String]? // ["10:00 AM", "6:00 PM"]
    let timeRangeStart: String? // "9:00 AM"
    let timeRangeEnd: String? // "5:00 PM"
    let monthlyDay: Int? // 1, 15, etc.
    let description: String? // Additional context from AI
    let priority: String? // "low", "medium", "high"
    let category: String? // "work", "personal", "shopping", "health", "other"
}

// MARK: - Extensions for Date Formatting
extension Date {
    static func from(timeString: String) -> Date? {
        return TimeRange.time(from: timeString)
    }
    
    static func from(dateString: String) -> Date? {
        let formatters: [DateFormatter] = [
            // ISO 8601 format
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            // Full date format (January 15, 2024)
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM d, yyyy"
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            // Short date format (Jan 15, 2024)
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            // Numeric date format (01/15/2024)
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd/yyyy"
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            // Numeric date format (1/15/2024)
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "M/d/yyyy"
                formatter.timeZone = TimeZone.current
                return formatter
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    static func from(dateTimeString: String) -> Date? {
        let formatters: [DateFormatter] = [
            // ISO 8601 with time
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            // Full date with time (January 15, 2024 at 9:30 AM)
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            // Short date with time (Jan 15, 2024 at 9:30 AM)
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
                formatter.timeZone = TimeZone.current
                return formatter
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateTimeString) {
                return date
            }
        }
        
        return nil
    }
    
    func timeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
    
    func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
    
    func fullDateTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
} 