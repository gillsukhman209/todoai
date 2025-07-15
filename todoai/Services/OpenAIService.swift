import Foundation
import OSLog

// MARK: - OpenAI Service
@MainActor
final class OpenAIService: ObservableObject {
    private let apiKey: String
    private let logger = Logger(subsystem: "com.todoai.app", category: "OpenAIService")
    
    init(apiKey: String = "") {
        // Read API key from UserDefaults - no hardcoded key
        if !apiKey.isEmpty {
            self.apiKey = apiKey
        } else {
            self.apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        }
        logger.info("🔑 OpenAI Service initialized with API key: \(self.apiKey.isEmpty ? "NOT SET" : "SET (\(self.apiKey.prefix(10))...)")")
    }
    
    // MARK: - Natural Language Task Parsing
    func parseTask(_ input: String) async throws -> ParsedTaskData {
        logger.info("🚀 Starting task parsing for input: '\(input)'")
        
        // Validate API key first
        guard !apiKey.isEmpty else {
            logger.error("❌ API key is empty")
            throw OpenAIError.missingAPIKey
        }
        
        guard apiKey.hasPrefix("sk-") else {
            logger.error("❌ API key format is invalid (doesn't start with 'sk-')")
            throw OpenAIError.invalidAPIKey
        }
        
        logger.info("✅ API key validation passed")
        
        let prompt = createTaskParsingPrompt(for: input)
        logger.info("📝 Generated prompt for OpenAI")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": prompt
                ],
                [
                    "role": "user",
                    "content": input
                ]
            ],
            "temperature": 0.1,
            "max_tokens": 500
        ]
        
        logger.info("📦 Prepared request body with \(requestBody.count) fields")
        
        let response = try await makeAPIRequest(requestBody: requestBody)
        
        logger.info("🔍 Parsing OpenAI response...")
        
        guard let content = response["choices"] as? [[String: Any]],
              let firstChoice = content.first,
              let message = firstChoice["message"] as? [String: Any],
              let jsonString = message["content"] as? String else {
            logger.error("❌ Invalid response structure from OpenAI")
            logger.error("❌ Response keys: \(response.keys)")
            throw OpenAIError.invalidResponse
        }
        
        logger.info("✅ Extracted content from OpenAI response")
        logger.info("📄 Raw AI response: \(jsonString)")
        
        // Strip markdown code blocks if present
        let cleanedJsonString = jsonString
            .replacingOccurrences(of: "```json\n", with: "")
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "\n```", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        logger.info("🧹 Cleaned JSON string: \(cleanedJsonString)")
        
        // Parse the JSON response
        guard let jsonData = cleanedJsonString.data(using: .utf8) else {
            logger.error("❌ Failed to convert string to data")
            throw OpenAIError.invalidJSON
        }
        
        logger.info("✅ Converted response to JSON data")
        
        do {
            let parsedData = try JSONDecoder().decode(ParsedTaskData.self, from: jsonData)
            logger.info("🎉 Successfully parsed task: '\(input)' -> '\(parsedData.cleanTitle)'")
            return parsedData
        } catch {
            logger.error("❌ Failed to decode JSON: \(error.localizedDescription)")
            logger.error("❌ Cleaned JSON: \(cleanedJsonString)")
            throw OpenAIError.invalidJSON
        }
    }
    
    // MARK: - Private Methods
    private func makeAPIRequest(requestBody: [String: Any]) async throws -> [String: Any] {
        logger.info("🌐 Making API request to OpenAI")
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            logger.error("❌ Failed to create URL")
            throw OpenAIError.invalidURL
        }
        
        logger.info("✅ URL created successfully: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        logger.info("📋 Request headers configured (timeout: 30s)")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            logger.info("✅ Request body serialized successfully")
        } catch {
            logger.error("❌ Failed to serialize request body: \(error)")
            throw OpenAIError.requestSerializationFailed
        }
        
        logger.info("📡 Starting network request to OpenAI...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            logger.info("✅ Network request completed successfully")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("❌ Invalid HTTP response received")
                throw OpenAIError.invalidResponse
            }
            
            logger.info("📊 HTTP Response Status: \(httpResponse.statusCode)")
            logger.info("📊 Response Headers: \(httpResponse.allHeaderFields)")
            
            guard httpResponse.statusCode == 200 else {
                logger.error("❌ API request failed with status code: \(httpResponse.statusCode)")
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    logger.error("❌ Error response: \(errorData)")
                }
                if let errorString = String(data: data, encoding: .utf8) {
                    logger.error("❌ Raw error response: \(errorString)")
                }
                
                switch httpResponse.statusCode {
                case 401:
                    logger.error("❌ Authentication failed - Invalid API key")
                    throw OpenAIError.invalidAPIKey
                case 429:
                    logger.error("❌ Rate limit exceeded")
                    throw OpenAIError.rateLimitExceeded
                case 500...599:
                    logger.error("❌ Server error")
                    throw OpenAIError.serverError
                default:
                    logger.error("❌ API request failed with unknown status code")
                    throw OpenAIError.apiRequestFailed(httpResponse.statusCode)
                }
            }
            
            logger.info("✅ HTTP 200 response received")
            logger.info("📏 Response data size: \(data.count) bytes")
            
            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logger.error("❌ Failed to parse JSON response")
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.error("❌ Raw response: \(responseString)")
                }
                throw OpenAIError.invalidResponse
            }
            
            logger.info("✅ JSON response parsed successfully")
            return jsonResponse
        } catch let error as URLError {
            logger.error("🚨 URLError occurred: \(error.localizedDescription)")
            logger.error("🚨 URLError code: \(error.code.rawValue)")
            logger.error("🚨 URLError domain: \((error as NSError).domain)")
            logger.error("🚨 URLError userInfo: \(error.userInfo)")
            
            switch error.code {
            case .notConnectedToInternet:
                logger.error("🚨 No internet connection detected")
                throw OpenAIError.noInternetConnection
            case .timedOut:
                logger.error("🚨 Request timed out")
                throw OpenAIError.requestTimeout
            case .cannotFindHost:
                logger.error("🚨 Cannot find host (DNS issue)")
                throw OpenAIError.cannotFindHost
            case .cannotConnectToHost:
                logger.error("🚨 Cannot connect to host")
                throw OpenAIError.networkError("Cannot connect to OpenAI servers")
            case .networkConnectionLost:
                logger.error("🚨 Network connection lost")
                throw OpenAIError.networkError("Network connection lost")
            case .dnsLookupFailed:
                logger.error("🚨 DNS lookup failed")
                throw OpenAIError.networkError("DNS lookup failed")
            case .httpTooManyRedirects:
                logger.error("🚨 Too many redirects")
                throw OpenAIError.networkError("Too many redirects")
            case .secureConnectionFailed:
                logger.error("🚨 Secure connection failed")
                throw OpenAIError.networkError("Secure connection failed")
            default:
                logger.error("🚨 Unknown network error: \(error.localizedDescription)")
                throw OpenAIError.networkError(error.localizedDescription)
            }
        } catch {
            logger.error("🚨 Unexpected error: \(error)")
            logger.error("🚨 Error type: \(type(of: error))")
            throw OpenAIError.networkError("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    private func createTaskParsingPrompt(for input: String) -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        formatter.timeZone = TimeZone.current
        let currentDateTime = formatter.string(from: now)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        timeFormatter.timeZone = TimeZone.current
        let currentTime = timeFormatter.string(from: now)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        dateFormatter.timeZone = TimeZone.current
        let currentDate = dateFormatter.string(from: now)
        
        return """
        You are a task parsing assistant. Parse natural language task input into structured JSON data.

        CURRENT DATE/TIME: \(currentDateTime)
        CURRENT TIME: \(currentTime)
        CURRENT DATE: \(currentDate)

        Your job is to extract:
        1. A clean task title (remove time/recurrence information)
        2. Due date/time for one-time tasks (including relative time calculations)
        3. Recurrence patterns for repeating tasks
        4. Time constraints and ranges

        RELATIVE TIME HANDLING:
        - "in 5 minutes" → calculate exact time 5 minutes from now
        - "in 30 minutes" → calculate exact time 30 minutes from now
        - "in an hour" → calculate exact time 1 hour from now
        - "in 2 hours" → calculate exact time 2 hours from now
        - "in 2mins" → calculate exact time 2 minutes from now
        - "in 5mins" → calculate exact time 5 minutes from now
        - "in 10mins" → calculate exact time 10 minutes from now
        - "in 1min" → calculate exact time 1 minute from now
        - "in 30sec" → calculate exact time 30 seconds from now
        - "in 1hr" → calculate exact time 1 hour from now
        - "in 2hrs" → calculate exact time 2 hours from now
        - "in 3hrs" → calculate exact time 3 hours from now
        - "tomorrow" → next day at reasonable time or specified time
        - "next week" → 7 days from now
        - "next Monday" → the upcoming Monday
        - "next Tuesday" → the upcoming Tuesday
        - "tonight" → today at evening time (7-9 PM)
        - "this morning" → today at morning time (8-10 AM)
        - "this afternoon" → today at afternoon time (1-3 PM)
        - "this evening" → today at evening time (6-8 PM)
        - "later today" → today at a reasonable future time
        - "later" → in a few hours from now
        - "soon" → in 30 minutes to 1 hour from now
        - "Monday" (if today is Wednesday) → next Monday
        - "Friday" (if today is Tuesday) → this Friday

        RECURRENCE TYPES:
        - "none": One-time task
        - "daily": Every day
        - "weekly": Every week
        - "monthly": Every month  
        - "yearly": Every year
        - "hourly": Every hour
        - "custom_interval": Custom intervals (every X hours/days)
        - "specific_days": Specific weekdays (Mon, Wed, Fri)
        - "multiple_daily_times": Multiple times per day

        EXAMPLES:

        CRITICAL: For relative time expressions, you MUST calculate the actual time/date values. DO NOT return placeholders like "[CALCULATE: ...]". Calculate the actual time based on the current date/time provided above.

        Example calculations:
        - If current time is 2:30 PM and user says "in 30 minutes", return "3:00 PM"
        - If current time is 10:15 AM and user says "in 2 hours", return "12:15 PM"
        - If current time is 5:45 PM and user says "in 15 minutes", return "6:00 PM"

        Input: "remind me in 30 minutes to take out the trash"
        Output: {"cleanTitle": "take out the trash", "dueDate": null, "dueTime": "3:00 PM", "recurrenceType": "none", "interval": null, "specificWeekdays": null, "specificTimes": null, "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "One-time reminder to take out the trash in 30 minutes"}

        Input: "remind me in an hour to check my email"
        Output: {"cleanTitle": "check my email", "dueDate": null, "dueTime": "3:30 PM", "recurrenceType": "none", "interval": null, "specificWeekdays": null, "specificTimes": null, "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "One-time reminder to check email in 1 hour"}

        Input: "remind me soon to call the dentist"
        Output: {"cleanTitle": "call the dentist", "dueDate": null, "dueTime": "3:15 PM", "recurrenceType": "none", "interval": null, "specificWeekdays": null, "specificTimes": null, "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "One-time reminder to call the dentist soon"}

        Input: "remind me later to review my presentation"
        Output: {"cleanTitle": "review my presentation", "dueDate": null, "dueTime": "5:30 PM", "recurrenceType": "none", "interval": null, "specificWeekdays": null, "specificTimes": null, "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "One-time reminder to review presentation later today"}

        Input: "remind me next Monday to submit my report"
        Output: {"cleanTitle": "submit my report", "dueDate": "2025-07-21", "dueTime": "9:00 AM", "recurrenceType": "none", "interval": null, "specificWeekdays": null, "specificTimes": null, "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "One-time reminder to submit report next Monday"}

        Input: "remind me in 5 minutes to go for a walk"
        Output: {"cleanTitle": "go for a walk", "dueDate": null, "dueTime": "2:35 PM", "recurrenceType": "none", "interval": null, "specificWeekdays": null, "specificTimes": null, "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "One-time reminder to go for a walk in 5 minutes"}

        Input: "remind me in 2mins to drink water"
        Output: {"cleanTitle": "drink water", "dueDate": null, "dueTime": "2:32 PM", "recurrenceType": "none", "interval": null, "specificWeekdays": null, "specificTimes": null, "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "One-time reminder to drink water in 2 minutes"}

        Input: "remind me in 1hr to check email"
        Output: {"cleanTitle": "check email", "dueDate": null, "dueTime": "3:30 PM", "recurrenceType": "none", "interval": null, "specificWeekdays": null, "specificTimes": null, "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "One-time reminder to check email in 1 hour"}

        Input: "remind me in 2 hours to check on the laundry"
        Output: {"cleanTitle": "check on the laundry", "dueDate": null, "dueTime": "4:30 PM", "recurrenceType": "none", "interval": null, "specificWeekdays": null, "specificTimes": null, "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "One-time reminder to check on laundry in 2 hours"}

        Input: "remind me tomorrow at 9am to call mom"
        Output: {"cleanTitle": "call mom", "dueDate": "2025-07-16", "dueTime": "9:00 AM", "recurrenceType": "none", "interval": null, "specificWeekdays": null, "specificTimes": null, "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "One-time reminder to call mom tomorrow at 9 AM"}

        Input: "remind me tonight to lock the door"
        Output: {"cleanTitle": "lock the door", "dueDate": null, "dueTime": "8:00 PM", "recurrenceType": "none", "interval": null, "specificWeekdays": null, "specificTimes": null, "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "One-time reminder to lock the door tonight"}

        Input: "remind me this afternoon to water the plants"
        Output: {"cleanTitle": "water the plants", "dueDate": null, "dueTime": "2:00 PM", "recurrenceType": "none", "interval": null, "specificWeekdays": null, "specificTimes": null, "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "One-time reminder to water the plants this afternoon"}

        Input: "call dad at 6am"
        Output: {"cleanTitle": "call dad", "dueDate": null, "dueTime": "6:00 AM", "recurrenceType": "none", "interval": null, "specificWeekdays": null, "specificTimes": null, "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "One-time task to call dad at 6 AM"}

        Input: "pay PGE every Friday at 10am"
        Output: {"cleanTitle": "pay PGE", "dueDate": null, "dueTime": null, "recurrenceType": "specific_days", "interval": null, "specificWeekdays": ["friday"], "specificTimes": ["10:00 AM"], "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "Weekly task to pay PGE every Friday at 10 AM"}

        Input: "submit the report monthly on the 1st at 9am"
        Output: {"cleanTitle": "submit the report", "dueDate": null, "dueTime": null, "recurrenceType": "monthly", "interval": null, "specificWeekdays": null, "specificTimes": ["9:00 AM"], "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": 1, "description": "Monthly task to submit report on the 1st at 9 AM"}

        Input: "stretch every 2 hours from 8am to 8pm"
        Output: {"cleanTitle": "stretch", "dueDate": null, "dueTime": null, "recurrenceType": "custom_interval", "interval": 2, "specificWeekdays": null, "specificTimes": null, "timeRangeStart": "8:00 AM", "timeRangeEnd": "8:00 PM", "monthlyDay": null, "description": "Recurring task to stretch every 2 hours between 8 AM and 8 PM"}

        Input: "workout every Mon, Wed, Fri at 7pm"
        Output: {"cleanTitle": "workout", "dueDate": null, "dueTime": null, "recurrenceType": "specific_days", "interval": null, "specificWeekdays": ["monday", "wednesday", "friday"], "specificTimes": ["7:00 PM"], "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "Weekly workouts on Monday, Wednesday, and Friday at 7 PM"}

        Input: "remind me to check crypto prices at 10am and 6pm every day"
        Output: {"cleanTitle": "check crypto prices", "dueDate": null, "dueTime": null, "recurrenceType": "multiple_daily_times", "interval": null, "specificWeekdays": null, "specificTimes": ["10:00 AM", "6:00 PM"], "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "Daily reminders to check crypto prices at 10 AM and 6 PM"}

        Input: "journal every night at 9pm"
        Output: {"cleanTitle": "journal", "dueDate": null, "dueTime": null, "recurrenceType": "daily", "interval": null, "specificWeekdays": null, "specificTimes": ["9:00 PM"], "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "Daily journaling every night at 9 PM"}

        Input: "take vitamins every morning"
        Output: {"cleanTitle": "take vitamins", "dueDate": null, "dueTime": null, "recurrenceType": "daily", "interval": null, "specificWeekdays": null, "specificTimes": null, "timeRangeStart": null, "timeRangeEnd": null, "monthlyDay": null, "description": "Daily task to take vitamins in the morning"}

        Input: "drink water every 30 minutes from 9am to 5pm"
        Output: {"cleanTitle": "drink water", "dueDate": null, "dueTime": null, "recurrenceType": "custom_interval", "interval": 30, "specificWeekdays": null, "specificTimes": null, "timeRangeStart": "9:00 AM", "timeRangeEnd": "5:00 PM", "monthlyDay": null, "description": "Drink water every 30 minutes during work hours (9 AM to 5 PM)"}

        IMPORTANT:
        - Always return valid JSON
        - Use 12-hour time format (10:00 AM, 6:30 PM)
        - Weekdays should be lowercase full names (monday, tuesday, etc.)
        - For custom intervals with minutes, use interval in minutes
        - For custom intervals with hours, use interval in hours
        - Clean titles should not contain time or recurrence information
        - Always include a helpful description
        - For relative time expressions, calculate the exact time based on current time
        - For relative dates, calculate the exact date based on current date
        - When time is ambiguous, use reasonable defaults (morning: 9 AM, afternoon: 2 PM, evening: 7 PM, night: 8 PM)
        - NEVER return placeholder text like "[CALCULATE: ...]" - always return actual calculated values
        - For dates, use YYYY-MM-DD format (e.g., "2025-07-16")
        - For times, use 12-hour format with AM/PM (e.g., "3:30 PM")

        Return ONLY the JSON object, no other text.
        """
    }
}

// MARK: - Error Types
enum OpenAIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidJSON
    case requestSerializationFailed
    case apiRequestFailed(Int)
    case missingAPIKey
    case invalidAPIKey
    case rateLimitExceeded
    case serverError
    case noInternetConnection
    case requestTimeout
    case cannotFindHost
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .invalidJSON:
            return "Invalid JSON in response"
        case .requestSerializationFailed:
            return "Failed to serialize request"
        case .apiRequestFailed(let statusCode):
            return "API request failed with status code: \(statusCode)"
        case .missingAPIKey:
            return "OpenAI API key is missing. Please set it in Settings."
        case .invalidAPIKey:
            return "Invalid OpenAI API key. Please check your key in Settings."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .serverError:
            return "OpenAI server error. Please try again later."
        case .noInternetConnection:
            return "No internet connection. Please check your network."
        case .requestTimeout:
            return "Request timed out. Please try again."
        case .cannotFindHost:
            return "Cannot connect to OpenAI servers. Please check your internet connection."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
} 