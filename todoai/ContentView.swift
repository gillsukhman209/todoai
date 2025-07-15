//
//  ContentView.swift
//  todoai
//
//  Created by Sukhman Singh on 7/14/25.
//

import SwiftUI
import SwiftData

// MARK: - View Types
enum TodoViewType: String, CaseIterable {
    case inbox = "Inbox"
    case today = "Today"
    case upcoming = "Upcoming"
    
    var icon: String {
        switch self {
        case .inbox: return "tray.fill"
        case .today: return "calendar"
        case .upcoming: return "calendar.badge.clock"
        }
    }
}

// MARK: - Professional Design System
extension Color {
    // Beautiful purple/teal professional color palette
    static let accent = Color(red: 0.4, green: 0.6, blue: 0.9) // Vibrant blue
    static let accentSecondary = Color(red: 0.3, green: 0.7, blue: 0.8) // Rich teal
    
    // Professional backgrounds with glass effect
    static let cardBackground = Color.white.opacity(0.1)
    static let hoverBackground = Color.white.opacity(0.15)
    
    // Clean primary background for sidebars
    static let primaryBackground = Color.black.opacity(0.2)
    
    // Text colors optimized for dark gradient
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.8)
    static let tertiaryText = Color.white.opacity(0.6)
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [Todo]
    @State private var showSidebar = true
    @State private var showingAPIKeySetup = false
    @State private var showingSchedulingView = false
    @State private var selectedTodoForScheduling: Todo?
    @State private var taskCreationViewModel: TaskCreationViewModel?
    @State private var selectedView: TodoViewType = .inbox
    @State private var focusInputTrigger = false
    
    init() {
        // Initialize the state as nil - will be properly set up in onAppear
        _taskCreationViewModel = State(initialValue: nil)
    }
    
    // MARK: - Computed Properties
    
    private var filteredTodos: [Todo] {
        switch selectedView {
        case .inbox:
            return todos
        case .today:
            return todayTodos
        case .upcoming:
            return upcomingTodos
        }
    }
    
    private var todayTodos: [Todo] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return todos.filter { todo in
            // Include if due today
            if let dueDate = todo.dueDate {
                return calendar.isDate(dueDate, inSameDayAs: today)
            }
            
            // Include if created today (even without due date)
            return calendar.isDate(todo.createdAt, inSameDayAs: today)
        }
    }
    
    private var upcomingTodos: [Todo] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today)!
        
        return todos.filter { todo in
            // Include if has due date in the next 7 days
            if let dueDate = todo.dueDate {
                return dueDate >= today && dueDate < nextWeek
            }
            
            // Include if created in the next 7 days (for recurring tasks)
            return todo.createdAt >= today && todo.createdAt < nextWeek
        }
    }
    
    private var groupedUpcomingTodos: [(String, Date, [Todo])] {
        let calendar = Calendar.current
        let today = Date()
        var groups: [(String, Date, [Todo])] = []
        
        // Create groups for each day of the week (always show all 7 days)
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: i, to: calendar.startOfDay(for: today))!
            let dayName = calendar.weekdaySymbols[calendar.component(.weekday, from: date) - 1]
            let dateString = i == 0 ? "Today" : (i == 1 ? "Tomorrow" : dayName)
            groups.append((dateString, date, []))
        }
        
        // Group todos by their due date or creation date
        for todo in todos { // Use all todos, not just upcomingTodos
            let targetDate = todo.dueDate ?? todo.createdAt
            let daysDiff = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: targetDate)).day ?? 0
            
            if daysDiff >= 0 && daysDiff < 7 {
                if let index = groups.firstIndex(where: { Calendar.current.isDate($0.1, inSameDayAs: targetDate) }) {
                    groups[index].2.append(todo)
                }
            }
        }
        
        // Sort todos within each day
        for i in 0..<groups.count {
            groups[i].2.sort { $0.createdAt > $1.createdAt }
        }
        
        return groups
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Main content area
            TodoListView(
                todos: filteredTodos,
                selectedView: selectedView,
                groupedUpcomingTodos: groupedUpcomingTodos,
                onDeleteTodo: deleteTodo,
                onToggleComplete: toggleTodoComplete,
                onScheduleTodo: showSchedulingView,
                onMoveTodo: moveTodoToDay,
                onCompleteCleanup: completeCleanup,
                showSidebar: $showSidebar,
                onFocusInput: focusTaskInput
            )
            .padding(.leading, showSidebar ? 280 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showSidebar)
            
            // Custom floating sidebar
            if showSidebar {
                FloatingSidebarView(
                    activeTodoCount: filteredTodos.filter { !$0.isCompleted }.count,
                    selectedView: selectedView,
                    onViewChange: { newView in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedView = newView
                        }
                    },
                    onDismiss: { 
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSidebar = false
                        }
                    },
                    onSettings: {
                        showingAPIKeySetup = true
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            
            // Persistent Floating Input
            if let viewModel = taskCreationViewModel {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingTaskInputContainer(
                            viewModel: viewModel,
                            focusTrigger: focusInputTrigger
                        )
                        Spacer()
                    }
                    .zIndex(100)
                }
                .allowsHitTesting(true)
            }
            
            // API Key Setup Overlay
            if showingAPIKeySetup {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showingAPIKeySetup = false
                        }
                    
                    APIKeySetupView(isPresented: $showingAPIKeySetup)
                        .padding(32)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(200)
            }
            
            // Scheduling View Overlay
            if showingSchedulingView, let selectedTodo = selectedTodoForScheduling {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showingSchedulingView = false
                            selectedTodoForScheduling = nil
                        }
                    
                    SchedulingView(
                        todo: selectedTodo,
                        onScheduled: {
                            showingSchedulingView = false
                            selectedTodoForScheduling = nil
                        }
                    )
                    .padding(32)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(300)
            }
        }
        .background(
            // Premium singular gradient - Stunning purple-to-teal spectrum
            LinearGradient(
                colors: [
                    Color(red: 0.25, green: 0.12, blue: 0.40),   // Rich deep purple
                    Color(red: 0.22, green: 0.15, blue: 0.45),   // Purple-violet
                    Color(red: 0.18, green: 0.20, blue: 0.50),   // Blue-purple
                    Color(red: 0.15, green: 0.25, blue: 0.55),   // Deep blue
                    Color(red: 0.12, green: 0.35, blue: 0.60),   // Ocean blue
                    Color(red: 0.10, green: 0.45, blue: 0.65),   // Blue-teal
                    Color(red: 0.08, green: 0.55, blue: 0.70)    // Beautiful teal
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(.all) // Extend into title bar area
        )
        .preferredColorScheme(.dark) // Ensure dark mode for proper text contrast
        .onAppear {
            self.setupTaskCreationViewModel()
        }
        .onChange(of: taskCreationViewModel?.state) { oldValue, newValue in
            if case .completed = newValue {
                // Reset the input when task is created
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    taskCreationViewModel?.resetState()
                }
            }
        }
    }
    
    private func setupTaskCreationViewModel() {
        // Initialize the view model with the proper model context
        // API key is read from UserDefaults - set it up via Settings
        let openAIService = OpenAIService()
        taskCreationViewModel = TaskCreationViewModel(
            openAIService: openAIService,
            modelContext: modelContext
        )
    }
    
    private func focusTaskInput() {
        focusInputTrigger.toggle()
    }
    

    
    private func deleteTodo(_ todo: Todo) {
        withAnimation(.easeInOut(duration: 0.25)) {
            // Cancel any pending notifications for this task before deleting
            Task {
                await NotificationService.shared.cancelAllNotifications(for: todo.id)
            }
            
            // Delete the task from the database
            modelContext.delete(todo)
        }
    }
    
    private func toggleTodoComplete(_ todo: Todo) {
        withAnimation(.easeInOut(duration: 0.2)) {
            todo.isCompleted.toggle()
        }
    }
    
    private func showSchedulingView(for todo: Todo) {
        selectedTodoForScheduling = todo
        withAnimation(.easeInOut(duration: 0.3)) {
            showingSchedulingView = true
        }
    }
    
    private func moveTodoToDay(_ todo: Todo, to targetDate: Date) {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Update the todo's due date to the target date
            todo.dueDate = targetDate
            
            // Keep the same time if it exists, otherwise set to current time
            if let existingTime = todo.dueTime {
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: existingTime)
                todo.dueDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: targetDate)
            }
            
            // Save the changes
            try? modelContext.save()
        }
    }
    
    private func completeCleanup() async {
        print("🧹 Starting complete cleanup...")
        
        // Step 1: Delete all todos from the database
        print("🗑️ Deleting all todos...")
        withAnimation(.easeInOut(duration: 0.25)) {
            for todo in todos {
                modelContext.delete(todo)
            }
        }
        
        // Step 2: Cancel all pending notifications
        print("🔔 Cancelling all notifications...")
        NotificationService.shared.cancelAllNotifications()
        
        // Step 3: Save the model context to commit deletions
        try? modelContext.save()
        
        // Step 4: Wait a moment for cleanup to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Step 5: Show debug info
        print("🔍 Showing debug info after cleanup...")
        await TaskScheduler.shared.debugScheduledNotifications()
        
        print("✅ Complete cleanup finished!")
    }
}

