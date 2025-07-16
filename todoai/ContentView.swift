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
    case calendar = "Calendar"
    case today = "Today"
    case upcoming = "Upcoming"
    
    var icon: String {
        switch self {
        case .calendar: return "calendar.circle.fill"
        case .today: return "calendar"
        case .upcoming: return "calendar.badge.clock"
        }
    }
}

// MARK: - Liquid Glass Design System
extension Color {
    // Vibrant Rainbow Color Palette
    static let accent = Color(red: 0.4, green: 0.6, blue: 0.9) // Vibrant blue
    static let accentSecondary = Color(red: 0.3, green: 0.7, blue: 0.8) // Rich teal
    static let accentPurple = Color(red: 0.6, green: 0.4, blue: 0.9) // Vibrant purple
    static let accentPink = Color(red: 0.9, green: 0.4, blue: 0.7) // Vibrant pink
    static let accentOrange = Color(red: 0.9, green: 0.6, blue: 0.2) // Vibrant orange
    static let accentGreen = Color(red: 0.2, green: 0.8, blue: 0.4) // Vibrant green
    static let accentYellow = Color(red: 0.9, green: 0.8, blue: 0.2) // Vibrant yellow
    static let accentRed = Color(red: 0.9, green: 0.3, blue: 0.3) // Vibrant red
    
    // Light mode gradient colors - very subtle pink hints
    static let gradientStart = Color(red: 0.995, green: 0.99, blue: 0.995) // Almost white with hint of pink
    static let gradientMid = Color(red: 0.99, green: 0.985, blue: 0.99) // Very subtle pink
    static let gradientEnd = Color(red: 0.992, green: 0.988, blue: 0.992) // Barely pink
    
    // Status-specific colors
    static let completedColor = Color(red: 0.2, green: 0.8, blue: 0.4) // Success green
    static let urgentColor = Color(red: 0.9, green: 0.3, blue: 0.3) // Urgent red
    static let warningColor = Color(red: 0.9, green: 0.7, blue: 0.2) // Warning orange
    static let infoColor = Color(red: 0.3, green: 0.7, blue: 0.9) // Info blue
    
