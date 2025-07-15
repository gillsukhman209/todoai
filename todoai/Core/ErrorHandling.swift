import Foundation
import OSLog
import SwiftData

// MARK: - Error Categories
enum ErrorCategory: String, CaseIterable {
    case dataModel = "data_model"
    case network = "network"
    case ai = "ai"
    case notification = "notification"
    case validation = "validation"
    case migration = "migration"
    case permission = "permission"
    case system = "system"
    case user = "user"
    case unknown = "unknown"
}

// MARK: - Error Severity
enum ErrorSeverity: Int, CaseIterable {
    case info = 0
    case warning = 1
    case error = 2
    case critical = 3
    case fatal = 4
    
    var displayName: String {
        switch self {
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        case .critical: return "Critical"
        case .fatal: return "Fatal"
        }
    }
    
    var emoji: String {
        switch self {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        case .fatal: return "💀"
        }
    }
}

// MARK: - Recovery Strategy
enum RecoveryStrategy {
    case none
    case retry(maxAttempts: Int)
    case fallback(action: () -> Void)
    case userIntervention(message: String)
    case gracefulDegradation
    case restart
}

// MARK: - Enhanced Error Protocol
protocol EnhancedError: Error {
    var category: ErrorCategory { get }
    var severity: ErrorSeverity { get }
    var code: String { get }
    var userMessage: String { get }
    var technicalMessage: String { get }
    var recoveryStrategy: RecoveryStrategy { get }
    var context: [String: Any] { get }
    var timestamp: Date { get }
    var canRetry: Bool { get }
    var shouldLog: Bool { get }
    var shouldNotifyUser: Bool { get }
}

// MARK: - Base Enhanced Error
struct BaseEnhancedError: EnhancedError {
    let category: ErrorCategory
    let severity: ErrorSeverity
    let code: String
    let userMessage: String
    let technicalMessage: String
    let recoveryStrategy: RecoveryStrategy
    let context: [String: Any]
    let timestamp: Date
    let canRetry: Bool
    let shouldLog: Bool
    let shouldNotifyUser: Bool
    
    init(
        category: ErrorCategory,
        severity: ErrorSeverity,
        code: String,
        userMessage: String,
        technicalMessage: String,
        recoveryStrategy: RecoveryStrategy = .none,
        context: [String: Any] = [:],
        canRetry: Bool = false,
        shouldLog: Bool = true,
        shouldNotifyUser: Bool = true
    ) {
        self.category = category
        self.severity = severity
        self.code = code
        self.userMessage = userMessage
        self.technicalMessage = technicalMessage
        self.recoveryStrategy = recoveryStrategy
        self.context = context
        self.timestamp = Date()
        self.canRetry = canRetry
        self.shouldLog = shouldLog
        self.shouldNotifyUser = shouldNotifyUser
    }
}

// MARK: - Specific Error Types
enum TodoAppError: EnhancedError {
    // Data Model Errors
    case dataModelValidationFailed(String)
    case dataModelCorrupted(String)
    case dataModelMigrationFailed(String)
    case dataModelRelationshipBroken(String)
    
    // Network Errors
    case networkConnectionFailed(String)
    case networkTimeout(String)
    case networkDNSResolutionFailed(String)
    case networkUnauthorized(String)
    case networkServerError(String)
    case networkRateLimited(String)
    
    // AI Processing Errors
    case aiProcessingFailed(String)
    case aiAPIKeyInvalid(String)
    case aiAPIKeyMissing(String)
    case aiResponseInvalid(String)
    case aiConfidenceTooLow(String)
    case aiParsingFailed(String)
    
    // Notification Errors
    case notificationPermissionDenied(String)
    case notificationSchedulingFailed(String)
    case notificationDeliveryFailed(String)
    case notificationSystemError(String)
    
    // Validation Errors
    case validationEmptyTitle(String)
    case validationInvalidDate(String)
    case validationInvalidRecurrence(String)
    case validationDataCorrupted(String)
    
    // Migration Errors
    case migrationSchemaIncompatible(String)
    case migrationDataLoss(String)
    case migrationBackupFailed(String)
    case migrationRestoreFailed(String)
    
    // Permission Errors
    case permissionNotificationDenied(String)
    case permissionCalendarDenied(String)
    case permissionLocationDenied(String)
    
    // System Errors
    case systemOutOfMemory(String)
    case systemDiskFull(String)
    case systemTimezoneChanged(String)
    case systemClockSkewed(String)
    
    // User Errors
    case userInputInvalid(String)
    case userActionCancelled(String)
    case userQuotaExceeded(String)
    
    // Unknown Errors
    case unknown(String)
    