struct FloatingSidebarView: View {
    let activeTodoCount: Int
    let selectedView: TodoViewType
    let onViewChange: (TodoViewType) -> Void
    let onDismiss: () -> Void
    let onSettings: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with dismiss button
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TodoAI")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Color.primaryText)
                    
                    Text("Task Management")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.secondaryText)
                }
                
                Spacer()
                
                // Dismiss button
                Button(action: onDismiss) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.secondaryText)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                .onHover { hovering in
                    isHovered = hovering
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            // Navigation items
            VStack(spacing: 8) {
                ForEach(TodoViewType.allCases, id: \.self) { viewType in
                    SidebarItemView(
                        icon: viewType.icon,
                        title: viewType.rawValue,
                        count: viewType == .inbox ? activeTodoCount : nil,
                        isSelected: selectedView == viewType,
                        onTap: {
                            onViewChange(viewType)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            // Footer
            VStack(spacing: 12) {
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // Settings button
                Button(action: onSettings) {
                    HStack(spacing: 12) {
                        Image(systemName: "gear")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.secondaryText)
                            .frame(width: 20)
                        
                        Text("Settings")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.secondaryText)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                
                Text("⌘+B to toggle sidebar")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.tertiaryText)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 24)
        }
        .frame(width: 260)
        .background(
            // Premium sidebar gradient - Purple/teal theme
            ZStack {
                // Main gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.28, green: 0.15, blue: 0.42).opacity(0.95),   // Deep purple
                        Color(red: 0.22, green: 0.25, blue: 0.48).opacity(0.9),   // Purple-blue
                        Color(red: 0.18, green: 0.35, blue: 0.55).opacity(0.95)   // Blue-teal
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Glass overlay
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
                
                // Accent highlight
                LinearGradient(
                    colors: [
                        Color.accent.opacity(0.2),
                        Color.clear,
                        Color.accentSecondary.opacity(0.15)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.overlay)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 25, x: 0, y: 10)
        .padding(.leading, 20)
        .padding(.vertical, 20)
    }
}

struct SidebarItemView: View {
    let icon: String
    let title: String
    let count: Int?
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelected ? Color.accent : Color.secondaryText)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? Color.primaryText : Color.secondaryText)
            
            Spacer()
            
            if let count = count, count > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accent)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accent.opacity(0.2) : (isHovered ? Color.white.opacity(0.1) : Color.clear))
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            if !isSelected {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}

