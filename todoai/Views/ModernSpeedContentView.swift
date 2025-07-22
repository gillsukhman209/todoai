//
//  ModernSpeedContentView.swift
//  todoai
//
//  COMPLETELY REDESIGNED - Modern, Speed-Focused Interface
//  Inspired by Linear, Notion, Arc Browser - Built for 2025
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

struct ModernSpeedContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [Todo]
    @State private var currentMonth = Date()
    @State private var quickInput = ""
    @State private var selectedDate = Date()
    @State private var currentView: SpeedView = .today
    @StateObject private var taskCreationViewModel: TaskCreationViewModel
    
    init() {
        let openAIService = OpenAIService()
        // Create temporary context for initialization - will be updated in onAppear
        let tempContainer = try! ModelContainer(for: Schema([Todo.self]), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        self._taskCreationViewModel = StateObject(wrappedValue: TaskCreationViewModel(openAIService: openAIService, modelContext: tempContainer.mainContext))
    }
    @FocusState private var isInputFocused: Bool
    
    // Smart suggestions
    @State private var suggestions: [String] = []
    @State private var selectedSuggestionIndex = -1
    
    // Performance optimization: cache for todo filtering
    @State private var todoCache: [String: [Todo]] = [:]
    
    // Safety system for keyboard shortcuts
    private var isAnyTextInputActive: Bool {
        // Check main input focus
        if isInputFocused { return true }
        
        // Check if quickInput has content (user might be typing)
        if !quickInput.isEmpty { return true }
        
        // TODO: Add checks for other text input states when implementing inline editing
        // - Check editing states from other views
        // - Check modal text inputs
        // - Check system text selection
        
        return false
    }
    
    // Common task suggestions
    private let commonTasks = [
        "Buy groceries", "Exercise for 30 minutes", "Call dentist", "Pay bills",
        "Clean room", "Study for exam", "Walk the dog", "Water plants",
        "Do laundry", "Schedule doctor appointment", "Reply to emails",
        "Read book", "Meditate", "Cook dinner", "Organize desk", "Backup files",
        "Team meeting", "Code review", "Deploy app", "Write documentation",
        "Plan vacation", "Book flight", "Gym session", "Meal prep"
    ]
    
    enum SpeedView: String, CaseIterable {
        case calendar = "Calendar"
        case today = "Today"
        case upcoming = "Upcoming" 
        case all = "All"
        
        var icon: String {
            switch self {
            case .calendar: return "calendar"
            case .today: return "calendar.badge.clock"
            case .upcoming: return "arrow.up.right"
            case .all: return "list.bullet"
            }
        }
    }
    
    private var todayTodos: [Todo] {
        let today = Date()
        return todos.filter { todo in
            shouldTodoAppearOnDate(todo, date: today)
        }.sorted(by: { !$0.isCompleted && $1.isCompleted })
    }
    
    private var upcomingTodos: [Todo] {
        let calendar = Calendar.current
        let today = Date()
        
        return todos.filter { todo in
            // Check each day in the next week
            for dayOffset in 1...7 {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: today),
                   shouldTodoAppearOnDate(todo, date: date) {
                    return true
                }
            }
            return false
        }.sorted(by: { !$0.isCompleted && $1.isCompleted })
    }
    
    private var displayTodos: [Todo] {
        switch currentView {
        case .calendar: return todos // All todos for calendar view
        case .today: return todayTodos
        case .upcoming: return upcomingTodos
        case .all: return todos.sorted(by: { !$0.isCompleted && $1.isCompleted })
        }
    }
    
    /// Get todos for a specific date (used by calendar view) - memoized for performance
    private func todosForDate(_ date: Date) -> [Todo] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let cacheKey = "\(dateFormatter.string(from: date))-\(todos.count)-\(todos.hashValue)"
        
        // Check cache first
        if let cachedTodos = todoCache[cacheKey] {
            return cachedTodos
        }
        
        // Calculate and cache result
        let result = todos.filter { todo in
            shouldTodoAppearOnDate(todo, date: date)
        }.sorted(by: { !$0.isCompleted && $1.isCompleted })
        
        todoCache[cacheKey] = result
        
        // Clean cache if it gets too big
        if todoCache.count > 50 {
            todoCache.removeAll()
        }
        
        return result
    }
    
    // MARK: - Persistence Helpers
    
    /// Save the model context with error handling
    private func saveContext() {
        do {
            try modelContext.save()
            print("✅ Successfully saved model context")
        } catch {
            print("❌ Failed to save model context: \(error.localizedDescription)")
        }
    }
    
    /// Save context whenever a todo is modified
    private func saveTodoChanges() {
        saveContext()
    }
    
    /// Verify database status and log todo count
    private func verifyDatabaseStatus() {
        print("📊 Database Status:")
        print("  - Total todos loaded: \(todos.count)")
        print("  - Database location: \(getDatabasePath())")
        
        if todos.isEmpty {
            print("⚠️ No todos found - this might be a new install or data loss")
        } else {
            print("✅ Successfully loaded \(todos.count) todos from database")
            
            // Log some sample todos for verification
            let sampleCount = min(3, todos.count)
            for (index, todo) in todos.prefix(sampleCount).enumerated() {
                print("  \(index + 1). \(todo.title) (created: \(todo.createdAt.formatted()))")
            }
            
            if todos.count > 3 {
                print("  ... and \(todos.count - 3) more")
            }
        }
    }
    
    /// Get the database file path for debugging
    private func getDatabasePath() -> String {
        let appSupportURL = URL.applicationSupportDirectory.appendingPathComponent("TodoAI")
        let dbURL = appSupportURL.appendingPathComponent("TodoDatabase.sqlite")
        return dbURL.path
    }
    
    var body: some View {
        ZStack {
            // Ultra-clean background
            Rectangle()
                .fill(Color.black)
                .ignoresSafeArea()
                .onTapGesture {
                    // Unfocus input when clicking on background
                    isInputFocused = false
                }
            
            // Main speed-focused layout
            VStack(spacing: 0) {
                // Modern header
                modernHeader
                
                // Content area - Calendar or Todo List
                if currentView == .calendar {
                    modernCalendarView
                } else {
                    speedTodoList
                }
                
                // Lightning-fast input
                lightningInput
            }
        }
        .preferredColorScheme(.dark)
        .focusEffectDisabled()
        .focusable(currentView == .calendar)
        .onKeyPress { keyPress in
            return handleGlobalKeyPress(keyPress)
        }
        .onAppear {
            // Set the model context for AI task creation
            taskCreationViewModel.updateModelContext(modelContext)
            taskCreationViewModel.updateSelectedDate(selectedDate)
            
            // Force save any pending changes on app startup
            saveContext()
            
            // Verify database status and log diagnostics
            verifyDatabaseStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusTaskInput)) { _ in
            // Handle Command+N from menu
            isInputFocused = true
            if currentView != .today {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    currentView = .today
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showTodayView)) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentView = .today
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showUpcomingView)) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentView = .upcoming
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCalendarView)) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentView = .calendar
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAllView)) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentView = .all
            }
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            // Only update selected date in task creation when in calendar view
            if currentView == .calendar {
                taskCreationViewModel.updateSelectedDate(newValue)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            // Save data when app goes to background
            saveContext()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            // Save data when app is about to terminate
            saveContext()
        }
    }
    
    // MARK: - Modern Header
    private var modernHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentView.rawValue)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Show selected date when in calendar mode
                    if currentView == .calendar && !Calendar.current.isDate(selectedDate, inSameDayAs: Date()) {
                        Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.cyan.opacity(0.8))
                    }
                }
                
                HStack(spacing: 12) {
                    Text("\(displayTodos.filter { !$0.isCompleted }.count)")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    Text("active")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    if displayTodos.contains(where: \.isCompleted) {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 3, height: 3)
                        
                        Text("\(displayTodos.filter(\.isCompleted).count)")
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(.green)
                        
                        Text("done")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            
            Spacer()
            
            // View switcher
            HStack(spacing: 8) {
                ForEach(SpeedView.allCases, id: \.self) { view in
                    speedViewButton(for: view)
                }
                
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    private func speedViewButton(for view: SpeedView) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentView = view
                // Reset selected date to today when leaving calendar view
                if view != .calendar {
                    selectedDate = Date()
                    taskCreationViewModel.updateSelectedDate(Date())
                }
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: view.icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(view.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                
                // Keyboard shortcut hint
                Text(keyboardShortcutHint(for: view))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(currentView == view ? .black.opacity(0.5) : .white.opacity(0.5))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.1))
                    )
            }
            .foregroundColor(currentView == view ? .black : .white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(currentView == view ? .cyan : .white.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(currentView == view ? .clear : .white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func keyboardShortcutHint(for view: SpeedView) -> String {
        switch view {
        case .today: return "T"
        case .upcoming: return "U"
        case .calendar: return "C"
        case .all: return "A"
        }
    }
    
    // MARK: - Modern Calendar View
    private var modernCalendarView: some View {
        VStack(spacing: 0) {
            // Month navigation
            HStack {
                Button(action: { 
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.1))
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(currentMonth.formatted(.dateTime.month(.wide)))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(currentMonth.formatted(.dateTime.year()))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Button(action: { 
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.1))
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            // Calendar content with modern wrapper
            ModernCalendarWrapper(
                todos: todos,
                currentMonth: $currentMonth,
                selectedDate: $selectedDate,
                todosForDate: todosForDate,
                onToggleComplete: { todo in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        todo.toggleCompletionOnDate(selectedDate)
                        saveTodoChanges()
                    }
                },
                onDeleteTodo: { todo in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        modelContext.delete(todo)
                        saveTodoChanges()
                    }
                },
                onScheduleTodo: { _ in
                    // Scheduling functionality removed
                },
                onMoveTodo: { todo, date in
                    todo.dueDate = date
                    saveTodoChanges()
                },
                onAddTaskForDay: { date in
                    selectedDate = date
                    // Focus the input to create a task for this date
                }
            )
        }
    }
    
    // MARK: - Speed Todo List  
    private var speedTodoList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(displayTodos, id: \.id) { todo in
                    ModernTodoCard(
                        todo: todo,
                        onComplete: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                todo.toggleCompletionOnDate(Date())
                                saveTodoChanges()
                            }
                        },
                        onDelete: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                modelContext.delete(todo)
                                saveTodoChanges()
                            }
                        },
                        onSchedule: {
                            // Scheduling functionality removed
                        }
                    )
                }
                
                if displayTodos.isEmpty {
                    modernEmptyState
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 120) // Space for input
        }
    }
    
    private var modernEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: currentView == .today ? "sun.max" : "sparkles")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(.white.opacity(0.3))
            
            VStack(spacing: 8) {
                Text(currentView == .today ? "Nothing for today" : "All clear")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Start typing below to add tasks")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.top, 60)
    }
    
    // MARK: - Lightning Input
    private var lightningInput: some View {
        VStack(spacing: 12) {
            Spacer()
            
            // Smart suggestions row
            if !suggestions.isEmpty && isInputFocused && !quickInput.isEmpty {
                smartSuggestionsRow
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // AI Status indicator
            if !taskCreationViewModel.statusMessage.isEmpty {
                aiStatusIndicator
                    .transition(.opacity)
            }
            
            HStack(spacing: 16) {
                HStack {
                    TextField("Try: 'workout every Mon, Wed, Fri at 7pm'", text: $quickInput)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .textFieldStyle(.plain)
                        .focused($isInputFocused)
                        .onSubmit {
                            createTodoWithAI()
                        }
                        .onChange(of: quickInput) { oldValue, newValue in
                            taskCreationViewModel.input = newValue
                            // Only update suggestions if input is meaningful
                            if newValue.count > 2 {
                                updateSuggestions(for: newValue)
                            } else {
                                suggestions = []
                            }
                        }
                    
                    if !quickInput.isEmpty {
                        Group {
                            if taskCreationViewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                            } else {
                                Button(action: createTodoWithAI) {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(width: 32, height: 32)
                                        .background(
                                            Circle()
                                                .fill(.cyan)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isInputFocused ? .cyan.opacity(0.5) : .white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .background(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .black.opacity(0),
                                .black.opacity(0.8),
                                .black
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
            )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isInputFocused)
        .animation(.spring(response: 0.2, dampingFraction: 0.9), value: quickInput.isEmpty)
    }
    
    private func createTodoWithAI() {
        guard !quickInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        Task {
            await taskCreationViewModel.createTodo()
            if case .completed = taskCreationViewModel.state {
                await MainActor.run {
                    quickInput = ""
                    taskCreationViewModel.input = ""
                    suggestions = []
                    selectedSuggestionIndex = -1
                    
                    // If we're in calendar view and have a selected date, assign it
                    if currentView == .calendar, 
                       let lastCreatedTodo = todos.last,
                       !Calendar.current.isDate(selectedDate, inSameDayAs: Date()) {
                        lastCreatedTodo.dueDate = selectedDate
                        saveTodoChanges()
                    }
                    
                    // Haptic feedback for successful creation
                    #if canImport(UIKit)
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                    #endif
                }
            }
        }
    }
    
    // MARK: - Smart Suggestions
    private var smartSuggestionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                    suggestionChip(
                        suggestion: suggestion,
                        isSelected: index == selectedSuggestionIndex,
                        onTap: {
                            quickInput = suggestion
                            taskCreationViewModel.input = suggestion
                            selectedSuggestionIndex = -1
                            suggestions = []
                        }
                    )
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func suggestionChip(suggestion: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(suggestion)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .black : .white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? .cyan : .white.opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? .clear : .white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
    
    private var aiStatusIndicator: some View {
        HStack(spacing: 8) {
            statusIcon
            
            Text(taskCreationViewModel.statusMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }
    
    private var statusIcon: some View {
        Group {
            switch taskCreationViewModel.state {
            case .idle:
                Image(systemName: "sparkles")
                    .foregroundColor(.cyan.opacity(0.8))
            case .parsing:
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.orange.opacity(0.8))
            case .creating:
                Image(systemName: "plus.circle")
                    .foregroundColor(.green.opacity(0.8))
            case .parsed:
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green.opacity(0.8))
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .error:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .font(.system(size: 12, weight: .medium))
    }
    
    private func updateSuggestions(for input: String) {
        guard !input.isEmpty && input.count > 1 else {
            suggestions = []
            return
        }
        
        let filtered = commonTasks.filter { task in
            task.localizedCaseInsensitiveContains(input) && task != input
        }.prefix(4)
        
        suggestions = Array(filtered)
    }
    
    // MARK: - Keyboard Navigation
    
    private func handleGlobalKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        // Delegate calendar navigation to existing handler when in calendar view
        if currentView == .calendar {
            return handleCalendarKeyPress(keyPress)
        }
        
        return .ignored
    }
    
    private func handleCalendarKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        let calendar = Calendar.current
        
        switch keyPress.key {
        case .leftArrow:
            if let previousDay = calendar.date(byAdding: .day, value: -1, to: selectedDate) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDate = previousDay
                    // Update current month if we moved to a different month
                    if !calendar.isDate(previousDay, equalTo: currentMonth, toGranularity: .month) {
                        currentMonth = previousDay
                    }
                }
            }
            return .handled
            
        case .rightArrow:
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDate) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDate = nextDay
                    // Update current month if we moved to a different month
                    if !calendar.isDate(nextDay, equalTo: currentMonth, toGranularity: .month) {
                        currentMonth = nextDay
                    }
                }
            }
            return .handled
            
        case .upArrow:
            if let previousWeek = calendar.date(byAdding: .day, value: -7, to: selectedDate) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDate = previousWeek
                    if !calendar.isDate(previousWeek, equalTo: currentMonth, toGranularity: .month) {
                        currentMonth = previousWeek
                    }
                }
            }
            return .handled
            
        case .downArrow:
            if let nextWeek = calendar.date(byAdding: .day, value: 7, to: selectedDate) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDate = nextWeek
                    if !calendar.isDate(nextWeek, equalTo: currentMonth, toGranularity: .month) {
                        currentMonth = nextWeek
                    }
                }
            }
            return .handled
            
        default:
            return .ignored
        }
    }
    
    // MARK: - Recurring Task Logic
    
    /// Helper function to determine if a todo should appear on a specific date
    private func shouldTodoAppearOnDate(_ todo: Todo, date: Date) -> Bool {
        let calendar = Calendar.current
        
        // First check basic appearance logic
        var shouldAppear = false
        
        // Check if it's a regular todo with explicit due date
        if let dueDate = todo.dueDate {
            if calendar.isDate(dueDate, inSameDayAs: date) {
                shouldAppear = true
            }
        }
        
        // Check if it's a recurring todo that should appear on this date
        if let recurrenceConfig = todo.recurrenceConfig {
            shouldAppear = shouldRecurringTodoAppearOnDate(todo, recurrenceConfig: recurrenceConfig, date: date)
        }
        
        // Fallback: check if it was created on this date (for non-recurring, non-scheduled todos)
        if todo.dueDate == nil && todo.recurrenceConfig == nil {
            shouldAppear = calendar.isDate(todo.createdAt, inSameDayAs: date)
        }
        
        // If it shouldn't appear based on date logic, return false immediately
        if !shouldAppear {
            return false
        }
        
        // Phase 4 Enhancement: Hide todos that are completed on this specific date
        if todo.isCompletedOnDate(date) {
            return false
        }
        
        // Hide todos that are deleted/hidden on this specific date
        if todo.isDeletedOnDate(date) {
            return false
        }
        
        return true
    }
    
    /// Helper function to check if a recurring todo should appear on a specific date
    private func shouldRecurringTodoAppearOnDate(_ todo: Todo, recurrenceConfig: RecurrenceConfig, date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        switch recurrenceConfig.type {
        case .none:
            return false
            
        case .hourly:
            return true
            
        case .daily:
            return true
            
        case .weekly:
            if let dueDate = todo.dueDate {
                let originalWeekday = calendar.component(.weekday, from: dueDate)
                return weekday == originalWeekday
            }
            return false
            
        case .specificDays:
            return recurrenceConfig.specificWeekdays.contains(weekday)
            
        case .monthly:
            if let monthlyDay = recurrenceConfig.monthlyDay {
                let day = calendar.component(.day, from: date)
                return day == monthlyDay
            }
            return false
            
        case .yearly:
            if let dueDate = todo.dueDate {
                let originalMonth = calendar.component(.month, from: dueDate)
                let originalDay = calendar.component(.day, from: dueDate)
                let currentMonth = calendar.component(.month, from: date)
                let currentDay = calendar.component(.day, from: date)
                return originalMonth == currentMonth && originalDay == currentDay
            }
            return false
            
        case .customInterval:
            // Custom interval logic would need more sophisticated date math
            return false
            
        case .multipleDailyTimes:
            return true
        }
    }
}