    var category: ErrorCategory {
        switch self {
        case .dataModelValidationFailed, .dataModelCorrupted, .dataModelMigrationFailed, .dataModelRelationshipBroken:
            return .dataModel
        case .networkConnectionFailed, .networkTimeout, .networkDNSResolutionFailed, .networkUnauthorized, .networkServerError, .networkRateLimited:
            return .network
        case .aiProcessingFailed, .aiAPIKeyInvalid, .aiAPIKeyMissing, .aiResponseInvalid, .aiConfidenceTooLow, .aiParsingFailed:
            return .ai
        case .notificationPermissionDenied, .notificationSchedulingFailed, .notificationDeliveryFailed, .notificationSystemError:
            return .notification
        case .validationEmptyTitle, .validationInvalidDate, .validationInvalidRecurrence, .validationDataCorrupted:
            return .validation
        case .migrationSchemaIncompatible, .migrationDataLoss, .migrationBackupFailed, .migrationRestoreFailed:
            return .migration
        case .permissionNotificationDenied, .permissionCalendarDenied, .permissionLocationDenied:
            return .permission
        case .systemOutOfMemory, .systemDiskFull, .systemTimezoneChanged, .systemClockSkewed:
            return .system
        case .userInputInvalid, .userActionCancelled, .userQuotaExceeded:
            return .user
        case .unknown:
            return .unknown
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .dataModelCorrupted, .dataModelMigrationFailed, .migrationDataLoss, .systemOutOfMemory, .systemDiskFull:
            return .fatal
        case .dataModelRelationshipBroken, .networkServerError, .aiAPIKeyInvalid, .notificationSystemError, .migrationSchemaIncompatible:
            return .critical
        case .networkConnectionFailed, .networkTimeout, .aiProcessingFailed, .notificationDeliveryFailed, .validationInvalidRecurrence:
            return .error
        case .networkRateLimited, .aiConfidenceTooLow, .notificationPermissionDenied, .permissionNotificationDenied:
            return .warning
        case .userActionCancelled, .systemTimezoneChanged:
            return .info
        default:
            return .error
        }
    }
    
    var code: String {
        switch self {
        case .dataModelValidationFailed: return "DM001"
        case .dataModelCorrupted: return "DM002"
        case .dataModelMigrationFailed: return "DM003"
        case .dataModelRelationshipBroken: return "DM004"
        case .networkConnectionFailed: return "NW001"
        case .networkTimeout: return "NW002"
        case .networkDNSResolutionFailed: return "NW003"
        case .networkUnauthorized: return "NW004"
        case .networkServerError: return "NW005"
        case .networkRateLimited: return "NW006"
        case .aiProcessingFailed: return "AI001"
        case .aiAPIKeyInvalid: return "AI002"
        case .aiAPIKeyMissing: return "AI003"
        case .aiResponseInvalid: return "AI004"
        case .aiConfidenceTooLow: return "AI005"
        case .aiParsingFailed: return "AI006"
        case .notificationPermissionDenied: return "NOT001"
        case .notificationSchedulingFailed: return "NOT002"
        case .notificationDeliveryFailed: return "NOT003"
        case .notificationSystemError: return "NOT004"
        case .validationEmptyTitle: return "VAL001"
        case .validationInvalidDate: return "VAL002"
        case .validationInvalidRecurrence: return "VAL003"
        case .validationDataCorrupted: return "VAL004"
        case .migrationSchemaIncompatible: return "MIG001"
        case .migrationDataLoss: return "MIG002"
        case .migrationBackupFailed: return "MIG003"
        case .migrationRestoreFailed: return "MIG004"
        case .permissionNotificationDenied: return "PER001"
        case .permissionCalendarDenied: return "PER002"
        case .permissionLocationDenied: return "PER003"
        case .systemOutOfMemory: return "SYS001"
        case .systemDiskFull: return "SYS002"
        case .systemTimezoneChanged: return "SYS003"
        case .systemClockSkewed: return "SYS004"
        case .userInputInvalid: return "USR001"
        case .userActionCancelled: return "USR002"
        case .userQuotaExceeded: return "USR003"
        case .unknown: return "UNK001"
        }
    }
    