struct TodoListView: View {
    let todos: [Todo]
    let selectedView: TodoViewType
    let groupedUpcomingTodos: [(String, Date, [Todo])]
    let onDeleteTodo: (Todo) -> Void
    let onToggleComplete: (Todo) -> Void
    let onScheduleTodo: (Todo) -> Void
    let onMoveTodo: (Todo, Date) -> Void
    let onCompleteCleanup: () async -> Void
    @Binding var showSidebar: Bool
    let onFocusInput: () -> Void
    @FocusState private var isMainViewFocused: Bool
    @State private var focusedTodoID: UUID?
    @State private var editingTodoID: UUID?
    
    var activeTodos: [Todo] {
        todos.filter { !$0.isCompleted }.sorted { $0.createdAt > $1.createdAt }
    }
    
    var completedTodos: [Todo] {
        todos.filter { $0.isCompleted }.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Professional header
                HStack {
                    // Toggle sidebar button
                    if !showSidebar {
                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showSidebar = true
                            }
                        }) {
                            Image(systemName: "sidebar.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.secondaryText)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedView.rawValue)
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .foregroundColor(Color.primaryText)
                        
                        if !activeTodos.isEmpty {
                            Text("\(activeTodos.count) task\(activeTodos.count == 1 ? "" : "s")")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.secondaryText)
                        } else {
                            Text(selectedView == .today ? "No tasks for today" : "All caught up")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.secondaryText)
                        }
                    }
                    
                    Spacer()
                    
                    // Debug button for notifications
                    Button(action: {
                        print("🔔 Debug button clicked!")
                        Task {
                            await TaskScheduler.shared.debugScheduledNotifications()
                        }
                    }) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.secondaryText)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Debug scheduled notifications")
                    
                    // Cleanup button for notifications
                    Button(action: {
                        print("🧹 Complete cleanup button clicked!")
                        Task {
                            await onCompleteCleanup()
                        }
                    }) {
                        Image(systemName: "trash.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.secondaryText)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Delete all todos and notifications")
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                // Clean task list
                LazyVStack(spacing: 8) {
                    if selectedView == .upcoming {
                        // Upcoming view - grouped by day
                        ForEach(groupedUpcomingTodos, id: \.0) { dayName, dayDate, dayTodos in
                            DayGroupView(
                                dayName: dayName,
                                dayDate: dayDate,
                                dayTodos: dayTodos,
                                allTodos: todos,
                                isFirst: dayName == groupedUpcomingTodos.first?.0,
                                onToggleComplete: onToggleComplete,
                                onDeleteTodo: onDeleteTodo,
                                onScheduleTodo: onScheduleTodo,
                                onMoveTodo: onMoveTodo,
                                focusedTodoID: focusedTodoID,
                                onFocus: { focusedTodoID = $0 },
                                editingTodoID: editingTodoID,
                                onEditingChange: { isEditing in
                                    if !isEditing {
                                        editingTodoID = nil
                                    }
                                }
                            )
                        }
                    } else {
                        // Regular view (Inbox or Today)
                        // Active todos
                        ForEach(activeTodos) { todo in
                            TodoRowView(
                                todo: todo,
                                onToggleComplete: { onToggleComplete(todo) },
                                onDelete: { onDeleteTodo(todo) },
                                onSchedule: { onScheduleTodo(todo) },
                                isFocused: focusedTodoID == todo.id,
                                onFocus: { focusedTodoID = todo.id },
                                isEditingTriggered: editingTodoID == todo.id,
                                onEditingChange: { isEditing in
                                    if !isEditing {
                                        editingTodoID = nil
                                    }
                                }
                            )
                            .padding(.horizontal, 32)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        
                        // Completed section
                        if !completedTodos.isEmpty {
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Completed")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color.secondaryText)
                                    
                                    Spacer()
                                    
                                    Text("\(completedTodos.count)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color.tertiaryText)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.tertiaryText.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 32)
                                .padding(.top, 24)
                                
                                ForEach(completedTodos) { todo in
                                    TodoRowView(
                                        todo: todo,
                                        onToggleComplete: { onToggleComplete(todo) },
                                        onDelete: { onDeleteTodo(todo) },
                                        onSchedule: { onScheduleTodo(todo) },
                                        isFocused: focusedTodoID == todo.id,
                                        onFocus: { focusedTodoID = todo.id },
                                        isEditingTriggered: editingTodoID == todo.id,
                                        onEditingChange: { isEditing in
                                            if !isEditing {
                                                editingTodoID = nil
                                            }
                                        }
                                    )
                                    .padding(.horizontal, 32)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                }
                            }
                        }
                    }
                    
                    // Bottom padding (extra space for floating input)
                    Color.clear.frame(height: 120)
                }
            }
        }
        .focusable()
        .focused($isMainViewFocused)
        .focusEffectDisabled() // Remove the blue focus ring
        .onKeyPress { keyPress in
            if keyPress.key == .upArrow {
                moveFocusUp()
                return .handled
            } else if keyPress.key == .downArrow {
                moveFocusDown()
                return .handled
            } else if keyPress.characters == "e" || keyPress.characters == "E" {
                // Handle edit on focused todo
                if let focusedID = focusedTodoID,
                   let focusedTodo = (activeTodos + completedTodos).first(where: { $0.id == focusedID }) {
                    startEditingTodo(focusedTodo)
                    return .handled
                }
            } else if keyPress.characters == "\u{8}" || keyPress.characters == "\u{7F}" {
                // Handle delete on focused todo
                if let focusedID = focusedTodoID,
                   let focusedTodo = (activeTodos + completedTodos).first(where: { $0.id == focusedID }) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        onDeleteTodo(focusedTodo)
                    }
                    return .handled
                }
            }
            return .ignored
        }
        .onTapGesture {
            isMainViewFocused = true
        }
        .onAppear {
            // Auto-focus the main view when it appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isMainViewFocused = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    // AI Smart Input Button
                    Button(action: {
                        onFocusInput()
                    }) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.accentSecondary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(KeyEquivalent("i"), modifiers: [.command])
                    
                    // Regular Add Button (now focuses input)
                    Button(action: {
                        onFocusInput()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.accent)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(KeyEquivalent("n"), modifiers: [.command])
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showSidebar.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.left")
                }
                .keyboardShortcut(KeyEquivalent("b"), modifiers: [.command])
                .opacity(0) // Hide the button but keep the shortcut
            }
        }
    }
    

    
    private func moveFocusUp() {
        let allTodos = activeTodos + completedTodos
        guard !allTodos.isEmpty else { return }
        
        // Ensure main view is focused for keyboard navigation
        if !isMainViewFocused {
            isMainViewFocused = true
        }
        
        if let focusedID = focusedTodoID,
           let currentIndex = allTodos.firstIndex(where: { $0.id == focusedID }) {
            if currentIndex > 0 {
                focusedTodoID = allTodos[currentIndex - 1].id
            } else {
                focusedTodoID = allTodos.last?.id
            }
        } else {
            focusedTodoID = allTodos.last?.id // Start from last when moving up
        }
    }
    
    private func moveFocusDown() {
        let allTodos = activeTodos + completedTodos
        guard !allTodos.isEmpty else { return }
        
        // Ensure main view is focused for keyboard navigation
        if !isMainViewFocused {
            isMainViewFocused = true
        }
        
        if let focusedID = focusedTodoID,
           let currentIndex = allTodos.firstIndex(where: { $0.id == focusedID }) {
            if currentIndex < allTodos.count - 1 {
                focusedTodoID = allTodos[currentIndex + 1].id
            } else {
                focusedTodoID = allTodos.first?.id
            }
        } else {
            focusedTodoID = allTodos.first?.id // Start from first when moving down
        }
    }
    
    private func startEditingTodo(_ todo: Todo) {
        editingTodoID = todo.id
    }
}