// MARK: - Modern Todo Card
struct ModernTodoCard: View {
    let todo: Todo
    let onComplete: () -> Void
    let onDelete: () -> Void
    let onSchedule: () -> Void
    
    @State private var isPressed = false
    @State private var swipeOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 16) {
            // Completion circle
            Button(action: onComplete) {
                ZStack {
                    Circle()
                        .stroke(todo.isCompleted ? .green : .white.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if todo.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Todo content
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(todo.isCompleted ? .white.opacity(0.5) : .white)
                    .strikethrough(todo.isCompleted, color: .white.opacity(0.5))
                    .lineLimit(3)
                
                // Show scheduling information
                if !todo.scheduleDescription.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: todo.isRecurring ? "repeat" : "calendar")
                            .font(.system(size: 12, weight: .medium))
                        
                        Text(todo.scheduleDescription)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.4))
                } else if let dueDate = todo.dueDate {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .medium))
                        
                        Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Spacer()
            
            // Priority/scheduling indicator
            VStack(spacing: 4) {
                if todo.isRecurring {
                    Image(systemName: "repeat")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cyan.opacity(0.8))
                } else {
                    Circle()
                        .fill(todo.isCompleted ? .green.opacity(0.6) : .cyan.opacity(0.8))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(todo.isCompleted ? 0.03 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .offset(x: swipeOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    swipeOffset = value.translation.width * 0.5
                }
                .onEnded { value in
                    if value.translation.width > 100 {
                        onComplete()
                    } else if value.translation.width < -100 {
                        onDelete()
                    }
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        swipeOffset = 0
                    }
                }
        )
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: swipeOffset)
        .contextMenu {
            Button(action: onComplete) {
                Label(todo.isCompleted ? "Mark Incomplete" : "Mark Complete", 
                      systemImage: todo.isCompleted ? "circle" : "checkmark.circle")
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .onLongPressGesture {
            // Trigger scheduling view on long press
            #if canImport(UIKit)
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
            #endif
            onSchedule()
        }
    }
}