    // Light mode glass morphism backgrounds
    static let cardBackground = Color.black.opacity(0.04)
    static let hoverBackground = Color.black.opacity(0.06)
    static let activeBackground = Color.black.opacity(0.08)
    static let coloredCardBackground = LinearGradient(
        colors: [
            Color.black.opacity(0.04),
            Color.accent.opacity(0.08),
            Color.accentSecondary.opacity(0.06)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Light mode primary background
    static let primaryBackground = Color.black.opacity(0.02)
    
    // Light mode text colors
    static let primaryText = Color.black
    static let secondaryText = Color.black.opacity(0.7)
    static let tertiaryText = Color.black.opacity(0.5)
    static let accentText = Color(red: 0.3, green: 0.4, blue: 0.6) // Slightly blue-tinted text for light mode
    
    // Light mode glass border colors
    static let glassBorder = Color.black.opacity(0.1)
    static let glassActiveBorder = Color.black.opacity(0.15)
    static let coloredGlassBorder = LinearGradient(
        colors: [
            Color.accent.opacity(0.2),
            Color.accentSecondary.opacity(0.15),
            Color.accentPurple.opacity(0.1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Interactive states with color variations
    static func dynamicAccent(for index: Int) -> Color {
        let colors = [accent, accentSecondary, accentPurple, accentPink, accentOrange, accentGreen, accentYellow]
        let safeIndex = abs(index) % colors.count
        return colors[safeIndex]
    }
    
    static func taskStatusColor(isCompleted: Bool, isUrgent: Bool = false) -> Color {
        if isCompleted {
            return completedColor
        } else if isUrgent {
            return urgentColor
        } else {
            return accent
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [Todo]
    @State private var showSidebar = true
    @State private var showingAPIKeySetup = false
    @State private var showingSchedulingView = false
    @State private var selectedTodoForScheduling: Todo?
    @State private var taskCreationViewModel: TaskCreationViewModel?
    @State private var selectedView: TodoViewType = .calendar
    @State private var focusInputTrigger = false
    
    init() {
        // Initialize the state as nil - will be properly set up in onAppear
        _taskCreationViewModel = State(initialValue: nil)
    }
    
    // MARK: - Computed Properties
    
    private var filteredTodos: [Todo] {
        switch selectedView {
        case .calendar:
            return todos // Show all todos for calendar view
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
                onFocusInput: focusTaskInput,
                onAddTaskForDay: createTaskForDay
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
            // Light mode background with very subtle pink hints
            ZStack {
                // Base light gradient - mostly white with extremely subtle pink
                LinearGradient(
                    colors: [
                        Color.white,                                  // Pure white
                        Color(red: 0.998, green: 0.995, blue: 0.998), // Barely pink
                        Color(red: 0.995, green: 0.992, blue: 0.995), // Very subtle pink
                        Color(red: 0.997, green: 0.994, blue: 0.997), // Almost white with pink hint
                        Color(red: 0.996, green: 0.993, blue: 0.996), // Subtle pink
                        Color(red: 0.999, green: 0.996, blue: 0.999), // Nearly white
                        Color.white                                   // Pure white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Very subtle colorful overlay
                LinearGradient(
                    colors: [
                        Color.gradientStart.opacity(0.3),
                        Color.gradientMid.opacity(0.2),
                        Color.gradientEnd.opacity(0.25),
                        Color.accentPink.opacity(0.08),
                        Color.accentPurple.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.overlay)
                
                // Subtle shimmer effect
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.accentPink.opacity(0.03),
                        Color.accentPurple.opacity(0.02),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.softLight)
            }
            .ignoresSafeArea(.all) // Extend into title bar area
        )
        .preferredColorScheme(.light) // Light mode for proper text contrast
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
    
    private func createTaskForDay(_ date: Date) {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Create a new task for the specified day
            let newTodo = Todo(title: "New Task")
            newTodo.dueDate = date
            
            // Add to model context
            modelContext.insert(newTodo)
            
            // Save the context
            try? modelContext.save()
        }
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
                        .background(Color.black.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.7, blendDuration: 0.2), value: isHovered)
                .onHover { hovering in
                    isHovered = hovering
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            // Navigation items
            VStack(spacing: 8) {
                ForEach(Array(TodoViewType.allCases.enumerated()), id: \.element) { index, viewType in
                    SidebarItemView(
                        icon: viewType.icon,
                        title: viewType.rawValue,
                        count: viewType == .calendar ? activeTodoCount : nil,
                        isSelected: selectedView == viewType,
                        accentColor: Color.dynamicAccent(for: index),
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
                    .background(Color.black.opacity(0.08))
                
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
                            .fill(Color.black.opacity(0.02))
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
            // Clean light mode sidebar background
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            Color(red: 0.98, green: 0.98, blue: 0.99).opacity(0.9),
                            Color(red: 0.97, green: 0.97, blue: 0.98).opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        .padding(.leading, 20)
        .padding(.vertical, 20)
    }
}

struct SidebarItemView: View {
    let icon: String
    let title: String
    let count: Int?
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelected ? accentColor : Color.secondaryText)
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
                    .background(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // Liquid glass base
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isSelected ? Color.activeBackground : 
                        (isHovered ? Color.hoverBackground : Color.clear)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(isSelected ? 0.6 : (isHovered ? 0.4 : 0))
                    )
                
                // Colorful liquid glass border
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? 
                            LinearGradient(
                                colors: [accentColor.opacity(0.6), accentColor.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) : 
                            LinearGradient(
                                colors: [Color.glassBorder, Color.glassBorder],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: isSelected ? 2 : 1
                    )
                    .opacity(isSelected ? 1.0 : (isHovered ? 0.8 : 0))
                
                // Colorful liquid highlight for selected state
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.3),
                                    accentColor.opacity(0.1),
                                    accentColor.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.overlay)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Hover effect with color
                if isHovered && !isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.1),
                                    accentColor.opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.overlay)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.2), value: isHovered)
        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.9, blendDuration: 0.15), value: isSelected)
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
    let onAddTaskForDay: (Date) -> Void
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
                                .background(Color.black.opacity(0.05))
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
                            .foregroundColor(Color.accentYellow)
                            .frame(width: 36, height: 36)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color.accentYellow.opacity(0.2),
                                        Color.accentYellow.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
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
                            .foregroundColor(Color.urgentColor)
                            .frame(width: 36, height: 36)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color.urgentColor.opacity(0.2),
                                        Color.urgentColor.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
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
                    if selectedView == .calendar {
                        // Calendar view
                        CalendarView(
                            todos: todos,
                            onToggleComplete: onToggleComplete,
                            onDeleteTodo: onDeleteTodo,
                            onScheduleTodo: onScheduleTodo,
                            onMoveTodo: onMoveTodo,
                            onAddTaskForDay: onAddTaskForDay
                        )
                    } else if selectedView == .upcoming {
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
                                },
                                onAddTaskForDay: onAddTaskForDay
                            )
                        }
                    } else {
                        // Regular view (Today)
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
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color.accentPurple,
                                        Color.accentPink
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
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
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color.accentGreen,
                                        Color.accentSecondary
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
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
            checkboxView
            
            mainContentView
            
            if isHovered {
                actionButtonsView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(todoItemBackground)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.2), value: isHovered)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.9, blendDuration: 0.15), value: isFocused)
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
            await refreshNotificationStatus()
        }
        .onChange(of: todo.id) { oldValue, newValue in
            Task {
                await refreshNotificationStatus()
            }
        }
        .onChange(of: isEditing) { oldValue, newValue in
            onEditingChange(newValue)
        }
    }
    
    private var checkboxView: some View {
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
                    .fill(todo.isCompleted ? Color.taskStatusColor(isCompleted: true) : Color.clear)
                    .frame(width: 20, height: 20)
                
                Circle()
                    .strokeBorder(
                        todo.isCompleted ? Color.clear : Color.taskStatusColor(isCompleted: false).opacity(0.4),
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
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            if isEditing {
                editingView
            } else {
                titleView
            }
            
            if showingInfo && hasAdditionalInfo {
                additionalInfoView
            }
        }
    }
    
    private var editingView: some View {
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
    }
    
    private var titleView: some View {
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
                    infoButtonView
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
            
            // Due date/time display
            if let dueDate = todo.dueDate {
                dueDateView(dueDate)
            }
        }
    }
    
    private var infoButtonView: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingInfo.toggle()
            }
        }) {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.secondaryText)
        }
        .buttonStyle(.plain)
    }
    
    private func dueDateView(_ dueDate: Date) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.tertiaryText)
            
            Text(dateFormatter.string(from: dueDate))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.tertiaryText)
            
            if let dueTime = todo.dueTime {
                Text("•")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.tertiaryText)
                
                Text(timeFormatter.string(from: dueTime))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.tertiaryText)
            }
        }
    }
    
    private var additionalInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let originalInput = todo.originalInput, !originalInput.isEmpty && originalInput != todo.title {
                HStack {
                    Text("Original:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.tertiaryText)
                    
                    Text(originalInput)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.tertiaryText)
                        .italic()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.tertiaryText.opacity(0.1))
                .cornerRadius(8)
            }
            
            if !todo.scheduleDescription.isEmpty {
                HStack {
                    Text("Schedule:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.tertiaryText)
                    
                    Text(todo.scheduleDescription)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.tertiaryText)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.tertiaryText.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.top, 8)
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 8) {
            // Schedule button
            Button(action: {
                onSchedule()
            }) {
                Image(systemName: hasScheduledNotifications ? "bell.badge.fill" : "bell")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(hasScheduledNotifications ? Color.accentOrange : Color.accentYellow)
                    .frame(width: 24, height: 24)
                    .background(
                        LinearGradient(
                            colors: [
                                (hasScheduledNotifications ? Color.accentOrange : Color.accentYellow).opacity(0.2),
                                (hasScheduledNotifications ? Color.accentOrange : Color.accentYellow).opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // Edit button
            Button(action: {
                startEditing()
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.accentPurple)
                    .frame(width: 24, height: 24)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.accentPurple.opacity(0.2),
                                Color.accentPurple.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
                    .foregroundColor(Color.urgentColor)
                    .frame(width: 24, height: 24)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.urgentColor.opacity(0.2),
                                Color.urgentColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .transition(.opacity)
    }
    
    private var todoItemBackground: some View {
        // Clean light mode todo item background
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                isFocused ? Color.white.opacity(0.95) :
                (isHovered ? Color.white.opacity(0.8) : Color.white.opacity(0.6))
            )
            .stroke(
                isFocused ? Color.dynamicAccent(for: todo.hashValue).opacity(0.3) :
                (isHovered ? Color.black.opacity(0.1) : Color.black.opacity(0.06)),
                lineWidth: isFocused ? 2 : 1
            )
            .shadow(
                color: isFocused ? Color.dynamicAccent(for: todo.hashValue).opacity(0.1) : Color.black.opacity(0.05),
                radius: isFocused ? 8 : 4,
                x: 0,
                y: 2
            )
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
    let onAddTaskForDay: (Date) -> Void
    
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
                        onAddTaskForDay(dayDate)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dynamicAccent(for: dayName.hashValue))
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
                            isDropTargeted ? Color.accent : Color.black.opacity(0.1),
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

// MARK: - Calendar View
struct CalendarView: View {
    let todos: [Todo]
    let onToggleComplete: (Todo) -> Void
    let onDeleteTodo: (Todo) -> Void
    let onScheduleTodo: (Todo) -> Void
    let onMoveTodo: (Todo, Date) -> Void
    let onAddTaskForDay: (Date) -> Void
    
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var selectedDayTodos: [Todo] = []
    
    private let calendar = Calendar.current
    
    // Get all days in the current month
    private var monthDays: [Date] {
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)!.start
        
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    // Get todos for a specific date
    private func todosForDate(_ date: Date) -> [Todo] {
        return todos.filter { todo in
            let todoDate = todo.dueDate ?? todo.createdAt
            return calendar.isDate(todoDate, inSameDayAs: date)
        }
    }
    
    // Get the first day of the month to calculate offset
    private var firstDayOfMonth: Date {
        calendar.dateInterval(of: .month, for: currentMonth)!.start
    }
    
    // Get the weekday of the first day (0 = Sunday, 1 = Monday, etc.)
    private var firstDayWeekday: Int {
        calendar.component(.weekday, from: firstDayOfMonth) - 1
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Month Navigation
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.accentPurple)
                        .frame(width: 32, height: 32)
                        .background(Color.accentPurple.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.primaryText)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)!
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.accentPurple)
                        .frame(width: 32, height: 32)
                        .background(Color.accentPurple.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            
            // Calendar Grid
            VStack(spacing: 0) {
                // Weekday headers
                HStack(spacing: 0) {
                    ForEach(calendar.weekdaySymbols, id: \.self) { weekday in
                        Text(String(weekday.prefix(3)))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.secondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                }
                
                // Calendar days
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                    // Empty cells for days before month starts
                    ForEach(0..<firstDayWeekday, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 60)
                    }
                    
                    // Days of the month
                    ForEach(monthDays, id: \.self) { date in
                        CalendarDayView(
                            date: date,
                            todos: todosForDate(date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDate(date, inSameDayAs: Date()),
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDate = date
                                    selectedDayTodos = todosForDate(date)
                                }
                            },
                            onAddTask: { onAddTaskForDay(date) }
                        )
                    }
                }
            }
            .padding(.horizontal, 32)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.cardBackground)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.glassBorder, lineWidth: 1)
            )
            
            // Selected day todos
            if !selectedDayTodos.isEmpty {
                VStack(spacing: 12) {
                    HStack {
                        Text("Tasks for \(selectedDate.formatted(.dateTime.weekday(.wide).month().day()))")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.primaryText)
                        
                        Spacer()
                        
                        Text("\(selectedDayTodos.count)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.tertiaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.tertiaryText.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 32)
                    
                    ForEach(selectedDayTodos) { todo in
                        TodoRowView(
                            todo: todo,
                            onToggleComplete: { onToggleComplete(todo) },
                            onDelete: { onDeleteTodo(todo) },
                            onSchedule: { onScheduleTodo(todo) },
                            isFocused: false,
                            onFocus: { },
                            isEditingTriggered: false,
                            onEditingChange: { _ in }
                        )
                        .padding(.horizontal, 32)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .onAppear {
            selectedDayTodos = todosForDate(selectedDate)
        }
        .onChange(of: todos) { oldValue, newValue in
            selectedDayTodos = todosForDate(selectedDate)
        }
    }
}

// MARK: - Calendar Day View
struct CalendarDayView: View {
    let date: Date
    let todos: [Todo]
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void
    let onAddTask: () -> Void
    
    @State private var isHovered = false
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Day number
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday ? .bold : .medium))
                    .foregroundColor(
                        isSelected ? Color.primaryText :
                        isToday ? Color.accentOrange :
                        Color.secondaryText
                    )
                
                // Todo indicators
                HStack(spacing: 2) {
                    ForEach(todos.prefix(3), id: \.id) { todo in
                        Circle()
                            .fill(Color.dynamicAccent(for: todo.hashValue))
                            .frame(width: 4, height: 4)
                    }
                    
                    if todos.count > 3 {
                        Text("+\(todos.count - 3)")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(Color.tertiaryText)
                    }
                }
                .frame(height: 8)
                
                Spacer()
                
                // Add button on hover
                if isHovered {
                    Button(action: onAddTask) {
                        Image(systemName: "plus")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(Color.accentGreen)
                            .frame(width: 16, height: 16)
                            .background(Color.accentGreen.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected ? Color.activeBackground :
                        isToday ? Color.accentOrange.opacity(0.1) :
                        (isHovered ? Color.hoverBackground : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.glassActiveBorder :
                        isToday ? Color.accentOrange.opacity(0.3) :
                        Color.clear,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Todo.self, inMemory: true)
}