struct TodoRowView: View {
    var todo: Todo
    let onToggleComplete: () -> Void
    let onDelete: () -> Void
    let onSchedule: () -> Void
    let isFocused: Bool
    let onFocus: () -> Void
    let isEditingTriggered: Bool
    let onEditingChange: (Bool) -> Void
    @State private var isEditing = false
    @State private var editingTitle = ""
    @State private var isHovered = false
    @State private var hasScheduledNotifications = false
    @State private var showingInfo = false
    @FocusState private var isEditingFocused: Bool
    
    // Computed property to determine if task has additional information
    private var hasAdditionalInfo: Bool {
        return !todo.scheduleDescription.isEmpty || 
               !todo.upcomingReminders.isEmpty || 
               (todo.originalInput != nil && !todo.originalInput!.isEmpty && todo.originalInput != todo.title) ||
               todo.dueDate != nil ||
               todo.dueTime != nil ||
               todo.isRecurring ||
               hasScheduledNotifications
    }
    
    // Date formatters
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Professional checkbox with better hit area
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onToggleComplete()
                }
            }) {
                ZStack {
                    // Larger invisible hit area
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 32, height: 32)
                    
                    // Visible checkbox
                    Circle()
                        .fill(todo.isCompleted ? Color.accent : Color.clear)
                        .frame(width: 20, height: 20)
                    
                    Circle()
                        .strokeBorder(
                            todo.isCompleted ? Color.clear : Color.accent.opacity(0.3),
                            lineWidth: 1.5
                        )
                        .frame(width: 20, height: 20)
                    
                    if todo.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.borderless)
            .contentShape(Circle())
            
            // Clean title
            if isEditing {
                TextField("Task title", text: $editingTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.primaryText)
                    .focused($isEditingFocused)
                    .onSubmit {
                        saveEdit()
                    }
                    .textFieldStyle(.plain)
                    .background(Color.clear)
                    .overlay(
                        Rectangle()
                            .stroke(Color.clear)
                    )
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(todo.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(todo.isCompleted ? Color.tertiaryText : Color.primaryText)
                            .strikethrough(todo.isCompleted, color: Color.tertiaryText)
                            .onTapGesture(count: 2) {
                                startEditing()
                            }
                            .contextMenu {
                                Button("Edit") {
                                    startEditing()
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    onDelete()
                                }
                            }
                        
                        // Info icon
                        if hasAdditionalInfo {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showingInfo.toggle()
                                }
                            }) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(showingInfo ? Color.accent : Color.secondaryText)
                                    .opacity(isHovered ? 1.0 : 0.7)
                            }
                            .buttonStyle(.plain)
                            .help("Show additional information")
                        }
                        
                        Spacer()
                        
                        // Processing indicator
                        if todo.isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.accent))
                        }
                        
                        // Processing error indicator
                        if let processingError = todo.processingError {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                                .help(processingError)
                        }
                    }
                    
                    // Additional information (shown when info icon is clicked)
                    if showingInfo {
                        VStack(alignment: .leading, spacing: 6) {
                            // Due date and time
                            if let dueDate = todo.dueDate {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Color.accent)
                                    
                                    Text("Due: \(dueDate, formatter: dateFormatter)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color.tertiaryText)
                                }
                            }
                            
                            if let dueTime = todo.dueTime {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Color.accent)
                                    
                                    Text("Time: \(dueTime, formatter: timeFormatter)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color.tertiaryText)
                                }
                            }
                            
                            // Recurring status
                            if todo.isRecurring {
                                HStack(spacing: 4) {
                                    Image(systemName: "repeat")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Color.accent)
                                    
                                    Text("Recurring task")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color.tertiaryText)
                                }
                            }
                            
                            // Schedule information
                            if !todo.scheduleDescription.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Color.accent)
                                    
                                    Text(todo.scheduleDescription)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color.tertiaryText)
                                }
                            }
                            
                            // Upcoming reminders for recurring tasks
                            if !todo.upcomingReminders.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "bell")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(Color.accent)
                                        
                                        Text("Next reminders:")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(Color.accentSecondary)
                                    }
                                    
                                    ForEach(Array(todo.upcomingReminders.prefix(4).enumerated()), id: \.offset) { index, reminder in
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color.accentSecondary.opacity(0.6))
                                                .frame(width: 3, height: 3)
                                            
                                            Text(reminder)
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundColor(Color.tertiaryText)
                                        }
                                        .padding(.leading, 16)
                                    }
                                }
                            }
                            
                            // Notification status
                            if hasScheduledNotifications {
                                HStack(spacing: 4) {
                                    Image(systemName: "bell.badge")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Color.accent)
                                    
                                    Text("Notifications scheduled")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color.tertiaryText)
                                }
                            }
                            
                            // Original AI input (if available)
                            if let originalInput = todo.originalInput, !originalInput.isEmpty, originalInput != todo.title {
                                HStack(spacing: 4) {
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Color.accent)
                                    
                                    Text("From: \"\(originalInput)\"")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color.accent.opacity(0.6))
                                        .italic()
                                }
                            }
                        }
                        .padding(.top, 4)
                        .padding(.leading, 2)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        // Show minimal info when collapsed
                        if !todo.scheduleDescription.isEmpty || !todo.upcomingReminders.isEmpty {
                            Text(todo.scheduleDescription.isEmpty ? "Has scheduled reminders" : todo.scheduleDescription)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.tertiaryText)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Edit, schedule, and delete buttons
            if isHovered && !isEditing {
                HStack(spacing: 8) {
                    // Schedule button
                    Button(action: {
                        onSchedule()
                    }) {
                        Image(systemName: hasScheduledNotifications ? "bell.badge.fill" : "bell")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(hasScheduledNotifications ? Color.accent : Color.accentSecondary)
                            .frame(width: 24, height: 24)
                            .background((hasScheduledNotifications ? Color.accent : Color.accentSecondary).opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    // Edit button
                    Button(action: {
                        startEditing()
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.accent)
                            .frame(width: 24, height: 24)
                            .background(Color.accent.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    // Delete button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            onDelete()
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 24, height: 24)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // Glass background with hover and focus effects
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isFocused ? Color.accent.opacity(0.05) :
                        (isHovered ? Color.hoverBackground : Color.cardBackground)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                
                // Subtle border for all states
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            }
            .shadow(
                color: Color.black.opacity(isHovered ? 0.4 : 0.2), 
                radius: isHovered ? 15 : 8, 
                x: 0, 
                y: isHovered ? 8 : 4
            )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onFocus()
        }
        .onChange(of: isEditingTriggered) { oldValue, newValue in
            if newValue && !isEditing {
                startEditing()
            }
        }
        .task {
            // Check if task has scheduled notifications
            await refreshNotificationStatus()
        }
        .onChange(of: todo.id) { oldValue, newValue in
            // Refresh notification status when todo changes
            Task {
                await refreshNotificationStatus()
            }
        }
        .onChange(of: isEditing) { oldValue, newValue in
            onEditingChange(newValue)
        }
    }
    
    private func startEditing() {
        editingTitle = todo.title
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isEditingFocused = true
        }
    }
    
    private func refreshNotificationStatus() async {
        hasScheduledNotifications = await NotificationService.shared.hasScheduledNotifications(for: todo.id)
    }
    
    private func saveEdit() {
        let trimmedTitle = editingTitle.trimmingCharacters(in: .whitespaces)
        if !trimmedTitle.isEmpty {
            todo.title = trimmedTitle
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
            isEditingFocused = false
        }
    }
    
    private func cancelEdit() {
        editingTitle = todo.title
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
            isEditingFocused = false
        }
    }
}