// MARK: - Modern Calendar Wrapper
struct ModernCalendarWrapper: View {
    let todos: [Todo]
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    let todosForDate: (Date) -> [Todo]
    let onToggleComplete: (Todo) -> Void
    let onDeleteTodo: (Todo) -> Void
    let onScheduleTodo: (Todo) -> Void
    let onMoveTodo: (Todo, Date) -> Void
    let onAddTaskForDay: (Date) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar grid
            ModernCalendarGrid(
                todos: todos,
                currentMonth: currentMonth,
                selectedDate: $selectedDate,
                todosForDate: todosForDate,
                onToggleComplete: onToggleComplete,
                onDeleteTodo: onDeleteTodo,
                onScheduleTodo: onScheduleTodo,
                onMoveTodo: onMoveTodo,
                onAddTaskForDay: onAddTaskForDay
            )
            
            // Selected day todos detail view
            if !todosForDate(selectedDate).isEmpty {
                selectedDayDetailView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 120) // Space for input
    }
    
    private var selectedDayDetailView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDate.formatted(date: .complete, time: .omitted))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(todosForDate(selectedDate).count) tasks")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            LazyVStack(spacing: 8) {
                ForEach(todosForDate(selectedDate), id: \.id) { todo in
                    CompactTodoRow(
                        todo: todo,
                        onComplete: { onToggleComplete(todo) },
                        onSchedule: { onScheduleTodo(todo) },
                        onDelete: { onDeleteTodo(todo) }
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.top, 16)
    }
}

