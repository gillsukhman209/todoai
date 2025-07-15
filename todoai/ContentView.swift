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
    @State private var newTodoTitle = ""
    @State private var isAddingTodo = false
    @State private var showSidebar = true
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Main content area
            TodoListView(
                todos: todos, 
                newTodoTitle: $newTodoTitle, 
                isAddingTodo: $isAddingTodo,
                onAddTodo: addTodo,
                onDeleteTodo: deleteTodo,
                onToggleComplete: toggleTodoComplete,
                showSidebar: $showSidebar
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
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
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
    }
    
    private func addTodo() {
        guard !newTodoTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        withAnimation(.easeInOut(duration: 0.25)) {
            let newTodo = Todo(title: newTodoTitle.trimmingCharacters(in: .whitespaces))
            modelContext.insert(newTodo)
            newTodoTitle = ""
            isAddingTodo = false
        }
    }
    
    private func deleteTodo(_ todo: Todo) {
        withAnimation(.easeInOut(duration: 0.25)) {
            modelContext.delete(todo)
        }
    }
    
    private func toggleTodoComplete(_ todo: Todo) {
        withAnimation(.easeInOut(duration: 0.2)) {
            todo.isCompleted.toggle()
        }
    }
}

struct FloatingSidebarView: View {
    let activeTodoCount: Int
    let onDismiss: () -> Void
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
            VStack(spacing: 8) {
                Divider()
                    .background(Color.white.opacity(0.2))
                
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
    @Binding var newTodoTitle: String
    @Binding var isAddingTodo: Bool
    let onAddTodo: () -> Void
    let onDeleteTodo: (Todo) -> Void
    let onToggleComplete: (Todo) -> Void
    @Binding var showSidebar: Bool
    @FocusState private var isNewTodoFocused: Bool
    
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
                    // Add new todo
                    if isAddingTodo {
                        AddTodoRow(
                            title: $newTodoTitle,
                            isNewTodoFocused: $isNewTodoFocused,
                            onAddTodo: onAddTodo,
                            onCancel: cancelAddingTodo
                        )
                        .padding(.horizontal, 32)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    // Active todos
                    ForEach(activeTodos) { todo in
                        TodoRowView(
                            todo: todo,
                            onToggleComplete: { onToggleComplete(todo) },
                            onDelete: { onDeleteTodo(todo) }
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
                                    onDelete: { onDeleteTodo(todo) }
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: startAddingTodo) {
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
    
    private func startAddingTodo() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isAddingTodo = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isNewTodoFocused = true
        }
    }
    
    private func cancelAddingTodo() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isAddingTodo = false
            newTodoTitle = ""
            isNewTodoFocused = false
        }
    }
}

struct AddTodoRow: View {
    @Binding var title: String
    @FocusState.Binding var isNewTodoFocused: Bool
    let onAddTodo: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Clean checkbox
            Circle()
                .strokeBorder(Color.accent.opacity(0.3), lineWidth: 1.5)
                .frame(width: 20, height: 20)
            
            // Clean text field
            TextField("Add a task", text: $title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.primaryText)
                .focused($isNewTodoFocused)
                .textFieldStyle(.plain)
                .onSubmit {
                    onAddTodo()
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // Glass background
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.cardBackground)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            }
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
    }
}

struct TodoRowView: View {
    var todo: Todo
    let onToggleComplete: () -> Void
    let onDelete: () -> Void
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
            } else {
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
            }
            
            Spacer()
            
            // Clean delete button
            if isHovered && !isEditing {
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
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // Glass background with hover effect
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovered ? Color.hoverBackground : Color.cardBackground)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                
                // Dynamic border for editing state
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isEditing ? Color.accent.opacity(0.8) : Color.white.opacity(0.2), 
                        lineWidth: isEditing ? 2 : 1
                    )
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
