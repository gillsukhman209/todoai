//
//  ModernSpeedContentView.swift
//  todoai
//
//  COMPLETELY REDESIGNED - Modern, Speed-Focused Interface
//  Inspired by Linear, Notion, Arc Browser - Built for 2025
//

import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct ModernSpeedContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [Todo]
    @State private var showCommandPalette = false
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
        case today = "Today"
        case upcoming = "Upcoming" 
        case all = "All"
        
        var icon: String {
            switch self {
            case .today: return "calendar.badge.clock"
            case .upcoming: return "arrow.up.right"
            case .all: return "list.bullet"
            }
        }
    }
    
    private var todayTodos: [Todo] {
        let today = Date()
        let calendar = Calendar.current
        return todos.filter { todo in
            calendar.isDate(todo.createdAt, inSameDayAs: today) || 
            (todo.dueDate != nil && calendar.isDate(todo.dueDate!, inSameDayAs: today))
        }.sorted(by: { !$0.isCompleted && $1.isCompleted })
    }
    
    private var upcomingTodos: [Todo] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return todos.filter { todo in
            if let dueDate = todo.dueDate {
                return dueDate >= tomorrow
            }
            return false
        }.sorted(by: { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) })
    }
    
    private var displayTodos: [Todo] {
        switch currentView {
        case .today: return todayTodos
        case .upcoming: return upcomingTodos
        case .all: return todos.sorted(by: { !$0.isCompleted && $1.isCompleted })
        }
    }
    
    var body: some View {
        ZStack {
            // Ultra-clean background
            Rectangle()
                .fill(Color.black)
                .ignoresSafeArea()
            
            // Main speed-focused layout
            VStack(spacing: 0) {
                // Modern header
                modernHeader
                
                // Speed-focused todo list
                speedTodoList
                
                // Lightning-fast input
                lightningInput
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCommandPalette) {
            SimpleCommandPaletteView(isPresented: $showCommandPalette)
        }
        .onAppear {
            // Set the model context for AI task creation
            taskCreationViewModel.updateModelContext(modelContext)
            taskCreationViewModel.updateSelectedDate(selectedDate)
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            taskCreationViewModel.updateSelectedDate(newValue)
        }
    }
    
    // MARK: - Modern Header
    private var modernHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentView.rawValue)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
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
                
                Button(action: { showCommandPalette = true }) {
                    Image(systemName: "command")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 36, height: 36)
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
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    private func speedViewButton(for view: SpeedView) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentView = view
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: view.icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(view.rawValue)
                    .font(.system(size: 14, weight: .semibold))
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
    
    // MARK: - Speed Todo List  
    private var speedTodoList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(displayTodos, id: \.id) { todo in
                    ModernTodoCard(
                        todo: todo,
                        onComplete: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                todo.isCompleted.toggle()
                                try? modelContext.save()
                            }
                        },
                        onDelete: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                modelContext.delete(todo)
                                try? modelContext.save()
                            }
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
                            updateSuggestions(for: newValue)
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
}

// MARK: - Modern Todo Card
struct ModernTodoCard: View {
    let todo: Todo
    let onComplete: () -> Void
    let onDelete: () -> Void
    
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
                
                if let dueDate = todo.dueDate {
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
            
            // Priority indicator
            Circle()
                .fill(todo.isCompleted ? .green.opacity(0.6) : .cyan.opacity(0.8))
                .frame(width: 8, height: 8)
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
    }
}

#Preview {
    ModernSpeedContentView()
}