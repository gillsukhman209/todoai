//
//  ContentView.swift
//  todoai
//
//  Created by Sukhman Singh on 7/14/25.
//

import SwiftUI
import SwiftData

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
    @State private var showingNaturalLanguageInput = false
    @State private var showingAPIKeySetup = false
    @State private var showingSchedulingView = false
    @State private var selectedTodoForScheduling: Todo?
    @State private var taskCreationViewModel: TaskCreationViewModel?
    
    init() {
        // Initialize the state as nil - will be properly set up in onAppear
        _taskCreationViewModel = State(initialValue: nil)
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Main content area
            TodoListView(
                todos: todos, 
                onDeleteTodo: deleteTodo,
                onToggleComplete: toggleTodoComplete,
                onScheduleTodo: showSchedulingView,
                showSidebar: $showSidebar,
                showingNaturalLanguageInput: $showingNaturalLanguageInput
            )
            .padding(.leading, showSidebar ? 280 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showSidebar)
            
            // Custom floating sidebar
            if showSidebar {
                FloatingSidebarView(
                    activeTodoCount: todos.filter { !$0.isCompleted }.count,
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
            
            // Natural Language Input Overlay
            if showingNaturalLanguageInput, let viewModel = taskCreationViewModel {
                NaturalLanguageInputOverlay(
                    viewModel: viewModel,
                    isShowing: $showingNaturalLanguageInput
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(100)
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
                // Hide the natural language input when task is created
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.showingNaturalLanguageInput = false
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
    

    
    private func deleteTodo(_ todo: Todo) {
        withAnimation(.easeInOut(duration: 0.25)) {
            // Cancel any pending notifications for this task before deleting
            NotificationService.shared.cancelAllNotifications(for: todo.id)
            
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
}

struct FloatingSidebarView: View {
    let activeTodoCount: Int
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
                SidebarItemView(
                    icon: "tray.fill",
                    title: "Inbox",
                    count: activeTodoCount,
                    isSelected: true
                )
                
                SidebarItemView(
                    icon: "calendar",
                    title: "Today",
                    count: nil,
                    isSelected: false
                )
                
                SidebarItemView(
                    icon: "calendar.badge.clock",
                    title: "Upcoming",
                    count: nil,
                    isSelected: false
                )
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
    }
}

struct TodoListView: View {
    let todos: [Todo]
    let onDeleteTodo: (Todo) -> Void
    let onToggleComplete: (Todo) -> Void
    let onScheduleTodo: (Todo) -> Void
    @Binding var showSidebar: Bool
    @Binding var showingNaturalLanguageInput: Bool
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
                        Text("Inbox")
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .foregroundColor(Color.primaryText)
                        
                        if !activeTodos.isEmpty {
                            Text("\(activeTodos.count) task\(activeTodos.count == 1 ? "" : "s")")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.secondaryText)
                        } else {
                            Text("All caught up")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.secondaryText)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                // Clean task list
                LazyVStack(spacing: 8) {
                    
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
                    
                    // Bottom padding
                    Color.clear.frame(height: 60)
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
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingNaturalLanguageInput = true
                        }
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
                    
                    // Regular Add Button (now opens AI input)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingNaturalLanguageInput = true
                        }
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
    @FocusState private var isEditingFocused: Bool
    
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
                    
                    // Schedule information
                    if !todo.scheduleDescription.isEmpty {
                        Text(todo.scheduleDescription)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.tertiaryText)
                    }
                    
                    // Original AI input (if available)
                    if let originalInput = todo.originalInput, !originalInput.isEmpty, originalInput != todo.title {
                        Text("From: \"\(originalInput)\"")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.accent.opacity(0.6))
                            .italic()
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
                        Image(systemName: "bell")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.accentSecondary)
                            .frame(width: 24, height: 24)
                            .background(Color.accentSecondary.opacity(0.1))
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

#Preview {
    ContentView()
        .modelContainer(for: Todo.self, inMemory: true)
}