// MARK: - Day Group View with Drag & Drop
struct DayGroupView: View {
    let dayName: String
    let dayDate: Date
    let dayTodos: [Todo]
    let allTodos: [Todo]  // Added to find todos by ID for drag & drop
    let isFirst: Bool
    let onToggleComplete: (Todo) -> Void
    let onDeleteTodo: (Todo) -> Void
    let onScheduleTodo: (Todo) -> Void
    let onMoveTodo: (Todo, Date) -> Void
    let focusedTodoID: UUID?
    let onFocus: (UUID) -> Void
    let editingTodoID: UUID?
    let onEditingChange: (Bool) -> Void
    
    @State private var isDropTargeted = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Day Header
            HStack {
                Text(dayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.secondaryText)
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Add task button
                    Button(action: {
                        let newTodo = Todo(title: "New task for \(dayName)")
                        newTodo.dueDate = dayDate
                        // Add to context and save
                        // Note: This is a simplified implementation - in a real app you'd want to open a proper input dialog
                        print("Add task for \(dayName) on \(dayDate)")
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.accent.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    
                    // Task count
                    Text("\(dayTodos.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.tertiaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.tertiaryText.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, isFirst ? 0 : 24)
            
            // Drop Zone
            VStack(spacing: 8) {
                if dayTodos.isEmpty {
                    // Empty state with drop zone
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDropTargeted ? Color.accent.opacity(0.2) : Color.clear)
                        .stroke(
                            isDropTargeted ? Color.accent : Color.white.opacity(0.1),
                            style: StrokeStyle(lineWidth: 2, dash: isDropTargeted ? [] : [8, 4])
                        )
                        .frame(height: 60)
                        .overlay(
                            Text(isDropTargeted ? "Drop here" : "No tasks • Drag tasks here")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isDropTargeted ? Color.accent : Color.tertiaryText)
                        )
                        .padding(.horizontal, 32)
                        .dropDestination(for: TodoReference.self) { todoRefs, location in
                            guard let todoRef = todoRefs.first,
                                  let todo = allTodos.first(where: { $0.id == todoRef.id }) else { return false }
                            onMoveTodo(todo, dayDate)
                            return true
                        } isTargeted: { targeted in
                            isDropTargeted = targeted
                        }
                } else {
                    // Tasks with drop zone
                    ForEach(dayTodos) { todo in
                        DraggableTodoRowView(
                            todo: todo,
                            onToggleComplete: { onToggleComplete(todo) },
                            onDelete: { onDeleteTodo(todo) },
                            onSchedule: { onScheduleTodo(todo) },
                            isFocused: focusedTodoID == todo.id,
                            onFocus: { onFocus(todo.id) },
                            isEditingTriggered: editingTodoID == todo.id,
                            onEditingChange: onEditingChange
                        )
                        .padding(.horizontal, 32)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    // Drop zone between tasks
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDropTargeted ? Color.accent.opacity(0.1) : Color.clear)
                        .stroke(
                            isDropTargeted ? Color.accent : Color.clear,
                            style: StrokeStyle(lineWidth: 2)
                        )
                        .frame(height: isDropTargeted ? 40 : 20)
                        .overlay(
                            Text(isDropTargeted ? "Drop here" : "")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.accent)
                        )
                        .padding(.horizontal, 32)
                        .dropDestination(for: TodoReference.self) { todoRefs, location in
                            guard let todoRef = todoRefs.first,
                                  let todo = allTodos.first(where: { $0.id == todoRef.id }) else { return false }
                            onMoveTodo(todo, dayDate)
                            return true
                        } isTargeted: { targeted in
                            isDropTargeted = targeted
                        }
                }
            }
        }
    }
}

// MARK: - Draggable Todo Row View
struct DraggableTodoRowView: View {
    var todo: Todo
    let onToggleComplete: () -> Void
    let onDelete: () -> Void
    let onSchedule: () -> Void
    let isFocused: Bool
    let onFocus: () -> Void
    let isEditingTriggered: Bool
    let onEditingChange: (Bool) -> Void
    
    var body: some View {
        TodoRowView(
            todo: todo,
            onToggleComplete: onToggleComplete,
            onDelete: onDelete,
            onSchedule: onSchedule,
            isFocused: isFocused,
            onFocus: onFocus,
            isEditingTriggered: isEditingTriggered,
            onEditingChange: onEditingChange
        )
        .draggable(TodoReference(id: todo.id)) {
            // Drag preview
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(Color.accent)
                Text(todo.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.primaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cardBackground)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Todo.self, inMemory: true)
}