// MARK: - Modern Calendar Grid
struct ModernCalendarGrid: View {
    @Environment(\.modelContext) private var modelContext
    let todos: [Todo]
    let currentMonth: Date
    @Binding var selectedDate: Date
    let todosForDate: (Date) -> [Todo]
    let onToggleComplete: (Todo) -> Void
    let onDeleteTodo: (Todo) -> Void
    let onScheduleTodo: (Todo) -> Void
    let onMoveTodo: (Todo, Date) -> Void
    let onAddTaskForDay: (Date) -> Void
    
    private let calendar = Calendar.current
    
    /// Save the model context with error handling
    private func saveContext() {
        do {
            try modelContext.save()
            print("✅ Successfully saved model context")
        } catch {
            print("❌ Failed to save model context: \(error.localizedDescription)")
        }
    }
    
    // Get weeks for the current month
    private var weekDays: [[Date]] {
        let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)!.start
        let endOfMonth = calendar.dateInterval(of: .month, for: currentMonth)!.end
        
        let firstWeekday = calendar.dateComponents([.weekday], from: startOfMonth).weekday! - 1
        let startOfWeek = calendar.date(byAdding: .day, value: -firstWeekday, to: startOfMonth)!
        
        var weeks: [[Date]] = []
        var currentWeekStart = startOfWeek
        