    var userMessage: String {
        switch self {
        case .dataModelCorrupted:
            return "Your data appears to be corrupted. The app will attempt to recover automatically."
        case .networkConnectionFailed:
            return "Unable to connect to the internet. Please check your connection and try again."
        case .networkTimeout:
            return "The request timed out. Please try again."
        case .aiAPIKeyInvalid:
            return "AI service configuration is invalid. Please check your settings."
        case .aiProcessingFailed:
            return "AI processing failed. Creating a simple task instead."
        case .notificationPermissionDenied:
            return "Notification permission is required for reminders. Please enable it in Settings."
        case .notificationDeliveryFailed:
            return "Failed to schedule reminder. Please try again."
        case .validationEmptyTitle:
            return "Task title cannot be empty."
        case .validationInvalidDate:
            return "Invalid date or time specified."
        case .migrationDataLoss:
            return "Data migration failed. Some data may be lost."
        case .systemOutOfMemory:
            return "The app is running low on memory. Please close other apps and try again."
        case .userInputInvalid:
            return "Invalid input. Please check your entry and try again."
        case .userActionCancelled:
            return "Action was cancelled."
        default:
            return "An unexpected error occurred. Please try again."
        }
    }
    
    var technicalMessage: String {
        switch self {
        case .dataModelValidationFailed(let details),
             .dataModelCorrupted(let details),
             .dataModelMigrationFailed(let details),
             .dataModelRelationshipBroken(let details),
             .networkConnectionFailed(let details),
             .networkTimeout(let details),
             .networkDNSResolutionFailed(let details),
             .networkUnauthorized(let details),
             .networkServerError(let details),
             .networkRateLimited(let details),
             .aiProcessingFailed(let details),
             .aiAPIKeyInvalid(let details),
             .aiAPIKeyMissing(let details),
             .aiResponseInvalid(let details),
             .aiConfidenceTooLow(let details),
             .aiParsingFailed(let details),
             .notificationPermissionDenied(let details),
             .notificationSchedulingFailed(let details),
             .notificationDeliveryFailed(let details),
             .notificationSystemError(let details),
             .validationEmptyTitle(let details),
             .validationInvalidDate(let details),
             .validationInvalidRecurrence(let details),
             .validationDataCorrupted(let details),
             .migrationSchemaIncompatible(let details),
             .migrationDataLoss(let details),
             .migrationBackupFailed(let details),
             .migrationRestoreFailed(let details),
             .permissionNotificationDenied(let details),
             .permissionCalendarDenied(let details),
             .permissionLocationDenied(let details),
             .systemOutOfMemory(let details),
             .systemDiskFull(let details),
             .systemTimezoneChanged(let details),
             .systemClockSkewed(let details),
             .userInputInvalid(let details),
             .userActionCancelled(let details),
             .userQuotaExceeded(let details),
             .unknown(let details):
            return details
        }
    }
    
    var recoveryStrategy: RecoveryStrategy {
        switch self {
        case .networkConnectionFailed, .networkTimeout, .aiProcessingFailed, .notificationDeliveryFailed:
            return .retry(maxAttempts: 3)
        case .aiAPIKeyInvalid, .aiAPIKeyMissing:
            return .userIntervention(message: "Please configure your AI API key in Settings")
        case .notificationPermissionDenied, .permissionNotificationDenied:
            return .userIntervention(message: "Please enable notifications in Settings")
        case .dataModelCorrupted, .migrationDataLoss:
            return .fallback { /* Implement data recovery */ }
        case .systemOutOfMemory:
            return .gracefulDegradation
        case .dataModelMigrationFailed:
            return .restart
        case .userActionCancelled:
            return .none
        default:
            return .retry(maxAttempts: 1)
        }
    }
    
    var context: [String: Any] {
        return [
            "timestamp": timestamp,
            "category": category.rawValue,
            "severity": severity.rawValue,
            "code": code
        ]
    }
    
    var timestamp: Date {
        return Date()
    }
    
    var canRetry: Bool {
        switch self {
        case .networkConnectionFailed, .networkTimeout, .aiProcessingFailed, .notificationDeliveryFailed:
            return true
        case .userActionCancelled, .dataModelCorrupted, .migrationDataLoss:
            return false
        default:
            return true
        }
    }
    
    var shouldLog: Bool {
        switch self {
        case .userActionCancelled:
            return false
        default:
            return true
        }
    }
    
    var shouldNotifyUser: Bool {
        switch self {
        case .systemTimezoneChanged:
            return false
        default:
            return severity.rawValue >= ErrorSeverity.warning.rawValue
        }
    }
}

