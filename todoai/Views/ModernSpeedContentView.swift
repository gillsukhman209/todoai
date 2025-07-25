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
import AppKit

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
    @FocusState private var isMainViewFocused: Bool
    
    // Smart suggestions
    @State private var suggestions: [String] = []
    @State private var selectedSuggestionIndex = -1
    
    // Performance optimization: cache for todo filtering
    @State private var todoCache: [String: [Todo]] = [:]
    
    // MARK: - Keyboard Navigation State
    @State private var selectedTodoId: UUID? = nil
    @State private var isEditingTodo: Bool = false
    @State private var editingTodoId: UUID? = nil
    @State private var editingText: String = ""
    @State private var keyboardMode: KeyboardMode = .input
    @State private var needsFocusRestoration: Bool = false
    
    // MARK: - Drag and Drop State
    @State private var draggedTodo: Todo? = nil
    @State private var dropTargetIndex: Int? = nil
    @State private var isDragActive: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var dragPreviewPosition: CGPoint = .zero
    
    enum KeyboardMode {
        case input      // Typing in input field
        case navigation // Navigating through todos
        case editing    // Editing a todo
    }
    
    // Safety system for keyboard shortcuts
    private var isAnyTextInputActive: Bool {
        // Only block when actually editing a todo, not during navigation
        return keyboardMode == .editing
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
        case pomodoro = "Pomodoro"
        
        var icon: String {
            switch self {
            case .calendar: return "calendar"
            case .today: return "calendar.badge.clock"
            case .upcoming: return "arrow.up.right"
            case .all: return "list.bullet"
            case .pomodoro: return "timer"
            }
        }
    }
    
    private var todayTodos: [Todo] {
        let today = Date()
        return todos.filter { todo in
            shouldTodoAppearOnDate(todo, date: today, includeCompleted: true)
        }
    }
    
    private var upcomingTodos: [Todo] {
        let calendar = Calendar.current
        let today = Date()
        
        return todos.filter { todo in
            for dayOffset in 1...7 {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: today),
                   shouldTodoAppearOnDate(todo, date: date, includeCompleted: false) {
                    return true
                }
            }
            return false
        }
    }
    
    /// Group upcoming todos by date for timeline view (includes today + next 7 days)
    private func groupUpcomingTodosByDate() -> [(Date, [Todo])] {
        let calendar = Calendar.current
        let today = Date()
        var groupedTodos: [Date: [Todo]] = [:]
        
        // Include today (dayOffset 0) and next 7 days
        for dayOffset in 0...7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            
            let todosForDate = todos.filter { todo in
                shouldTodoAppearOnDate(todo, date: date, includeCompleted: false)
            }.sorted { first, second in
                // Sort by time if available, then by creation date
                if let firstTime = first.dueTime, let secondTime = second.dueTime {
                    return firstTime < secondTime
                }
                return first.createdAt < second.createdAt
            }
            
            if !todosForDate.isEmpty {
                groupedTodos[date] = todosForDate
            }
        }
        
        // Convert to sorted array of tuples
        return groupedTodos.sorted { $0.key < $1.key }
    }
    
    private var displayTodos: [Todo] {
        let baseTodos: [Todo]
        switch currentView {
        case .calendar: baseTodos = todos
        case .today: baseTodos = todayTodos 
        case .upcoming: baseTodos = upcomingTodos
        case .all: baseTodos = todos
        case .pomodoro: baseTodos = []
        }
        
        // Sort with completed todos at the bottom
        return baseTodos.sorted { todo1, todo2 in
            if todo1.isCompleted != todo2.isCompleted {
                return !todo1.isCompleted && todo2.isCompleted
            }
            return todo1.sortOrder < todo2.sortOrder
        }
    }
    
    
    // MARK: - Keyboard Navigation Helpers
    
    /// Get the todos list to navigate based on current view
    private var navigableTodos: [Todo] {
        switch currentView {
        case .calendar:
            // In calendar view, navigate through todos for selected date
            return todosForDate(selectedDate)
        case .today, .all:
            // For other views, use the display todos
            return displayTodos
        case .upcoming:
            // For upcoming view, flatten all grouped todos to match what's displayed
            return groupUpcomingTodosByDate().flatMap { $0.1 }
        case .pomodoro:
            // Pomodoro view doesn't have navigable todos
            return []
        }
    }
    
    /// Get the currently selected todo
    private var selectedTodo: Todo? {
        guard let id = selectedTodoId else { return nil }
        return navigableTodos.first { $0.id == id }
    }
    
    /// Get the index of the currently selected todo
    private var selectedTodoIndex: Int? {
        guard let id = selectedTodoId else { return nil }
        return navigableTodos.firstIndex { $0.id == id }
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
        
        // Calculate and cache result - calendar view shows all todos including completed
        let result = todos.filter { todo in
            shouldTodoAppearOnDate(todo, date: date, includeCompleted: true)
        }.sorted(by: { !$0.isCompleted && $1.isCompleted })
        
        todoCache[cacheKey] = result
        
        // Clean cache if it gets too big
        if todoCache.count > 50 {
            todoCache.removeAll()
        }
        
        return result
    }
    
    // MARK: - Keyboard Navigation Methods
    
    /// Move selection up in the todo list
    private func navigateUp() {
        print("🔑 navigateUp() called")
        print("🔑 isAnyTextInputActive: \(isAnyTextInputActive)")
        guard !isAnyTextInputActive else { 
            print("🔑 Blocked by isAnyTextInputActive")
            return 
        }
        
        let todos = navigableTodos
        print("🔑 navigableTodos count: \(todos.count)")
        guard !todos.isEmpty else { 
            print("🔑 No todos available")
            return 
        }
        
        if let currentIndex = selectedTodoIndex {
            print("🔑 Current index: \(currentIndex)")
            // Move to previous todo, wrap to bottom if at top
            let newIndex = currentIndex > 0 ? currentIndex - 1 : todos.count - 1
            selectedTodoId = todos[newIndex].id
            print("🔑 New index: \(newIndex), selected: \(todos[newIndex].title)")
        } else {
            print("🔑 No current selection, selecting last todo")
            selectedTodoId = todos.last?.id
            print("🔑 Selected: \(todos.last?.title ?? "unknown")")
        }
    }
    
    /// Move selection down in the todo list
    private func navigateDown() {
        print("🔑 navigateDown() called")
        print("🔑 isAnyTextInputActive: \(isAnyTextInputActive)")
        guard !isAnyTextInputActive else { 
            print("🔑 Blocked by isAnyTextInputActive")
            return 
        }
        
        let todos = navigableTodos
        print("🔑 navigableTodos count: \(todos.count)")
        guard !todos.isEmpty else { 
            print("🔑 No todos available")
            return 
        }
        
        if let currentIndex = selectedTodoIndex {
            print("🔑 Current index: \(currentIndex)")
            // If we're at the last todo, move to input instead of wrapping
            if currentIndex >= todos.count - 1 {
                print("🔑 At last todo, moving to input mode")
                keyboardMode = .input
                selectedTodoId = nil
                // Focus the input field
                DispatchQueue.main.async {
                    isInputFocused = true
                }
            } else {
                // Move to next todo
                let newIndex = currentIndex + 1
                selectedTodoId = todos[newIndex].id
                print("🔑 New index: \(newIndex), selected: \(todos[newIndex].title)")
            }
        } else {
            print("🔑 No current selection, selecting first todo")
            selectedTodoId = todos.first?.id
            print("🔑 Selected: \(todos.first?.title ?? "unknown")")
        }
    }
    
    /// Delete the currently selected todo
    private func deleteSelectedTodo() {
        guard keyboardMode == .navigation,
              let todo = selectedTodo,
              let currentIndex = selectedTodoIndex else { return }
        
        let todos = navigableTodos
        
        withAnimation(.easeOut(duration: 0.3)) {
            modelContext.delete(todo)
            saveTodoChanges()
            
            // Move focus to the nearest todo
            if todos.count > 1 {
                // If we deleted the last item, select the new last item
                if currentIndex >= todos.count - 1 {
                    // Select the item that will become the new last item
                    if currentIndex > 0 {
                        selectedTodoId = todos[currentIndex - 1].id
                    }
                } else {
                    // Select the item that will take this position after deletion
                    selectedTodoId = todos[currentIndex + 1].id
                }
            } else {
                // No more todos, clear selection
                selectedTodoId = nil
            }
        }
    }
    
    /// Toggle completion of the currently selected todo
    private func toggleSelectedTodoCompletion() {
        guard keyboardMode == .navigation,
              let todo = selectedTodo else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            if currentView == .calendar {
                // For calendar view, toggle completion on selected date
                todo.toggleCompletionOnDate(selectedDate)
            } else {
                // For other views, toggle overall completion
                todo.isCompleted.toggle()
            }
            saveTodoChanges()
        }
    }
    
    /// Start editing the currently selected todo
    private func startEditingSelectedTodo() {
        guard keyboardMode == .navigation,
              let todo = selectedTodo else { return }
        
        editingTodoId = todo.id
        editingText = todo.title
        isEditingTodo = true
        keyboardMode = .editing
    }
    
    /// Save the edited todo text
    private func saveEditedTodo() {
        guard let todoId = editingTodoId,
              let todo = todos.first(where: { $0.id == todoId }) else {
            cancelEditingTodo()
            return
        }
        
        let trimmedText = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            todo.title = trimmedText
            saveTodoChanges()
        }
        
        cancelEditingTodo()
        
        // Restore keyboard focus after editing completes
        print("🔄 Restoring keyboard focus after editing")
        needsFocusRestoration = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            needsFocusRestoration = false
            print("🔄 Focus restoration complete")
        }
    }
    
    /// Cancel editing and reset state
    private func cancelEditingTodo() {
        isEditingTodo = false
        editingTodoId = nil
        editingText = ""
        keyboardMode = .navigation
        
        // Restore focus to main view for keyboard navigation
        DispatchQueue.main.async {
            isMainViewFocused = true
        }
    }
    
    /// Reset selection when view changes
    private func resetSelection() {
        selectedTodoId = nil
        cancelEditingTodo()
    }
    
    // MARK: - Drag and Drop Functions
    
    /// Handle when a todo starts being dragged from its drag handle
    private func startDragging(todo: Todo, at location: CGPoint) {
        print("🎯 Starting drag for: \(todo.title)")
        draggedTodo = todo
        isDragActive = true
        dragPreviewPosition = location
        dropTargetIndex = nil
        
        // Haptic feedback for drag start
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
    
    /// Handle drag movement and update drop target
    private func updateDrag(location: CGPoint) {
        guard isDragActive else { return }
        
        dragPreviewPosition = location
        
        // Calculate which drop target we're over
        let todos = displayTodos
        let approximateCardHeight: CGFloat = 70
        let spacing: CGFloat = isDragActive ? 8 : 12
        
        // Estimate which todo index we're hovering over based on Y position
        let scrollOffset: CGFloat = 100 // Approximate offset from top of scroll view
        let relativeY = location.y - scrollOffset
        let hoveredIndex = max(0, min(todos.count, Int(relativeY / (approximateCardHeight + spacing))))
        
        if dropTargetIndex != hoveredIndex {
            dropTargetIndex = hoveredIndex
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            print("🎯 Hovering over drop zone: \(hoveredIndex)")
        }
    }
    
    /// Handle when drag ends - perform the reorder
    private func endDrag() {
        defer {
            draggedTodo = nil
            isDragActive = false
            dropTargetIndex = nil
            dragPreviewPosition = .zero
        }
        
        guard let draggedTodo = draggedTodo,
              let targetIndex = dropTargetIndex else {
            print("🎯 Drag cancelled - no valid drop target")
            return
        }
        
        let todos = displayTodos
        guard let currentIndex = todos.firstIndex(where: { $0.id == draggedTodo.id }) else {
            print("🎯 Error: Could not find dragged todo in current list")
            return
        }
        
        // Prevent dropping in the same location
        if currentIndex == targetIndex {
            print("🎯 Dropped in same location - no change needed")
            return
        }
        
        print("🎯 Reordering: moving \(draggedTodo.title) from \(currentIndex) to \(targetIndex)")
        
        // Perform the reorder with animation
        withAnimation(.easeInOut(duration: 0.2)) {
            reorderTodos(from: currentIndex, to: targetIndex)
        }
        
        // Success haptic feedback
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
    
    
    /// Reorder todos by updating their sort orders
    private func reorderTodos(from sourceIndex: Int, to targetIndex: Int, todosList: [Todo]? = nil) {
        let currentTodos = todosList ?? displayTodos
        guard sourceIndex >= 0 && sourceIndex < currentTodos.count &&
              targetIndex >= 0 && targetIndex <= currentTodos.count else { return }
        
        let draggedTodo = currentTodos[sourceIndex]
        
        // Create new array with the todo moved to the target position
        var reorderedTodos = currentTodos
        reorderedTodos.remove(at: sourceIndex)
        
        // Adjust target index if it's after the removal
        let adjustedTargetIndex = targetIndex > sourceIndex ? targetIndex - 1 : targetIndex
        reorderedTodos.insert(draggedTodo, at: adjustedTargetIndex)
        
        // Update sort orders to maintain the new arrangement
        for (newIndex, todo) in reorderedTodos.enumerated() {
            todo.sortOrder = newIndex * 100  // Use increments of 100 to allow future insertions
        }
        
        // Save the changes
        saveTodoChanges()
        
        print("🎯 Reordered todos - moved \(draggedTodo.title) from \(sourceIndex) to \(adjustedTargetIndex)")
    }
    
    // MARK: - Keyboard Reordering Methods
    
    /// Move selected todo up one position
    private func moveSelectedTodoUp() {
        guard let selectedId = selectedTodoId else { return }
        
        if currentView == .upcoming {
            moveSelectedTodoUpInUpcomingView()
        } else {
            let currentTodos = navigableTodos
            guard let currentIndex = currentTodos.firstIndex(where: { $0.id == selectedId }) else { return }
            guard currentIndex > 0 else { return } // Already at top
            
            let targetIndex = currentIndex - 1
            reorderTodos(from: currentIndex, to: targetIndex, todosList: currentTodos)
            
            // Add visual feedback
            withAnimation(.easeInOut(duration: 0.2)) {
                // Animation will be handled by the todo card updates
            }
            
            // Haptic feedback
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            
            print("🔑 Moved todo up from \(currentIndex) to \(targetIndex)")
        }
    }
    
    /// Move selected todo down one position
    private func moveSelectedTodoDown() {
        guard let selectedId = selectedTodoId else { 
            print("🔑 moveSelectedTodoDown: No selected todo ID")
            return 
        }
        
        if currentView == .upcoming {
            moveSelectedTodoDownInUpcomingView()
        } else {
            let currentTodos = navigableTodos
            print("🔑 moveSelectedTodoDown: Total todos: \(currentTodos.count)")
            guard let currentIndex = currentTodos.firstIndex(where: { $0.id == selectedId }) else { 
                print("🔑 moveSelectedTodoDown: Could not find todo with ID \(selectedId)")
                return 
            }
            print("🔑 moveSelectedTodoDown: Current index: \(currentIndex)")
            guard currentIndex < currentTodos.count - 1 else { 
                print("🔑 moveSelectedTodoDown: Already at bottom (index \(currentIndex) of \(currentTodos.count - 1))")
                return 
            } // Already at bottom
            
            // For moving down, we need to account for the drag-drop logic
            // When moving from index i to index i+1, we need to pass i+2 as target
            // because the reorderTodos method adjusts for removal
            let targetIndex = currentIndex + 2
            print("🔑 moveSelectedTodoDown: Moving from \(currentIndex) to target \(targetIndex)")
            reorderTodos(from: currentIndex, to: targetIndex, todosList: currentTodos)
            
            // Add visual feedback
            withAnimation(.easeInOut(duration: 0.2)) {
                // Animation will be handled by the todo card updates
            }
            
            // Haptic feedback
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            
            print("🔑 Moved todo down from \(currentIndex) to \(targetIndex)")
        }
    }
    
    /// Move selected todo to top position
    private func moveSelectedTodoToTop() {
        guard let selectedId = selectedTodoId else { return }
        let currentTodos = navigableTodos
        guard let currentIndex = currentTodos.firstIndex(where: { $0.id == selectedId }) else { return }
        guard currentIndex > 0 else { return } // Already at top
        
        let targetIndex = 0
        reorderTodos(from: currentIndex, to: targetIndex, todosList: currentTodos)
        
        // Add visual feedback
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Animation will be handled by the todo card updates
        }
        
        // Stronger haptic feedback for large moves
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        
        print("🔑 Moved todo to top from \(currentIndex) to \(targetIndex)")
    }
    
    /// Move selected todo to bottom position
    private func moveSelectedTodoToBottom() {
        guard let selectedId = selectedTodoId else { return }
        let currentTodos = navigableTodos
        guard let currentIndex = currentTodos.firstIndex(where: { $0.id == selectedId }) else { return }
        guard currentIndex < currentTodos.count - 1 else { return } // Already at bottom
        
        // For moving to bottom, pass count as target (will be adjusted to count-1 after removal)
        let targetIndex = currentTodos.count
        reorderTodos(from: currentIndex, to: targetIndex, todosList: currentTodos)
        
        // Add visual feedback
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Animation will be handled by the todo card updates
        }
        
        // Stronger haptic feedback for large moves
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        
        print("🔑 Moved todo to bottom from \(currentIndex) to \(targetIndex)")
    }
    
    // MARK: - Upcoming View Specific Reordering
    
    /// Move selected todo up within its day in upcoming view
    private func moveSelectedTodoUpInUpcomingView() {
        guard let selectedId = selectedTodoId,
              let selectedTodo = todos.first(where: { $0.id == selectedId }) else {
            print("🔑 Upcoming Up: No selected todo found")
            return
        }
        
        let groupedTodos = groupUpcomingTodosByDate()
        
        // Find which day group contains this todo
        guard let dayGroupIndex = groupedTodos.firstIndex(where: { _, dayTodos in
            dayTodos.contains { $0.id == selectedId }
        }) else {
            print("🔑 Upcoming Up: Todo not found in any day group")
            return
        }
        
        let (date, dayTodos) = groupedTodos[dayGroupIndex]
        guard let todoIndexInDay = dayTodos.firstIndex(where: { $0.id == selectedId }) else {
            print("🔑 Upcoming Up: Todo index not found in day")
            return
        }
        
        if todoIndexInDay > 0 {
            // Move within the same day - use more robust reordering
            let targetTodo = dayTodos[todoIndexInDay - 1]
            
            // Get all todos for this day and reorder them properly
            let todosForThisDay = dayTodos.sorted { $0.sortOrder < $1.sortOrder }
            
            // Create new sort orders with gaps
            for (index, todo) in todosForThisDay.enumerated() {
                let newOrder = index * 1000 // Large gaps to avoid conflicts
                if todo.id == selectedTodo.id {
                    // This todo should be at targetIndex position
                    todo.sortOrder = (todoIndexInDay - 1) * 1000
                } else if todo.id == targetTodo.id {
                    // Target todo moves down one position
                    todo.sortOrder = todoIndexInDay * 1000
                } else if index < todoIndexInDay - 1 {
                    // Todos before the swap position stay the same
                    todo.sortOrder = index * 1000
                } else if index > todoIndexInDay {
                    // Todos after the swap position stay the same
                    todo.sortOrder = index * 1000
                }
            }
            
            print("🔑 Upcoming Up: Moved todo '\(selectedTodo.title)' within day from index \(todoIndexInDay) to \(todoIndexInDay - 1)")
        } else if dayGroupIndex > 0 {
            // Move to the previous day (to the end of that day's todos)
            let (previousDate, previousDayTodos) = groupedTodos[dayGroupIndex - 1]
            
            // Update the todo's due date to the previous day
            selectedTodo.dueDate = previousDate
            
            // Set sort order to be after the last todo in the previous day
            if let lastTodoInPreviousDay = previousDayTodos.last {
                selectedTodo.sortOrder = lastTodoInPreviousDay.sortOrder + 100
            } else {
                selectedTodo.sortOrder = 0
            }
            
            print("🔑 Upcoming Up: Moved todo to previous day (\(previousDate))")
        } else {
            print("🔑 Upcoming Up: Already at the top of the first day")
            return
        }
        
        // Save changes and provide feedback
        saveTodoChanges()
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
    
    /// Move selected todo down within its day in upcoming view  
    private func moveSelectedTodoDownInUpcomingView() {
        guard let selectedId = selectedTodoId,
              let selectedTodo = todos.first(where: { $0.id == selectedId }) else {
            print("🔑 Upcoming Down: No selected todo found")
            return
        }
        
        let groupedTodos = groupUpcomingTodosByDate()
        
        // Find which day group contains this todo
        guard let dayGroupIndex = groupedTodos.firstIndex(where: { _, dayTodos in
            dayTodos.contains { $0.id == selectedId }
        }) else {
            print("🔑 Upcoming Down: Todo not found in any day group")
            return
        }
        
        let (date, dayTodos) = groupedTodos[dayGroupIndex]
        guard let todoIndexInDay = dayTodos.firstIndex(where: { $0.id == selectedId }) else {
            print("🔑 Upcoming Down: Todo index not found in day")
            return
        }
        
        if todoIndexInDay < dayTodos.count - 1 {
            // Move within the same day - use more robust reordering
            let targetTodo = dayTodos[todoIndexInDay + 1]
            
            // Get all todos for this day and reorder them properly
            let todosForThisDay = dayTodos.sorted { $0.sortOrder < $1.sortOrder }
            
            // Create new sort orders with gaps
            for (index, todo) in todosForThisDay.enumerated() {
                if todo.id == selectedTodo.id {
                    // This todo should be at targetIndex position
                    todo.sortOrder = (todoIndexInDay + 1) * 1000
                } else if todo.id == targetTodo.id {
                    // Target todo moves up one position
                    todo.sortOrder = todoIndexInDay * 1000
                } else if index < todoIndexInDay {
                    // Todos before the swap position stay the same
                    todo.sortOrder = index * 1000
                } else if index > todoIndexInDay + 1 {
                    // Todos after the swap position stay the same
                    todo.sortOrder = index * 1000
                }
            }
            
            print("🔑 Upcoming Down: Moved todo '\(selectedTodo.title)' within day from index \(todoIndexInDay) to \(todoIndexInDay + 1)")
        } else if dayGroupIndex < groupedTodos.count - 1 {
            // Move to the next day (to the beginning of that day's todos)
            let (nextDate, nextDayTodos) = groupedTodos[dayGroupIndex + 1]
            
            // Update the todo's due date to the next day
            selectedTodo.dueDate = nextDate
            
            // Set sort order to be before the first todo in the next day
            if let firstTodoInNextDay = nextDayTodos.first {
                selectedTodo.sortOrder = firstTodoInNextDay.sortOrder - 100
            } else {
                selectedTodo.sortOrder = 0
            }
            
            print("🔑 Upcoming Down: Moved todo to next day (\(nextDate))")
        } else {
            print("🔑 Upcoming Down: Already at the bottom of the last day")
            return
        }
        
        // Save changes and provide feedback
        saveTodoChanges()
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
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
        // Clear cache when todos change
        todoCache.removeAll()
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
                // Modern header - always visible with fixed height
                modernHeader
                    .zIndex(100) // Ensure header stays on top
                    .fixedSize(horizontal: false, vertical: true)
                
                // Content area - Calendar, Timeline, or Todo List - This should expand
                ZStack {
                    
                    if currentView == .calendar {
                        modernCalendarView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else if currentView == .upcoming {
                        upcomingTimelineView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else if currentView == .pomodoro {
                        PomodoroView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        speedTodoList
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                    
                    // Lightning-fast input overlay at bottom
                    VStack {
                        Spacer()
                        lightningInputFixed
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .clipped() // Prevent content from overlapping header
            }
        }
        .preferredColorScheme(.dark)
        .focusable(true)
        .focused($isMainViewFocused)
        .focusEffectDisabled()
        .onKeyPress { keyPress in
            return handleGlobalKeyPress(keyPress)
        }
        .onChange(of: needsFocusRestoration) { oldValue, newValue in
            if newValue {
                // Restore focus to main view for keyboard navigation
                DispatchQueue.main.async {
                    print("🔄 Restoring focus to main view")
                    isMainViewFocused = true
                }
            }
        }
        .onAppear {
            // Set the model context for AI task creation
            taskCreationViewModel.updateModelContext(modelContext)
            taskCreationViewModel.updateSelectedDate(selectedDate)
            
            // Ensure main view has focus for keyboard navigation
            DispatchQueue.main.async {
                isMainViewFocused = true
            }
            
            // Force save any pending changes on app startup
            saveContext()
            
            // Verify database status and log diagnostics
            verifyDatabaseStatus()
            
            // Main view handles all keyboard events by default
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusTaskInput)) { _ in
            // Handle Command+N from menu
            isInputFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showTodayView)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                currentView = .today
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showUpcomingView)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                currentView = .upcoming
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCalendarView)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                currentView = .calendar
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAllView)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                currentView = .all
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showPomodoroView)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                currentView = .pomodoro
            }
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            // Only update selected date in task creation when in calendar view
            if currentView == .calendar {
                taskCreationViewModel.updateSelectedDate(newValue)
            }
        }
        .onChange(of: currentView) { oldValue, newValue in
            // Reset keyboard navigation selection when switching views
            resetSelection()
        }
        .onChange(of: isInputFocused) { oldValue, newValue in
            // Update keyboard mode when input focus changes
            if newValue {
                print("🔄 Input focused - switching to input mode and clearing selection")
                keyboardMode = .input
                selectedTodoId = nil  // Clear todo selection when focusing input
            } else if keyboardMode == .input {
                print("🔄 Input unfocused - switching to navigation mode")
                keyboardMode = .navigation
                // Restore focus to main view for keyboard navigation
                DispatchQueue.main.async {
                    isMainViewFocused = true
                }
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
            withAnimation(.easeInOut(duration: 0.2)) {
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
        case .pomodoro: return "P"
        }
    }
    
    // MARK: - Modern Calendar View
    private var modernCalendarView: some View {
        VStack(spacing: 0) {
            // Month navigation
            HStack {
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.25)) {
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
                    withAnimation(.easeInOut(duration: 0.25)) {
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        todo.toggleCompletionOnDate(selectedDate)
                        saveTodoChanges()
                    }
                },
                onDeleteTodo: { todo in
                    withAnimation(.easeInOut(duration: 0.2)) {
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
    
    // MARK: - Upcoming Timeline View
    private var upcomingTimelineView: some View {
        UpcomingTimelineView(
            groupedTodos: groupUpcomingTodosByDate(),
            selectedTodoId: selectedTodoId,
            editingTodoId: editingTodoId,
            editingText: $editingText,
            isDragActive: isDragActive,
            draggedTodo: draggedTodo,
            dropTargetDate: nil,
            onToggleComplete: { todo in
                // Just save the changes - the toggle is handled by DaySection
                saveTodoChanges()
            },
            onDeleteTodo: { todo in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    modelContext.delete(todo)
                    saveTodoChanges()
                }
            },
            onSelectTodo: { todo in
                selectedTodoId = todo.id
                keyboardMode = .navigation
            },
            onSaveEdit: saveEditedTodo,
            onCancelEdit: cancelEditingTodo,
            onDragStart: { todo, location in
                startDragging(todo: todo, at: location)
            },
            onDragChanged: { location in
                updateDrag(location: location)
            },
            onDragEnd: {
                endDrag()
            },
            onMoveTodoToDate: { todo, date in
                withAnimation(.easeInOut(duration: 0.3)) {
                    todo.dueDate = date
                    saveTodoChanges()
                }
            }
        )
    }
    
    // MARK: - Speed Todo List  
    private var speedTodoList: some View {
        ZStack {
            // Main todo list
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: isDragActive ? 8 : 12) {
                    let todos = displayTodos
                    
                    ForEach(Array(todos.enumerated()), id: \.element.id) { index, todo in
                        VStack(spacing: 0) {
                            // Drop zone indicator - shows where item will be dropped
                            if isDragActive && dropTargetIndex == index {
                                Capsule()
                                    .fill(.blue)
                                    .frame(height: 4)
                                    .padding(.horizontal, 20)
                                    .animation(.easeInOut(duration: 0.2), value: dropTargetIndex)
                            }
                            
                            // Enhanced todo card with drag handle
                            DraggableTodoCardView(
                                todo: todo,
                                index: index,
                                isBeingDragged: draggedTodo?.id == todo.id,
                                onComplete: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        todo.toggleCompletionOnDate(Date())
                                        saveTodoChanges()
                                    }
                                },
                                onDelete: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        modelContext.delete(todo)
                                        saveTodoChanges()
                                    }
                                },
                                onSchedule: {
                                    // Scheduling functionality removed
                                },
                                isSelected: selectedTodoId == todo.id,
                                isEditing: isEditingTodo && editingTodoId == todo.id,
                                editingText: $editingText,
                                onSaveEdit: saveEditedTodo,
                                onCancelEdit: cancelEditingTodo,
                                onSelect: {
                                    selectedTodoId = todo.id
                                },
                                onDragStart: { location in
                                    startDragging(todo: todo, at: location)
                                },
                                onDragChanged: { location in
                                    updateDrag(location: location)
                                },
                                onDragEnd: {
                                    endDrag()
                                }
                            )
                        }
                    }
                    
                    // Drop zone at the very bottom
                    if isDragActive && dropTargetIndex == displayTodos.count {
                        Capsule()
                            .fill(.blue)
                            .frame(height: 4)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .animation(.easeInOut(duration: 0.2), value: dropTargetIndex)
                    }
                }
                
                if displayTodos.isEmpty {
                    modernEmptyState
                }
            }
            .padding(.horizontal, 16)
            
            // Floating drag preview
            if let draggedTodo = draggedTodo, isDragActive {
                DragPreviewCard(todo: draggedTodo)
                    .position(dragPreviewPosition)
                    .zIndex(999)
                    .allowsHitTesting(false)
                    .animation(.easeOut(duration: 0.1), value: dragPreviewPosition)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 120) // Space for input
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
    
    // MARK: - Lightning Input Fixed (without Spacer)
    private var lightningInputFixed: some View {
        VStack(spacing: 12) {
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
                        .onTapGesture {
                            // Immediately clear selection when input is tapped
                            print("🔄 Input tapped - immediately clearing selection and switching to input mode")
                            selectedTodoId = nil
                            keyboardMode = .input
                        }
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
    
    // MARK: - Lightning Input (Original with Spacer)
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
            print("🔄 Todo creation state: \(taskCreationViewModel.state)")
            if case .completed = taskCreationViewModel.state {
                await MainActor.run {
                    print("✅ Clearing input field after successful todo creation")
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
        print("🔑 Key pressed: \(keyPress.key)")
        print("🔑 Characters: '\(keyPress.characters)' (count: \(keyPress.characters.count))")
        print("🔑 Character codes: \(keyPress.characters.map { String(format: "%02X", $0.asciiValue ?? 0) })")
        print("🔑 Input focused: \(isInputFocused)")
        print("🔑 Keyboard mode: \(keyboardMode)")
        print("🔑 Any text active: \(isAnyTextInputActive)")
        print("🔑 Selected todo ID: \(selectedTodoId?.uuidString ?? "none")")
        print("🔑 Current view: \(currentView)")
        
        // Handle editing shortcuts first (if in edit mode)
        if isEditingTodo {
            switch keyPress.key {
            case .return:
                saveEditedTodo()
                return .handled
            case .escape:
                cancelEditingTodo()
                return .handled
            default:
                return .ignored
            }
        }
        
        // Handle general keyboard navigation
        switch keyPress.key {
        case .upArrow:
            print("🔑 Up arrow detected")
            if currentView == .calendar {
                print("🔑 Delegating to calendar handler")
                return handleCalendarKeyPress(keyPress)
            } else {
                // Check for keyboard drag shortcuts first
                if keyPress.modifiers.contains(.command) && keyPress.modifiers.contains(.shift) {
                    if keyPress.modifiers.contains(.control) {
                        // Cmd+Shift+Ctrl+Up: Move to top
                        if keyboardMode == .navigation && selectedTodoId != nil {
                            moveSelectedTodoToTop()
                            return .handled
                        }
                    } else {
                        // Cmd+Shift+Up: Move up one position
                        if keyboardMode == .navigation && selectedTodoId != nil {
                            moveSelectedTodoUp()
                            return .handled
                        }
                    }
                }
                
                // Always handle up arrow for navigation, regardless of input focus
                if keyboardMode == .editing {
                    print("🔑 In editing mode, ignoring up arrow")
                    return .ignored
                } else {
                    // Switch to navigation mode if needed
                    if keyboardMode == .input {
                        print("🔑 Switching to navigation mode")
                        keyboardMode = .navigation
                        // Restore focus to main view for keyboard navigation
                        isMainViewFocused = true
                        // Select last todo if none selected
                        if selectedTodoId == nil {
                            let todos = navigableTodos
                            print("🔑 Available todos: \(todos.count)")
                            if !todos.isEmpty {
                                selectedTodoId = todos.last?.id
                                print("🔑 Selected last todo: \(todos.last?.title ?? "unknown")")
                            }
                        }
                    } else {
                        print("🔑 Already in navigation mode, calling navigateUp()")
                        navigateUp()
                    }
                    return .handled
                }
            }
            
        case .downArrow:
            print("🔑 Down arrow detected")
            if currentView == .calendar {
                print("🔑 Delegating to calendar handler")
                return handleCalendarKeyPress(keyPress)
            } else {
                // Check for keyboard drag shortcuts first
                if keyPress.modifiers.contains(.command) && keyPress.modifiers.contains(.shift) {
                    if keyPress.modifiers.contains(.control) {
                        // Cmd+Shift+Ctrl+Down: Move to bottom
                        if keyboardMode == .navigation && selectedTodoId != nil {
                            moveSelectedTodoToBottom()
                            return .handled
                        }
                    } else {
                        // Cmd+Shift+Down: Move down one position
                        if keyboardMode == .navigation && selectedTodoId != nil {
                            moveSelectedTodoDown()
                            return .handled
                        }
                    }
                }
                
                // Always handle down arrow for navigation, regardless of input focus
                if keyboardMode == .editing {
                    print("🔑 In editing mode, ignoring down arrow")
                    return .ignored
                } else {
                    // Switch to navigation mode if needed
                    if keyboardMode == .input {
                        print("🔑 Switching to navigation mode")
                        keyboardMode = .navigation
                        // Restore focus to main view for keyboard navigation
                        isMainViewFocused = true
                        // Select first todo if none selected
                        if selectedTodoId == nil {
                            let todos = navigableTodos
                            print("🔑 Available todos: \(todos.count)")
                            if !todos.isEmpty {
                                selectedTodoId = todos.first?.id
                                print("🔑 Selected first todo: \(todos.first?.title ?? "unknown")")
                            }
                        }
                    } else {
                        print("🔑 Already in navigation mode, calling navigateDown()")
                        navigateDown()
                    }
                    return .handled
                }
            }
            
        case .leftArrow, .rightArrow:
            // Only handle left/right for calendar view
            if currentView == .calendar {
                return handleCalendarKeyPress(keyPress)
            }
            return .ignored
            
        case .return:
            // Allow action only in navigation mode with a selected todo (not while editing)
            if keyboardMode == .navigation && selectedTodoId != nil {
                print("🔑 Enter key: Toggling completion (mode=\(keyboardMode), selected=\(selectedTodoId != nil))")
                toggleSelectedTodoCompletion()
                return .handled
            } else {
                print("🔑 Enter key: Ignoring (mode=\(keyboardMode), selected=\(selectedTodoId != nil))")
                return .ignored
            }
            
        case .delete:
            // Allow action only in navigation mode with a selected todo (not while editing or in input)
            if keyboardMode == .navigation && selectedTodoId != nil {
                print("🔑 Delete key: Deleting todo (mode=\(keyboardMode), selected=\(selectedTodoId != nil))")
                deleteSelectedTodo()
                return .handled
            } else {
                print("🔑 Delete key: Ignoring (mode=\(keyboardMode), selected=\(selectedTodoId != nil))")
                return .ignored
            }
            
        default:
            // Check for Cmd+E
            if keyPress.modifiers.contains(.command) && keyPress.characters == "e" {
                // Allow action only in navigation mode with a selected todo (not while editing or in input)
                if keyboardMode == .navigation && selectedTodoId != nil {
                    print("🔑 Cmd+E: Starting edit (mode=\(keyboardMode), selected=\(selectedTodoId != nil))")
                    startEditingSelectedTodo()
                    return .handled
                } else {
                    print("🔑 Cmd+E: Ignoring (mode=\(keyboardMode), selected=\(selectedTodoId != nil))")
                    return .ignored
                }
            }
            
            // Check for backspace (character code 7F)
            if keyPress.characters == "\u{7F}" {
                // Allow action only in navigation mode with a selected todo (not while editing or in input)
                if keyboardMode == .navigation && selectedTodoId != nil {
                    print("🔑 Backspace: Deleting todo (mode=\(keyboardMode), selected=\(selectedTodoId != nil))")
                    deleteSelectedTodo()
                    return .handled
                } else {
                    print("🔑 Backspace: Ignoring (mode=\(keyboardMode), selected=\(selectedTodoId != nil))")
                    return .ignored
                }
            }
            
            // Delegate to calendar handler for other keys in calendar view
            if currentView == .calendar {
                return handleCalendarKeyPress(keyPress)
            }
            
            print("🔑 Unhandled key in main handler")
            return .ignored
        }
    }
    
    private func handleCalendarKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        let calendar = Calendar.current
        
        switch keyPress.key {
        case .leftArrow:
            if let previousDay = calendar.date(byAdding: .day, value: -1, to: selectedDate) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDate = previousDay
                    // Reset todo selection when changing dates
                    selectedTodoId = nil
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
                    // Reset todo selection when changing dates
                    selectedTodoId = nil
                    // Update current month if we moved to a different month
                    if !calendar.isDate(nextDay, equalTo: currentMonth, toGranularity: .month) {
                        currentMonth = nextDay
                    }
                }
            }
            return .handled
            
        case .upArrow:
            // If shift is held, navigate through todos on current date
            if keyPress.modifiers.contains(.shift) {
                navigateUp()
                return .handled
            } else {
                // Otherwise navigate to previous week
                if let previousWeek = calendar.date(byAdding: .day, value: -7, to: selectedDate) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDate = previousWeek
                        selectedTodoId = nil
                        if !calendar.isDate(previousWeek, equalTo: currentMonth, toGranularity: .month) {
                            currentMonth = previousWeek
                        }
                    }
                }
                return .handled
            }
            
        case .downArrow:
            // If shift is held, navigate through todos on current date
            if keyPress.modifiers.contains(.shift) {
                navigateDown()
                return .handled
            } else {
                // Otherwise navigate to next week
                if let nextWeek = calendar.date(byAdding: .day, value: 7, to: selectedDate) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDate = nextWeek
                        selectedTodoId = nil
                        if !calendar.isDate(nextWeek, equalTo: currentMonth, toGranularity: .month) {
                            currentMonth = nextWeek
                        }
                    }
                }
                return .handled
            }
            
        case .return:
            // Allow action only in navigation mode with a selected todo (not while editing or in input)
            if keyboardMode == .navigation && selectedTodoId != nil {
                print("🔑 Calendar Enter key: Toggling completion (mode=\(keyboardMode), selected=\(selectedTodoId != nil))")
                toggleSelectedTodoCompletion()
                return .handled
            } else {
                print("🔑 Calendar Enter key: Ignoring (mode=\(keyboardMode), selected=\(selectedTodoId != nil))")
                return .ignored
            }
            
        case .delete:
            // Allow action only in navigation mode with a selected todo (not while editing or in input)
            if keyboardMode == .navigation && selectedTodoId != nil {
                print("🔑 Calendar Delete: Deleting todo (mode=\(keyboardMode), selected=\(selectedTodoId != nil))")
                deleteSelectedTodo()
                return .handled
            } else {
                print("🔑 Calendar Delete: Ignoring (mode=\(keyboardMode), selected=\(selectedTodoId != nil))")
                return .ignored
            }
            
        default:
            // Check for Cmd+E
            if keyPress.modifiers.contains(.command) && keyPress.characters == "e" {
                // Allow action only in navigation mode with a selected todo (not while editing or in input)
                if keyboardMode == .navigation && selectedTodoId != nil {
                    print("🔑 Calendar Cmd+E: Starting edit (mode=\(keyboardMode), selected=\(selectedTodoId != nil))")
                    startEditingSelectedTodo()
                    return .handled
                } else {
                    print("🔑 Calendar Cmd+E: Ignoring (mode=\(keyboardMode), selected=\(selectedTodoId != nil))")
                    return .ignored
                }
            }
            
            // Check for backspace (character code 7F)
            if keyPress.characters == "\u{7F}" {
                // Allow action only in navigation mode with a selected todo (not while editing or in input)
                if keyboardMode == .navigation && selectedTodoId != nil {
                    print("🔑 Calendar Backspace: Deleting todo (mode=\(keyboardMode), selected=\(selectedTodoId != nil))")
                    deleteSelectedTodo()
                    return .handled
                } else {
                    print("🔑 Calendar Backspace: Ignoring (mode=\(keyboardMode), selected=\(selectedTodoId != nil))")
                    return .ignored
                }
            }
            
            return .ignored
        }
    }
    
    // MARK: - Recurring Task Logic
    
    /// Helper function to determine if a todo should appear on a specific date
    private func shouldTodoAppearOnDate(_ todo: Todo, date: Date, includeCompleted: Bool = false) -> Bool {
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
        
        // Hide todos that are completed on this specific date (only if includeCompleted is false)
        if !includeCompleted && todo.isCompletedOnDate(date) {
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
    
    // MARK: - Keyboard Navigation Properties
    let isSelected: Bool
    let isEditing: Bool
    @Binding var editingText: String
    let onSaveEdit: () -> Void
    let onCancelEdit: () -> Void
    let onSelect: () -> Void
    
    @State private var isPressed = false
    @State private var swipeOffset: CGFloat = 0
    @FocusState private var isEditFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Completion circle - with explicit tap gesture to ensure it works
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
            .frame(width: 32, height: 32) // Larger hit area
            .contentShape(Circle()) // Ensure entire area is tappable
            .onTapGesture {
                print("🟢 Bubble tapped for todo: \(todo.title)")
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    onComplete()
                }
            }
            
            // Todo content
            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    // Edit mode: show text field
                    TextField("Todo title", text: $editingText)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                        .textFieldStyle(.plain)
                        .focused($isEditFieldFocused)
                        .onSubmit {
                            onSaveEdit()
                        }
                        .onAppear {
                            isEditFieldFocused = true
                        }
                } else {
                    // Normal mode: show text
                    Text(todo.title)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(todo.isCompleted ? .white.opacity(0.5) : .white)
                        .strikethrough(todo.isCompleted, color: .white.opacity(0.5))
                        .lineLimit(3)
                }
                
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
                .fill(backgroundFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .offset(x: swipeOffset)
        .gesture(
            DragGesture(minimumDistance: 15)
                .onChanged { value in
                    // Only start swiping if the drag starts from the right side (not on the button)
                    if value.startLocation.x > 50 {
                        swipeOffset = value.translation.width * 0.5
                    }
                }
                .onEnded { value in
                    // Only complete swipe actions if drag started from the right side
                    if value.startLocation.x > 50 {
                        if value.translation.width > 100 {
                            onComplete()
                        } else if value.translation.width < -100 {
                            onDelete()
                        }
                    }
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        swipeOffset = 0
                    }
                }
        )
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: swipeOffset)
        .onTapGesture {
            onSelect()
        }
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
    }
    
    // MARK: - Visual State Helpers
    
    private var backgroundFill: Color {
        if isSelected {
            return isEditing ? .cyan.opacity(0.15) : .cyan.opacity(0.08)
        } else {
            return .white.opacity(todo.isCompleted ? 0.03 : 0.08)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return isEditing ? .cyan.opacity(0.8) : .cyan.opacity(0.5)
        } else {
            return .white.opacity(0.1)
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
        withAnimation(.easeInOut(duration: 0.2)) {
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

// MARK: - Upcoming Timeline Components

/// Compact todo card optimized for day sections
struct CompactTodoCard: View {
    let todo: Todo
    let date: Date
    let onComplete: () -> Void
    let onDelete: () -> Void
    
    // MARK: - Keyboard Navigation Properties
    let isSelected: Bool
    let isEditing: Bool
    @Binding var editingText: String
    let onSaveEdit: () -> Void
    let onCancelEdit: () -> Void
    let onSelect: () -> Void
    
    // MARK: - Drag and Drop Properties
    let isBeingDragged: Bool
    let onDragStart: (CGPoint) -> Void
    let onDragChanged: (CGPoint) -> Void
    let onDragEnd: () -> Void
    
    @State private var swipeOffset: CGFloat = 0
    @FocusState private var isEditFieldFocused: Bool
    
    private var timeDisplay: String {
        if let dueTime = todo.dueTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: dueTime)
        }
        return ""
    }
    
    private var timeOfDayLabel: String {
        guard let dueTime = todo.dueTime else { return "" }
        let hour = Calendar.current.component(.hour, from: dueTime)
        
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default: return "Night"
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Drag handle
            DragHandle()
                .opacity(isBeingDragged ? 0.3 : 1.0)
                .draggable(todo.id.uuidString)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 5, coordinateSpace: .global)
                        .onChanged { value in
                            if !isBeingDragged {
                                onDragStart(value.startLocation)
                            }
                            onDragChanged(value.location)
                        }
                        .onEnded { _ in
                            onDragEnd()
                        }
                )
            
            // Card content
            HStack(spacing: 12) {
                // Completion button - with explicit tap gesture to ensure it works
                ZStack {
                Circle()
                    .stroke(todo.isCompletedOnDate(date) ? .green : .white.opacity(0.4), lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                if todo.isCompletedOnDate(date) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            .frame(width: 28, height: 28) // Larger hit area
            .contentShape(Circle()) // Ensure entire area is tappable
            .onTapGesture {
                print("🟢 Compact bubble tapped for todo: \(todo.title)")
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    onComplete()
                }
            }
            
            // Todo content
            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    // Edit mode: show text field
                    TextField("Todo title", text: $editingText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .textFieldStyle(.plain)
                        .focused($isEditFieldFocused)
                        .onSubmit {
                            onSaveEdit()
                        }
                        .onAppear {
                            isEditFieldFocused = true
                        }
                } else {
                    // Normal mode: show text
                    Text(todo.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(todo.isCompletedOnDate(date) ? .white.opacity(0.5) : .white)
                        .strikethrough(todo.isCompletedOnDate(date), color: .white.opacity(0.5))
                        .lineLimit(2)
                }
                
                if !timeDisplay.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10, weight: .medium))
                        
                        Text(timeDisplay)
                            .font(.system(size: 11, weight: .medium))
                        
                        if !timeOfDayLabel.isEmpty {
                            Text("•")
                                .font(.system(size: 8))
                            
                            Text(timeOfDayLabel)
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Priority/type indicator
            VStack(spacing: 2) {
                if todo.isRecurring {
                    Image(systemName: "repeat")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.cyan.opacity(0.8))
                } else {
                    Circle()
                        .fill(priorityColor(for: todo.actualPriority))
                        .frame(width: 6, height: 6)
                        .opacity(todo.isCompletedOnDate(date) ? 0.5 : 0.8)
                }
            }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(backgroundFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
                )
        )
        .offset(x: swipeOffset)
        .simultaneousGesture(
            DragGesture(minimumDistance: 15, coordinateSpace: .local)
                .onChanged { value in
                    // Only start swiping if the drag starts from the right side (not on drag handle)
                    // Drag handle is ~32px wide, add some buffer
                    if value.startLocation.x > 50 {
                        if value.translation.width < 0 {
                            swipeOffset = max(value.translation.width * 0.3, -80)
                        } else if value.translation.width > 0 {
                            swipeOffset = min(value.translation.width * 0.3, 80)
                        }
                    }
                }
                .onEnded { value in
                    // Only complete swipe actions if drag started from the right side
                    if value.startLocation.x > 50 {
                        if value.translation.width > 60 {
                            onComplete()
                        } else if value.translation.width < -60 {
                            onDelete()
                        }
                    }
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        swipeOffset = 0
                    }
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: swipeOffset)
        .onTapGesture {
            onSelect()
        }
        .opacity(isBeingDragged ? 0.5 : 1.0)
        }
    }
    
    // MARK: - Visual State Helpers
    
    private var backgroundFill: Color {
        if isSelected {
            return isEditing ? .cyan.opacity(0.12) : .cyan.opacity(0.06)
        } else {
            return .white.opacity(todo.isCompletedOnDate(date) ? 0.03 : 0.06)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return isEditing ? .cyan.opacity(0.6) : .cyan.opacity(0.4)
        } else {
            return .white.opacity(0.08)
        }
    }
    
    private func priorityColor(for priority: TaskPriority) -> Color {
        switch priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

/// Day section with timeline header and todos
struct DaySection: View {
    let date: Date
    let todos: [Todo]
    let isFirst: Bool
    let selectedTodoId: UUID?
    let editingTodoId: UUID?
    @Binding var editingText: String
    let isDragActive: Bool
    let draggedTodo: Todo?
    let onToggleComplete: (Todo) -> Void
    let onDeleteTodo: (Todo) -> Void
    let onSelectTodo: (Todo) -> Void
    let onSaveEdit: () -> Void
    let onCancelEdit: () -> Void
    let onDragStart: (Todo, CGPoint) -> Void
    let onDragChanged: (CGPoint) -> Void
    let onDragEnd: () -> Void
    let onMoveTodoToDate: (Todo, Date) -> Void
    
    @State private var isDropTargeted = false
    
    private var dayTitle: String {
        let calendar = Calendar.current
        let today = Date()
        
        if calendar.isDate(date, inSameDayAs: today) {
            return "Today"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: today) ?? today) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
    }
    
    private var dateSubtitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private var isWeekend: Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // Sunday or Saturday
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Timeline connection line (except for first item)
            if !isFirst {
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 2, height: 20)
                    .padding(.leading, 11)
            }
            
            // Day header with timeline dot
            HStack(spacing: 16) {
                // Timeline dot
                ZStack {
                    Circle()
                        .fill(isWeekend ? .cyan.opacity(0.3) : .white.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.4), lineWidth: 2)
                        )
                    
                    Circle()
                        .fill(isWeekend ? .cyan : .white.opacity(0.8))
                        .frame(width: 8, height: 8)
                }
                
                // Day info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(dayTitle)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(dateSubtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    let activeTasks = todos.filter { !$0.isCompletedOnDate(date) }.count
                    let totalTasks = todos.count
                    
                    Text(activeTasks == totalTasks ? "\(totalTasks) tasks" : "\(activeTasks) of \(totalTasks) remaining")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Completion progress
                if !todos.isEmpty {
                    let completedCount = todos.filter { $0.isCompletedOnDate(date) }.count
                    let progress = Double(completedCount) / Double(todos.count)
                    
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 3)
                            .frame(width: 28, height: 28)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 28, height: 28)
                            .rotationEffect(.degrees(-90))
                        
                        if progress == 1.0 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .padding(.bottom, 16)
            
            // Todos for this day
            VStack(spacing: 8) {
                ForEach(todos, id: \.id) { todo in
                    CompactTodoCard(
                        todo: todo,
                        date: date,
                        onComplete: { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                todo.toggleCompletionOnDate(date)
                            }
                            onToggleComplete(todo)
                        },
                        onDelete: { onDeleteTodo(todo) },
                        isSelected: selectedTodoId == todo.id,
                        isEditing: editingTodoId == todo.id,
                        editingText: $editingText,
                        onSaveEdit: onSaveEdit,
                        onCancelEdit: onCancelEdit,
                        onSelect: {
                            onSelectTodo(todo)
                        },
                        isBeingDragged: draggedTodo?.id == todo.id,
                        onDragStart: { location in
                            onDragStart(todo, location)
                        },
                        onDragChanged: onDragChanged,
                        onDragEnd: onDragEnd
                    )
                    .padding(.leading, 40) // Align with timeline
                }
            }
            .padding(.bottom, 24)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isDropTargeted ? Color.blue.opacity(0.1) : Color.clear)
                .animation(.easeInOut(duration: 0.2), value: isDropTargeted)
        )
        .dropDestination(for: String.self) { droppedItems, location in
            // Handle todo drop from other days
            guard let todoIdString = droppedItems.first,
                  let todoId = UUID(uuidString: todoIdString) else {
                isDropTargeted = false
                return false
            }
            
            // Find the dragged todo - it might not be in this day's todos
            if let todo = draggedTodo, todo.id == todoId {
                // Move todo to this date if it's different
                if todo.dueDate != date {
                    onMoveTodoToDate(todo, date)
                }
                isDropTargeted = false
                return true
            }
            
            isDropTargeted = false
            return false
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }
}