        for _ in 0..<6 {
            var week: [Date] = []
            for dayOffset in 0..<7 {
                let date = calendar.date(byAdding: .day, value: dayOffset, to: currentWeekStart)!
                week.append(date)
            }
            weeks.append(week)
            currentWeekStart = calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!
            
            if currentWeekStart > endOfMonth && weeks.count >= 5 {
                break
            }
        }
        
        return weeks
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)
            
            // Calendar grid
            ForEach(Array(weekDays.enumerated()), id: \.offset) { weekIndex, week in
                HStack(spacing: 8) {
                    ForEach(week, id: \.self) { date in
                        modernDayCell(for: date)
                    }
                }
            }
        }
    }
    
    private func modernDayCell(for date: Date) -> some View {
        let isInCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
        let isToday = calendar.isDate(date, inSameDayAs: Date())
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let todaysTask = todosForDate(date)
        let hasTasks = !todaysTask.isEmpty
        
        return VStack(alignment: .leading, spacing: 2) {
            // Day number
            HStack {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 12, weight: isToday ? .bold : .medium))
                    .foregroundColor(
                        isToday ? .black :
                        isSelected ? .black :
                        isInCurrentMonth ? .white : .white.opacity(0.3)
                    )
                
                Spacer()
                
                if todaysTask.count > 2 {
                    Text("+\(todaysTask.count - 2)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.15))
                        )
                }
            }
            
            // Todo titles (up to 2 visible)
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(todaysTask.prefix(2).enumerated()), id: \.offset) { index, todo in
                    HStack(spacing: 3) {
                        // Completion button
                        Button(action: {
                            completeTodoOnDate(todo, date: date)
                        }) {
                            Image(systemName: todo.isCompletedOnDate(date) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(todo.isCompletedOnDate(date) ? .green : .white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        
                        // Priority indicator (colored dot)
                        Circle()
                            .fill(priorityColor(for: todo.actualPriority))
                            .frame(width: 4, height: 4)
                            .opacity(todo.isCompletedOnDate(date) ? 0.5 : 0.8)
                        
                        // Category icon (if available)
                        if !todo.categoryIcon.isEmpty {
                            Image(systemName: todo.categoryIcon)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.white.opacity(todo.isCompletedOnDate(date) ? 0.5 : 0.7))
                        }
                        
                        // Todo title
                        Text(todo.title)
                            .font(.system(size: dynamicFontSize(for: todo.title), weight: .medium))
                            .foregroundColor(todo.isCompletedOnDate(date) ? .green.opacity(0.8) : .white.opacity(0.9))
                            .strikethrough(todo.isCompletedOnDate(date), color: .green.opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(todo.isCompletedOnDate(date) ? .green.opacity(0.15) : .cyan.opacity(0.15))
                    )
                    .contextMenu {
                        Button(action: {
                            completeTodoOnDate(todo, date: date)
                        }) {
                            Label("Toggle Complete", systemImage: "checkmark.circle")
                        }
                        
                        Divider()
                        
                        if todo.isRecurring {
                            Button(role: .destructive, action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    todo.markDeletedOnDate(date)
                                }
                            }) {
                                Label("Hide for This Day", systemImage: "eye.slash")
                            }
                            
                            Button(role: .destructive, action: {
                                onDeleteTodo(todo)
                            }) {
                                Label("Delete Recurring Todo", systemImage: "trash.fill")
                            }
                        } else {
                            Button(role: .destructive, action: {
                                onDeleteTodo(todo)
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .draggable(todo.id.uuidString) {
                        // Drag preview
                        Text(todo.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.cyan.opacity(0.8))
                            )
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isToday ? .cyan.opacity(0.3) :
                    isSelected ? .white.opacity(0.2) :
                    hasTasks ? .white.opacity(0.05) : .clear
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            isToday ? .cyan.opacity(0.6) :
                            isInCurrentMonth ? .white.opacity(0.1) : .clear,
                            lineWidth: 1
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = date
        }
        .onLongPressGesture {
            // Long press to add task for this day
            onAddTaskForDay(date)
        }
        .dropDestination(for: String.self) { droppedItems, location in
            // Handle todo drop
            guard let todoIdString = droppedItems.first,
                  let todoId = UUID(uuidString: todoIdString),
                  let todo = todos.first(where: { $0.id == todoId }) else {
                return false
            }
            
            // Move todo to this date
            moveTodo(todo, to: date)
            return true
        } isTargeted: { isTargeted in
            // Visual feedback during drag over
            // Could add visual indication here if needed
        }
    }
    
    /// Dynamic font size based on text length - shorter text gets larger font
    private func dynamicFontSize(for text: String) -> CGFloat {
        let length = text.count
        switch length {
        case 0...8:
            return 16 // Very short text gets largest font
        case 9...15:
            return 14 // Medium text gets medium font
        case 16...25:
            return 13 // Longer text gets smaller font
        default:
            return 12 // Very long text gets smallest font
        }
    }
    
    /// Move a todo to a new date - handles both simple and recurring todos
    private func moveTodo(_ todo: Todo, to newDate: Date) {
        let calendar = Calendar.current
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if todo.isRecurring {
                // For recurring todos: Move the entire recurrence pattern
                // This updates the base dueDate which shifts all future occurrences
                todo.dueDate = calendar.startOfDay(for: newDate)
            } else {
                // For simple todos: Just update the dueDate
                todo.dueDate = calendar.startOfDay(for: newDate)
            }
            
            // Preserve the time if it exists
            if let existingTime = todo.dueTime {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: existingTime)
                if let newDateTime = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                 minute: timeComponents.minute ?? 0,
                                                 second: 0,
                                                 of: newDate) {
                    todo.dueDate = newDateTime
                }
            }
        }
        
        // Save changes
        saveContext()
    }
    
    /// Complete a todo on a specific date - handles both simple and recurring todos
    private func completeTodoOnDate(_ todo: Todo, date: Date) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            // Use the smart toggle method from Todo model
            todo.toggleCompletionOnDate(date)
        }
        
        // Save changes
        saveContext()
    }
    
    /// Get SwiftUI Color for priority level
    private func priorityColor(for priority: TaskPriority) -> Color {
        switch priority {
        case .low:
            return .gray
        case .medium:
            return .blue
        case .high:
            return .red
        case .urgent:
            return .red
        }
    }
}

