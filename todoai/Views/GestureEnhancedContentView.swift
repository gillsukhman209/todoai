//
//  GestureEnhancedContentView.swift
//  todoai
//
//  Ultimate speed-focused interface with pro gestures
//  Every interaction optimized for maximum productivity
//

import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct GestureEnhancedContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [Todo]
    @State private var quickInput = ""
    @State private var isCommandPalettePresented = false
    @State private var suggestions: [String] = []
    @State private var selectedSuggestionIndex = -1
    @FocusState private var isInputFocused: Bool
    
    // Gesture states
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var lastTapLocation: CGPoint = .zero
    @State private var doubleTapCount = 0
    
    // Performance optimizations
    @State private var visibleTodos: [Todo] = []
    @State private var filteredTodos: [Todo] = []
    @State private var searchQuery = ""
    
#if canImport(UIKit)
    private let haptics = UIImpactFeedbackGenerator(style: .light)
    private let strongHaptics = UIImpactFeedbackGenerator(style: .heavy)
#endif
    
    // Smart suggestions database
    private let commonTasks = [
        "Buy groceries", "Exercise", "Call mom", "Pay bills", "Clean room",
        "Study for exam", "Walk the dog", "Water plants", "Do laundry",
        "Schedule doctor appointment", "Reply to emails", "Read book",
        "Meditate", "Cook dinner", "Organize desk", "Backup files"
    ]
    
    var body: some View {
        ZStack {
            // Ultra-minimal background
            backgroundView
            
            VStack(spacing: 0) {
                // Pro header with gestures
                gestureHeader
                
                // Lightning-fast todo list
                gestureEnabledTodoList
                
                Spacer()
                
                // Smart input with suggestions
                smartInputWithSuggestions
            }
        }
        .preferredColorScheme(.dark)
        .gesture(globalGestures)
        .onAppear {
            updateVisibleTodos()
            generateSmartSuggestions()
        }
        .onChange(of: todos) { _, _ in
            updateVisibleTodos()
        }
        .onChange(of: quickInput) { _, newValue in
            generateSmartSuggestions(for: newValue)
        }
        .sheet(isPresented: $isCommandPalettePresented) {
            SimpleCommandPaletteView(isPresented: $isCommandPalettePresented)
        }
    }
    
    // MARK: - Background
    private var backgroundView: some View {
        Rectangle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.06),
                        Color.black,
                        Color(red: 0.01, green: 0.01, blue: 0.03)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 1000
                )
            )
            .ignoresSafeArea()
    }
    
    // MARK: - Gesture Header
    private var gestureHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Text("TODOS")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Live status indicator
                    Circle()
                        .fill(.cyan)
                        .frame(width: 8, height: 8)
                        .opacity(0.8)
                        .scaleEffect(isDragging ? 1.3 : 1.0)
                }
                
                // Smart stats
                HStack(spacing: 12) {
                    statBubble(count: visibleTodos.filter { !$0.isCompleted }.count, label: "active", color: .cyan)
                    statBubble(count: visibleTodos.filter { $0.isCompleted }.count, label: "done", color: .green)
                    
                    if !searchQuery.isEmpty {
                        statBubble(count: filteredTodos.count, label: "found", color: .orange)
                    }
                }
            }
            
            Spacer()
            
            // Quick action buttons
            HStack(spacing: 16) {
                quickActionButton(icon: "command", action: {
                    isCommandPalettePresented = true
                })
                
                quickActionButton(icon: "line.3.horizontal.decrease", action: {
                    // Toggle view mode
                })
                
                quickActionButton(icon: "plus.circle", action: {
                    isInputFocused = true
                })
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .onTapGesture(count: 2) { location in
            // Double tap to open command palette
            isCommandPalettePresented = true
            #if canImport(UIKit)
            strongHaptics.impactOccurred()
            #endif
        }
    }
    
    private func statBubble(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text("\(count)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func quickActionButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
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
        .scaleEffect(isDragging ? 0.9 : 1.0)
    }
    
    // MARK: - Gesture-Enabled Todo List
    private var gestureEnabledTodoList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 2) {
                ForEach(filteredTodos.isEmpty ? visibleTodos : filteredTodos, id: \.createdAt) { todo in
                    SuperSpeedTodoRow(
                        todo: todo,
                        modelContext: modelContext,
                        onUpdate: updateVisibleTodos
                    )
                    .gesture(
                        todoRowGestures(for: todo)
                    )
                }
                
                if (filteredTodos.isEmpty ? visibleTodos : filteredTodos).isEmpty {
                    proEmptyState
                }
            }
            .padding(.horizontal, 24)
        }
        .scrollContentBackground(.hidden)
    }
    
    private var proEmptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 2)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .ultraLight))
                    .foregroundColor(.white.opacity(0.3))
            }
            
            VStack(spacing: 8) {
                Text("Ready to be productive?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Start typing or use gestures below")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                
                // Gesture hints
                HStack(spacing: 20) {
                    gestureHint(gesture: "⌘ + K", action: "Command palette")
                    gestureHint(gesture: "Double tap", action: "Quick actions")
                    gestureHint(gesture: "Swipe", action: "Manage todos")
                }
                .padding(.top, 16)
            }
        }
        .padding(.top, 60)
    }
    
    private func gestureHint(gesture: String, action: String) -> some View {
        VStack(spacing: 4) {
            Text(gesture)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan.opacity(0.8))
            
            Text(action)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }
    
    // MARK: - Smart Input with Suggestions
    private var smartInputWithSuggestions: some View {
        VStack(spacing: 12) {
            // Suggestions row
            if !suggestions.isEmpty && isInputFocused {
                suggestionsRow
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Main input
            HStack(spacing: 0) {
                TextField("", text: $quickInput)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .onSubmit {
                        createTodoWithHaptics()
                    }
                    .placeholder(when: quickInput.isEmpty && !isInputFocused) {
                        Text("Type, speak, or gesture...")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                    }
                
                // Smart action buttons
                if !quickInput.isEmpty {
                    HStack(spacing: 12) {
                        // AI enhance button
                        Button(action: enhanceWithAI) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.purple)
                        }
                        .buttonStyle(.plain)
                        
                        // Submit button
                        Button(action: createTodoWithHaptics) {
                            Circle()
                                .fill(.cyan)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                )
                        }
                        .scaleEffect(isInputFocused ? 1.1 : 1.0)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(inputBackground)
            .onTapGesture {
                isInputFocused = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: isInputFocused)
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9), value: quickInput.isEmpty)
    }
    
    private var suggestionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                    suggestionChip(
                        suggestion: suggestion,
                        isSelected: index == selectedSuggestionIndex,
                        onTap: {
                            quickInput = suggestion
                            selectedSuggestionIndex = -1
                            createTodoWithHaptics()
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
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .black : .white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? .cyan : .white.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? .clear : .white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
    
    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(isInputFocused ? 0.3 : 0.1), lineWidth: 1)
            )
            .shadow(
                color: isInputFocused ? .cyan.opacity(0.1) : .clear,
                radius: isInputFocused ? 20 : 0,
                x: 0,
                y: isInputFocused ? 10 : 0
            )
    }
    
    // MARK: - Global Gestures
    private var globalGestures: some Gesture {
        SimultaneousGesture(
            // Command palette gesture
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    isCommandPalettePresented = true
                    #if canImport(UIKit)
                    strongHaptics.impactOccurred()
                    #endif
                },
            
            // Drag gesture for bulk actions
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                    if !isDragging && abs(value.translation.height) > 50 {
                        isDragging = true
                        #if canImport(UIKit)
                        haptics.impactOccurred()
                        #endif
                    }
                }
                .onEnded { value in
                    handleGlobalDrag(value)
                    dragOffset = .zero
                    isDragging = false
                }
        )
    }
    
    // MARK: - Todo Row Gestures
    private func todoRowGestures(for todo: Todo) -> some Gesture {
        DragGesture()
            .onEnded { value in
                if value.translation.width > 100 {
                    // Swipe right: Complete
                    toggleTodoCompletion(todo)
                } else if value.translation.width < -100 {
                    // Swipe left: Delete
                    deleteTodoWithAnimation(todo)
                }
            }
    }
    
    // MARK: - Actions
    private func createTodoWithHaptics() {
        guard !quickInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let todo = Todo(title: quickInput.trimmingCharacters(in: .whitespaces))
        modelContext.insert(todo)
        
#if canImport(UIKit)
        haptics.impactOccurred()
        #endif
        quickInput = ""
        selectedSuggestionIndex = -1
        
        Task {
            try? await MainActor.run {
                try? modelContext.save()
                updateVisibleTodos()
            }
        }
    }
    
    private func enhanceWithAI() {
        // Placeholder for AI enhancement
        #if canImport(UIKit)
        haptics.impactOccurred()
        #endif
    }
    
    private func toggleTodoCompletion(_ todo: Todo) {
        #if canImport(UIKit)
        haptics.impactOccurred()
        #endif
        todo.isCompleted.toggle()
        
        Task {
            try? await MainActor.run {
                try? modelContext.save()
                updateVisibleTodos()
            }
        }
    }
    
    private func deleteTodoWithAnimation(_ todo: Todo) {
        #if canImport(UIKit)
        strongHaptics.impactOccurred()
        #endif
        modelContext.delete(todo)
        
        Task {
            try? await MainActor.run {
                try? modelContext.save()
                updateVisibleTodos()
            }
        }
    }
    
    private func handleGlobalDrag(_ value: DragGesture.Value) {
        if value.translation.height < -100 {
            // Swipe up: Show command palette
            isCommandPalettePresented = true
        } else if value.translation.height > 100 {
            // Swipe down: Focus input
            isInputFocused = true
        }
    }
    
    private func updateVisibleTodos() {
        visibleTodos = todos.sorted { todo1, todo2 in
            if todo1.isCompleted != todo2.isCompleted {
                return !todo1.isCompleted
            }
            return todo1.createdAt > todo2.createdAt
        }
        
        if !searchQuery.isEmpty {
            filteredTodos = visibleTodos.filter { todo in
                todo.title.localizedCaseInsensitiveContains(searchQuery)
            }
        } else {
            filteredTodos = []
        }
    }
    
    private func generateSmartSuggestions(for input: String = "") {
        if input.isEmpty {
            suggestions = Array(commonTasks.shuffled().prefix(3))
        } else {
            let filtered = commonTasks.filter { task in
                task.localizedCaseInsensitiveContains(input) && task != input
            }
            
            let recentPatterns = todos.compactMap { todo in
                todo.title.components(separatedBy: " ").first
            }.filter { word in
                word.localizedCaseInsensitiveContains(input) && word.count > 2
            }
            
            suggestions = Array(Set(filtered + recentPatterns)).prefix(4).map { $0 }
        }
    }
}

