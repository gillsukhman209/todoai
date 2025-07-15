import Foundation
import SwiftData
import OSLog

// MARK: - Enhanced Recurrence Type
enum EnhancedRecurrenceType: String, Codable, CaseIterable {
    case once = "once"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    case weekdays = "weekdays"
    case weekends = "weekends"
    case biweekly = "biweekly"
    case bimonthly = "bimonthly"
    case quarterly = "quarterly"
    case semiannually = "semiannually"
    case custom = "custom"
}

// MARK: - Enhanced Weekday
enum EnhancedWeekday: Int, Codable, CaseIterable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}

// MARK: - Week Position
enum WeekPosition: Int, Codable, CaseIterable {
    case first = 1
    case second = 2
    case third = 3
    case fourth = 4
    case last = -1
}

// MARK: - Enhanced Time Range
@Model
final class EnhancedTimeRange {
    var startTime: Date = Date()
    var endTime: Date = Date().addingTimeInterval(3600) // 1 hour later
    var timezone: String = TimeZone.current.identifier
    var isValid: Bool = false
    var validationErrors: String = ""
    
    init() {
        self.validate()
    }
    
    init(startTime: Date, endTime: Date, timezone: String = TimeZone.current.identifier) {
        self.startTime = startTime
        self.endTime = endTime
        self.timezone = timezone
        self.isValid = false
        self.validationErrors = ""
        self.validate()
    }
    
    // MARK: - Computed Properties
    var start: DateComponents {
        get {
            return Calendar.current.dateComponents([.hour, .minute], from: startTime)
        }
        set {
            let calendar = Calendar.current
            let today = Date()
            if let newTime = calendar.date(bySettingHour: newValue.hour ?? 0, minute: newValue.minute ?? 0, second: 0, of: today) {
                startTime = newTime
                validate()
            }
        }
    }
    
    var end: DateComponents {
        get {
            return Calendar.current.dateComponents([.hour, .minute], from: endTime)
        }
        set {
            let calendar = Calendar.current
            let today = Date()
            if let newTime = calendar.date(bySettingHour: newValue.hour ?? 0, minute: newValue.minute ?? 0, second: 0, of: today) {
                endTime = newTime
                validate()
            }
        }
    }
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    var durationInMinutes: Int {
        return Int(duration / 60)
    }
    
    var durationInHours: Double {
        return duration / 3600
    }
    
    // MARK: - Validation
    private func validate() {
        validationErrors = ""
        
        if startTime >= endTime {
            validationErrors += "Start time must be before end time. "
            isValid = false
            return
        }
        
        if duration > 24 * 3600 {
            validationErrors += "Duration cannot exceed 24 hours. "
            isValid = false
            return
        }
        
        if duration < 60 {
            validationErrors += "Duration must be at least 1 minute. "
            isValid = false
            return
        }
        
        isValid = true
    }
    
    // MARK: - Helper Methods
    func contains(time: Date) -> Bool {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        
        let timeMinutes = (timeComponents.hour ?? 0) * 60 + (timeComponents.minute ?? 0)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        
        return timeMinutes >= startMinutes && timeMinutes <= endMinutes
    }
    
    func overlaps(with other: EnhancedTimeRange) -> Bool {
        return startTime < other.endTime && endTime > other.startTime
    }
    
    func formatted() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
}

// MARK: - Enhanced Schedule
@Model
final class EnhancedSchedule {
    var type: EnhancedRecurrenceType = EnhancedRecurrenceType.once
    var interval: Int = 1
    var startDate: Date = Date()
    var endDate: Date?
    var timezone: String = TimeZone.current.identifier
    var isActive: Bool = true
    var lastCalculated: Date?
    var nextOccurrenceCache: Date?
    var cacheExpiresAt: Date?
    
    // Optional relationships
    var timeRange: EnhancedTimeRange?
    var weekdays: [EnhancedWeekday]?
    var monthlyDays: [Int]?
    var weekPosition: WeekPosition?
    var customPattern: String?
    
    init() {}
    
    init(type: EnhancedRecurrenceType, interval: Int, startDate: Date, endDate: Date? = nil, timezone: String = TimeZone.current.identifier) {
        self.type = type
        self.interval = interval
        self.startDate = startDate
        self.endDate = endDate
        self.timezone = timezone
        self.isActive = true
        self.lastCalculated = nil
        self.nextOccurrenceCache = nil
        self.cacheExpiresAt = nil
    }
    
    // MARK: - Occurrence Calculation
    func calculateNextOccurrence(after date: Date = Date()) -> Date? {
        // Check cache first
        if let cached = nextOccurrenceCache,
           let expires = cacheExpiresAt,
           Date() < expires,
           cached > date {
            return cached
        }
        
        let calendar = Calendar.current
        var nextDate: Date?
        
        switch type {
        case .once:
            nextDate = startDate > date ? startDate : nil
            
        case .daily:
            nextDate = calculateDailyOccurrence(after: date, calendar: calendar)
            
        case .weekly:
            nextDate = calculateWeeklyOccurrence(after: date, calendar: calendar)
            
        case .monthly:
            nextDate = calculateMonthlyOccurrence(after: date, calendar: calendar)
            
        case .yearly:
            nextDate = calculateYearlyOccurrence(after: date, calendar: calendar)
            
        case .weekdays:
            nextDate = calculateWeekdaysOccurrence(after: date, calendar: calendar)
            
        case .weekends:
            nextDate = calculateWeekendsOccurrence(after: date, calendar: calendar)
            
        case .biweekly:
            nextDate = calculateBiweeklyOccurrence(after: date, calendar: calendar)
            
        case .bimonthly:
            nextDate = calculateBimonthlyOccurrence(after: date, calendar: calendar)
            
        case .quarterly:
            nextDate = calculateQuarterlyOccurrence(after: date, calendar: calendar)
            
        case .semiannually:
            nextDate = calculateSemiannuallyOccurrence(after: date, calendar: calendar)
            
        case .custom:
            nextDate = calculateCustomOccurrence(after: date, calendar: calendar)
        }
        
        // Check against end date
        if let end = endDate, let next = nextDate, next > end {
            nextDate = nil
        }
        
        // Update cache
        nextOccurrenceCache = nextDate
        cacheExpiresAt = Date().addingTimeInterval(3600) // Cache for 1 hour
        lastCalculated = Date()
        
        return nextDate
    }
    