/// Main upcoming timeline view
struct UpcomingTimelineView: View {
    let groupedTodos: [(Date, [Todo])]
    let selectedTodoId: UUID?
    let editingTodoId: UUID?
    @Binding var editingText: String
    let isDragActive: Bool
    let draggedTodo: Todo?
    let dropTargetDate: Date?
    let onToggleComplete: (Todo) -> Void
    let onDeleteTodo: (Todo) -> Void
    let onSelectTodo: (Todo) -> Void
    let onSaveEdit: () -> Void
    let onCancelEdit: () -> Void
    let onDragStart: (Todo, CGPoint) -> Void
    let onDragChanged: (CGPoint) -> Void
    let onDragEnd: () -> Void
    let onMoveTodoToDate: (Todo, Date) -> Void
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            if groupedTodos.isEmpty {
                upcomingEmptyState
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(groupedTodos.enumerated()), id: \.offset) { index, dayGroup in
                        DaySection(
                            date: dayGroup.0,
                            todos: dayGroup.1,
                            isFirst: index == 0,
                            selectedTodoId: selectedTodoId,
                            editingTodoId: editingTodoId,
                            editingText: $editingText,
                            isDragActive: isDragActive,
                            draggedTodo: draggedTodo,
                            onToggleComplete: { todo in
                                onToggleComplete(todo)
                            },
                            onDeleteTodo: { todo in
                                onDeleteTodo(todo)
                            },
                            onSelectTodo: onSelectTodo,
                            onSaveEdit: onSaveEdit,
                            onCancelEdit: onCancelEdit,
                            onDragStart: onDragStart,
                            onDragChanged: onDragChanged,
                            onDragEnd: onDragEnd,
                            onMoveTodoToDate: onMoveTodoToDate
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 100) // Reduced space since input is overlaid
            }
        }
    }
    
    private var upcomingEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.day.timeline.right")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(.white.opacity(0.3))
            
            VStack(spacing: 8) {
                Text("Free week ahead!")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("No upcoming tasks scheduled")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.top, 60)
    }
}