// MARK: - Super Speed Todo Row
struct SuperSpeedTodoRow: View {
    let todo: Todo
    let modelContext: ModelContext
    let onUpdate: () -> Void
    
    @State private var isPressed = false
    @State private var swipeOffset: CGFloat = 0
    @State private var showingActions = false
    
    #if canImport(UIKit)
    private let haptics = UIImpactFeedbackGenerator(style: .light)
    #endif
    
    var body: some View {
        HStack(spacing: 16) {
            // Quick completion circle
            Button(action: toggleCompletion) {
                ZStack {
                    Circle()
                        .stroke(todo.isCompleted ? .green : .white.opacity(0.2), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if todo.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(isPressed ? 1.2 : 1.0)
            
            // Todo content
            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(todo.isCompleted ? .white.opacity(0.4) : .white)
                    .strikethrough(todo.isCompleted, color: .white.opacity(0.4))
                    .lineLimit(3)
                
                Text(formatRelativeTime(todo.createdAt))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }
            
            Spacer()
            
            // Quick action indicators
            if showingActions {
                HStack(spacing: 12) {
                    actionIcon(icon: "checkmark.circle", color: .green)
                    actionIcon(icon: "trash", color: .red)
                }
                .transition(.opacity.combined(with: .scale))
            }
            
            // Status dot
            Circle()
                .fill(todo.isCompleted ? .green.opacity(0.6) : .cyan.opacity(0.6))
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(todoBackground)
        .offset(x: swipeOffset)
        .gesture(swipeGesture)
        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.9), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: swipeOffset)
        .animation(.easeInOut(duration: 0.2), value: showingActions)
    }
    
    private var todoBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(todo.isCompleted ? .white.opacity(0.02) : .white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
    }
    
    private func actionIcon(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(color)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(color.opacity(0.2))
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.4), lineWidth: 1)
                    )
            )
    }
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                swipeOffset = value.translation.width * 0.3
                showingActions = abs(value.translation.width) > 50
            }
            .onEnded { value in
                if value.translation.width > 100 {
                    toggleCompletion()
                } else if value.translation.width < -100 {
                    deleteTodo()
                }
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    swipeOffset = 0
                    showingActions = false
                }
            }
    }
    
    private func toggleCompletion() {
        #if canImport(UIKit)
        haptics.impactOccurred()
        #endif
        
        withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.9)) {
            isPressed = true
            todo.isCompleted.toggle()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8)) {
                isPressed = false
            }
        }
        
        Task {
            try? await MainActor.run {
                try? modelContext.save()
                onUpdate()
            }
        }
    }
    
    private func deleteTodo() {
        #if canImport(UIKit)
        haptics.impactOccurred()
        #endif
        modelContext.delete(todo)
        
        Task {
            try? await MainActor.run {
                try? modelContext.save()
                onUpdate()
            }
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "now"
        } else if timeInterval < 3600 {
            return "\(Int(timeInterval / 60))m ago"
        } else if timeInterval < 86400 {
            return "\(Int(timeInterval / 3600))h ago"
        } else {
            return "\(Int(timeInterval / 86400))d ago"
        }
    }
}