    // MARK: - Private Calculation Methods
    private func calculateDailyOccurrence(after date: Date, calendar: Calendar) -> Date? {
        let dayInterval = interval
        var nextDate = startDate
        
        while nextDate <= date {
            nextDate = calendar.date(byAdding: .day, value: dayInterval, to: nextDate) ?? nextDate
        }
        
        return nextDate
    }
    
    private func calculateWeeklyOccurrence(after date: Date, calendar: Calendar) -> Date? {
        let weekInterval = interval
        var nextDate = startDate
        
        while nextDate <= date {
            nextDate = calendar.date(byAdding: .weekOfYear, value: weekInterval, to: nextDate) ?? nextDate
        }
        
        return nextDate
    }
    
    private func calculateMonthlyOccurrence(after date: Date, calendar: Calendar) -> Date? {
        let monthInterval = interval
        var nextDate = startDate
        
        while nextDate <= date {
            nextDate = calendar.date(byAdding: .month, value: monthInterval, to: nextDate) ?? nextDate
        }
        
        return nextDate
    }
    
    private func calculateYearlyOccurrence(after date: Date, calendar: Calendar) -> Date? {
        let yearInterval = interval
        var nextDate = startDate
        
        while nextDate <= date {
            nextDate = calendar.date(byAdding: .year, value: yearInterval, to: nextDate) ?? nextDate
        }
        
        return nextDate
    }
    
    private func calculateWeekdaysOccurrence(after date: Date, calendar: Calendar) -> Date? {
        var nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        
        while true {
            let weekday = calendar.component(.weekday, from: nextDate)
            if weekday >= 2 && weekday <= 6 { // Monday to Friday
                return nextDate
            }
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
        }
    }
    
    private func calculateWeekendsOccurrence(after date: Date, calendar: Calendar) -> Date? {
        var nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        
        while true {
            let weekday = calendar.component(.weekday, from: nextDate)
            if weekday == 1 || weekday == 7 { // Sunday or Saturday
                return nextDate
            }
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
        }
    }
    
    private func calculateBiweeklyOccurrence(after date: Date, calendar: Calendar) -> Date? {
        return calculateWeeklyOccurrence(after: date, calendar: calendar)
    }
    
    private func calculateBimonthlyOccurrence(after date: Date, calendar: Calendar) -> Date? {
        let monthInterval = 2 * interval
        var nextDate = startDate
        
        while nextDate <= date {
            nextDate = calendar.date(byAdding: .month, value: monthInterval, to: nextDate) ?? nextDate
        }
        
        return nextDate
    }
    
    private func calculateQuarterlyOccurrence(after date: Date, calendar: Calendar) -> Date? {
        let monthInterval = 3 * interval
        var nextDate = startDate
        
        while nextDate <= date {
            nextDate = calendar.date(byAdding: .month, value: monthInterval, to: nextDate) ?? nextDate
        }
        
        return nextDate
    }
    
    private func calculateSemiannuallyOccurrence(after date: Date, calendar: Calendar) -> Date? {
        let monthInterval = 6 * interval
        var nextDate = startDate
        
        while nextDate <= date {
            nextDate = calendar.date(byAdding: .month, value: monthInterval, to: nextDate) ?? nextDate
        }
        
        return nextDate
    }
    
    private func calculateCustomOccurrence(after date: Date, calendar: Calendar) -> Date? {
        // This would need to be implemented based on the custom pattern
        // For now, fall back to daily
        return calculateDailyOccurrence(after: date, calendar: calendar)
    }
    
    // MARK: - Convenience Methods
    func nextOccurrence() -> Date? {
        return calculateNextOccurrence()
    }
    
    func nextOccurrence(after date: Date) -> Date? {
        return calculateNextOccurrence(after: date)
    }
    
    // MARK: - Helper Methods
    func isValidForDate(_ date: Date) -> Bool {
        guard isActive else { return false }
        
        if date < startDate {
            return false
        }
        
        if let end = endDate, date > end {
            return false
        }
        
        return true
    }
    
    func occurrencesBetween(start: Date, end: Date) -> [Date] {
        var occurrences: [Date] = []
        var current = start
        
        while current <= end {
            if let next = calculateNextOccurrence(after: current) {
                if next <= end {
                    occurrences.append(next)
                    current = next
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        return occurrences
    }
    
    func disable() {
        isActive = false
    }
    
    func enable() {
        isActive = true
        // Clear cache when re-enabling
        nextOccurrenceCache = nil
        cacheExpiresAt = nil
    }
} 