// MARK: - Professional Drag & Drop Components

/// A todo card with a dedicated drag handle for professional drag and drop
struct DraggableTodoCardView: View {
    let todo: Todo
    let index: Int
    let isBeingDragged: Bool
    let onComplete: () -> Void
    let onDelete: () -> Void
    let onSchedule: () -> Void
    let isSelected: Bool
    let isEditing: Bool
    @Binding var editingText: String
    let onSaveEdit: () -> Void
    let onCancelEdit: () -> Void
    let onSelect: () -> Void
    let onDragStart: (CGPoint) -> Void
    let onDragChanged: (CGPoint) -> Void
    let onDragEnd: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Drag handle - only this area is draggable
            DragHandle()
                .opacity(isBeingDragged ? 0.3 : 1.0)
                .gesture(
                    DragGesture(coordinateSpace: .global)
                        .onChanged { value in
                            if !isBeingDragged {
                                onDragStart(value.startLocation)
                            }
                            onDragChanged(value.location)
                        }
                        .onEnded { _ in
                            onDragEnd()
                        }
                )
            
            // Regular todo card - maintains all existing functionality
            ModernTodoCard(
                todo: todo,
                onComplete: onComplete,
                onDelete: onDelete,
                onSchedule: onSchedule,
                isSelected: isSelected,
                isEditing: isEditing,
                editingText: $editingText,
                onSaveEdit: onSaveEdit,
                onCancelEdit: onCancelEdit,
                onSelect: onSelect
            )
            .opacity(isBeingDragged ? 0.3 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isBeingDragged)
        }
    }
}

/// Drag handle with professional grip dots
struct DragHandle: View {
    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 3) {
                    ForEach(0..<2, id: \.self) { _ in
                        Circle()
                            .fill(.white.opacity(0.4))
                            .frame(width: 3, height: 3)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

/// Floating drag preview that follows the cursor
struct DragPreviewCard: View {
    let todo: Todo
    
    var body: some View {
        HStack(spacing: 16) {
            // Completion indicator
            Circle()
                .stroke(.green.opacity(0.6), lineWidth: 2)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .fill(.green.opacity(0.2))
                )
            
            // Todo title
            Text(todo.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(0.2))
                )
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
        )
        .scaleEffect(1.05)
        .rotationEffect(.degrees(3))
    }
}

#Preview {
    ModernSpeedContentView()
}