// MARK: - Compact Todo Row (for calendar day details)
struct CompactTodoRow: View {
    let todo: Todo
    let onComplete: () -> Void
    let onSchedule: () -> Void
    let onDelete: () -> Void
    
    @State private var swipeOffset: CGFloat = 0
    @State private var showDeleteButton = false
    
    var body: some View {
        ZStack {
            // Delete button background
            HStack {
                Spacer()
                
                Button(action: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        swipeOffset = -1000 // Swipe off screen
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDelete()
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 60)
                        .frame(maxHeight: .infinity)
                        .background(Color.red)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .opacity(showDeleteButton ? 1 : 0)
            }
            
            // Main content
            HStack(spacing: 12) {
                // Completion button
                Button(action: onComplete) {
                    ZStack {
                        Circle()
                            .stroke(todo.isCompleted ? .green : .white.opacity(0.3), lineWidth: 2)
                            .frame(width: 20, height: 20)
                        
                        if todo.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // Todo content
                VStack(alignment: .leading, spacing: 2) {
                    Text(todo.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(todo.isCompleted ? .white.opacity(0.5) : .white)
                        .strikethrough(todo.isCompleted, color: .white.opacity(0.5))
                        .lineLimit(2)
                    
                    if !todo.scheduleDescription.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: todo.isRecurring ? "repeat" : "calendar")
                                .font(.system(size: 10, weight: .medium))
                            
                            Text(todo.scheduleDescription)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.4))
                    }
                }
                
                Spacer()
                
                // Priority/scheduling indicator
                VStack(spacing: 4) {
                    if todo.isRecurring {
                        Image(systemName: "repeat")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.cyan.opacity(0.8))
                    } else {
                        Circle()
                            .fill(todo.isCompleted ? .green.opacity(0.6) : .cyan.opacity(0.8))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(todo.isCompleted ? 0.03 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .offset(x: swipeOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            swipeOffset = max(value.translation.width, -60)
                            showDeleteButton = swipeOffset < -20
                        }
                    }
                    .onEnded { value in
                        if value.translation.width < -50 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                swipeOffset = -60
                                showDeleteButton = true
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                swipeOffset = 0
                                showDeleteButton = false
                            }
                        }
                    }
            )
            .contextMenu {
                Button(action: onComplete) {
                    Label(todo.isCompleted ? "Mark Incomplete" : "Mark Complete", 
                          systemImage: todo.isCompleted ? "circle" : "checkmark.circle")
                }
                
                Divider()
                
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
            .onLongPressGesture {
                onSchedule()
            }
        }
    }
}

#Preview {
    ModernSpeedContentView()
}