// MARK: - Error Handler
@MainActor
final class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var currentError: EnhancedError?
    @Published var errorHistory: [EnhancedError] = []
    @Published var isShowingError = false
    
    private let logger = Logger(subsystem: "com.todoai.app", category: "ErrorHandler")
    private var retryAttempts: [String: Int] = [:]
    
    private init() {}
    
    // MARK: - Error Handling
    func handle(_ error: EnhancedError) {
        if error.shouldLog {
            logError(error)
        }
        
        addToHistory(error)
        
        if error.shouldNotifyUser {
            currentError = error
            isShowingError = true
        }
        
        handleRecovery(error)
    }
    
    func handle(_ error: Error) {
        let enhancedError = convertToEnhancedError(error)
        handle(enhancedError)
    }
    
    // MARK: - Recovery Handling
    private func handleRecovery(_ error: EnhancedError) {
        switch error.recoveryStrategy {
        case .none:
            break
        case .retry(let maxAttempts):
            handleRetry(error, maxAttempts: maxAttempts)
        case .fallback(let action):
            action()
        case .userIntervention(let message):
            // Show user intervention UI
            logger.info("User intervention required: \(message)")
        case .gracefulDegradation:
            handleGracefulDegradation()
        case .restart:
            handleRestart()
        }
    }
    
    private func handleRetry(_ error: EnhancedError, maxAttempts: Int) {
        let attempts = retryAttempts[error.code] ?? 0
        
        if attempts < maxAttempts {
            retryAttempts[error.code] = attempts + 1
            logger.info("Retrying operation for error \(error.code), attempt \(attempts + 1)/\(maxAttempts)")
            
            // Implement retry logic here
            // This would typically involve re-executing the failed operation
        } else {
            logger.error("Max retry attempts reached for error \(error.code)")
            retryAttempts[error.code] = nil
        }
    }
    
    private func handleGracefulDegradation() {
        logger.info("Entering graceful degradation mode")
        // Implement graceful degradation
        // - Reduce memory usage
        // - Disable non-essential features
        // - Switch to simplified UI
    }
    
    private func handleRestart() {
        logger.critical("Application restart required")
        // Implement restart logic
        // - Save current state
        // - Show restart dialog
        // - Perform restart
    }
    
    // MARK: - Error Conversion
    private func convertToEnhancedError(_ error: Error) -> EnhancedError {
        if let enhancedError = error as? EnhancedError {
            return enhancedError
        }
        
        // Convert URLError to enhanced error
        if let urlError = error as? URLError {
            return convertURLError(urlError)
        }
        
        // Convert SwiftData errors
        if let swiftDataError = error as? SwiftDataError {
            return convertSwiftDataError(swiftDataError)
        }
        
        // Default unknown error
        return TodoAppError.unknown(error.localizedDescription)
    }
    
    private func convertURLError(_ urlError: URLError) -> EnhancedError {
        switch urlError.code {
        case .notConnectedToInternet:
            return TodoAppError.networkConnectionFailed("No internet connection: \(urlError.localizedDescription)")
        case .timedOut:
            return TodoAppError.networkTimeout("Request timed out: \(urlError.localizedDescription)")
        case .cannotFindHost:
            return TodoAppError.networkDNSResolutionFailed("Cannot find host: \(urlError.localizedDescription)")
        case .cannotConnectToHost:
            return TodoAppError.networkConnectionFailed("Cannot connect to host: \(urlError.localizedDescription)")
        default:
            return TodoAppError.networkConnectionFailed("Network error: \(urlError.localizedDescription)")
        }
    }
    
    private func convertSwiftDataError(_ swiftDataError: SwiftDataError) -> EnhancedError {
        switch swiftDataError {
        case .loadIssueModelContainer:
            return TodoAppError.dataModelCorrupted("Failed to load model container: \(swiftDataError.localizedDescription)")
        default:
            return TodoAppError.dataModelValidationFailed("SwiftData error: \(swiftDataError.localizedDescription)")
        }
    }
    
    // MARK: - Logging
    private func logError(_ error: EnhancedError) {
        let logMessage = "[\(error.code)] \(error.severity.emoji) \(error.category.rawValue.uppercased()): \(error.technicalMessage)"
        
        switch error.severity {
        case .info:
            logger.info("\(logMessage)")
        case .warning:
            logger.warning("\(logMessage)")
        case .error:
            logger.error("\(logMessage)")
        case .critical:
            logger.critical("\(logMessage)")
        case .fatal:
            logger.fault("\(logMessage)")
        }
    }
    
    // MARK: - History Management
    private func addToHistory(_ error: EnhancedError) {
        errorHistory.append(error)
        
        // Keep only last 100 errors
        if errorHistory.count > 100 {
            errorHistory.removeFirst()
        }
    }
    
    // MARK: - Public Methods
    func clearCurrentError() {
        currentError = nil
        isShowingError = false
    }
    
    func clearHistory() {
        errorHistory.removeAll()
    }
    
    func getErrorsOfCategory(_ category: ErrorCategory) -> [EnhancedError] {
        return errorHistory.filter { $0.category == category }
    }
    
    func getErrorsOfSeverity(_ severity: ErrorSeverity) -> [EnhancedError] {
        return errorHistory.filter { $0.severity == severity }
    }
    
    func getRecentErrors(limit: Int = 10) -> [EnhancedError] {
        return Array(errorHistory.suffix(limit))
    }
} 