//
//  StructuredLogger.swift
//  todoai
//
//  Created by AI Assistant on 1/4/25.
//

import Foundation
import os.log

// MARK: - Log Level
enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var osLogType: OSLogType {
        switch self {
        case .debug:
            return .debug
        case .info:
            return .info
        case .warning:
            return .default
        case .error:
            return .error
        case .critical:
            return .fault
        }
    }
}

// MARK: - Structured Logger
@MainActor
class StructuredLogger: ObservableObject {
    static let shared = StructuredLogger()
    
    private let logger = Logger(subsystem: "com.todoai.app", category: "general")
    
    @Published var logLevel: LogLevel = .info
    @Published var isLoggingEnabled = true
    
    private init() {
        // Configure logging based on build configuration
        #if DEBUG
        logLevel = .debug
        #else
        logLevel = .info
        #endif
    }
    
    // MARK: - Public Logging Methods
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var logMessage = message
        if let error = error {
            logMessage += " - Error: \(error.localizedDescription)"
        }
        log(level: .error, message: logMessage, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var logMessage = message
        if let error = error {
            logMessage += " - Error: \(error.localizedDescription)"
        }
        log(level: .critical, message: logMessage, file: file, function: function, line: line)
    }
    
    // MARK: - Private Implementation
    
    private func log(level: LogLevel, message: String, file: String, function: String, line: Int) {
        guard isLoggingEnabled else { return }
        guard shouldLog(level: level) else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        switch level {
        case .debug:
            logger.debug("\(formattedMessage)")
        case .info:
            logger.info("\(formattedMessage)")
        case .warning:
            logger.warning("\(formattedMessage)")
        case .error:
            logger.error("\(formattedMessage)")
        case .critical:
            logger.critical("\(formattedMessage)")
        }
        
        // Also print to console in debug builds
        #if DEBUG
        print("[\(level.rawValue)] \(formattedMessage)")
        #endif
    }
    
    private func shouldLog(level: LogLevel) -> Bool {
        return level.osLogType.rawValue >= logLevel.osLogType.rawValue
    }
    
    // MARK: - Configuration
    
    func setLogLevel(_ level: LogLevel) {
        logLevel = level
        info("Log level changed to \(level.rawValue)")
    }
    
    func enableLogging(_ enabled: Bool) {
        isLoggingEnabled = enabled
        if enabled {
            info("Logging enabled")
        }
    }
}

// MARK: - Convenience Extensions
extension StructuredLogger {
    
    /// Log a task operation
    func logTask(_ operation: String, taskTitle: String, success: Bool = true) {
        if success {
            info("Task \(operation): \(taskTitle)")
        } else {
            error("Failed to \(operation) task: \(taskTitle)")
        }
    }
    
    /// Log a notification operation
    func logNotification(_ operation: String, success: Bool = true, details: String? = nil) {
        let message = "Notification \(operation)" + (details.map { " - \($0)" } ?? "")
        if success {
            info(message)
        } else {
            error(message)
        }
    }
    
    /// Log a schedule operation
    func logSchedule(_ operation: String, taskTitle: String, date: Date? = nil, success: Bool = true) {
        var message = "Schedule \(operation): \(taskTitle)"
        if let date = date {
            message += " at \(date.formatted(.dateTime))"
        }
        
        if success {
            info(message)
        } else {
            error(message)
        }
    }
} 