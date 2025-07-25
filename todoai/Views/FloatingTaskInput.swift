import SwiftUI
import SwiftData

struct FloatingTaskInputContainer: View {
    @ObservedObject var viewModel: TaskCreationViewModel
    let focusTrigger: Bool
    let selectedDate: Date
    
    var body: some View {
        FloatingTaskInput(viewModel: viewModel, focusTrigger: focusTrigger, selectedDate: selectedDate)
    }
}

struct FloatingTaskInput: View {
    @ObservedObject var viewModel: TaskCreationViewModel
    let focusTrigger: Bool
    let selectedDate: Date
    @FocusState private var isInputFocused: Bool
    
    // Smart suggestions
    @State private var suggestions: [String] = []
    @State private var selectedSuggestionIndex = -1
    
    // Common task suggestions
    private let commonTasks = [
        "Buy groceries", "Exercise for 30 minutes", "Call dentist", "Pay bills",
        "Clean room", "Study for exam", "Walk the dog", "Water plants",
        "Do laundry", "Schedule doctor appointment", "Reply to emails",
        "Read book", "Meditate", "Cook dinner", "Organize desk", "Backup files"
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            // Smart suggestions row
            if !suggestions.isEmpty && isInputFocused && !viewModel.input.isEmpty {
                suggestionsRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Main input container
            HStack(spacing: 12) {
                // Text input
                TextField(
                    "Type a task... (e.g., 'workout every Mon, Wed, Fri at 7pm')",
                    text: $viewModel.input,
                    axis: .vertical
                )
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.primaryText)
                .focused($isInputFocused)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .onSubmit {
                    handleSubmit()
                }
                .onChange(of: viewModel.input) { oldValue, newValue in
                    updateSuggestions(for: newValue)
                }
                
                // Submit button or loading indicator
                trailingButtonView
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(inputBackground)
            .onTapGesture {
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.2)) {
                    isInputFocused = true
                }
            }
            .scaleEffect(isInputFocused ? 1.02 : 1.0)
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.25), value: isInputFocused)
            
            // Status message
            if !viewModel.statusMessage.isEmpty {
                statusMessageView
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: 600) // Limit width like ChatGPT
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .onChange(of: focusTrigger) { oldValue, newValue in
            isInputFocused = true
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            viewModel.updateSelectedDate(newValue)
        }
        .onAppear {
            viewModel.updateSelectedDate(selectedDate)
        }
    }
    
    private var inputBackground: some View {
        // Dark gesture-enhanced input background
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.8))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isInputFocused ? Color.accent.opacity(0.5) : Color.white.opacity(0.2),
                        lineWidth: isInputFocused ? 2 : 1
                    )
            )
            .shadow(
                color: isInputFocused ? Color.accent.opacity(0.2) : Color.black.opacity(0.3),
                radius: isInputFocused ? 20 : 10,
                x: 0,
                y: isInputFocused ? 10 : 5
            )
    }
    
    private var trailingButtonView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.accent))
            } else if viewModel.canCreateTodo {
                Button(action: handleSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(Color.accent)
                }
                .buttonStyle(.plain)
                .scaleEffect(isInputFocused ? 1.15 : 1.0)
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.7, blendDuration: 0.2), value: isInputFocused)
            }
        }
    }
    
    private var statusMessageView: some View {
        HStack {
            statusIcon
            
            Text(viewModel.statusMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(statusMessageColor)
            
            Spacer()
            
            if case .error = viewModel.state {
                Button(action: {
                    viewModel.resetState()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(statusBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(statusBorderColor, lineWidth: 1)
                )
        )
    }
    
    private var statusIcon: some View {
        Group {
            switch viewModel.state {
            case .idle:
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            case .parsing, .creating:
                Image(systemName: "hourglass")
                    .foregroundColor(.orange)
            case .parsed:
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
            case .completed:
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
            case .error:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
            }
        }
        .font(.system(size: 12, weight: .medium))
    }
    
    private var statusMessageColor: Color {
        switch viewModel.state {
        case .idle: return Color.secondaryText
        case .parsing, .creating: return Color.orange
        case .parsed: return Color.green
        case .completed: return Color.green
        case .error: return Color.red
        }
    }
    
    private var statusBackgroundColor: Color {
        switch viewModel.state {
        case .idle: return Color.blue.opacity(0.1)
        case .parsing, .creating: return Color.orange.opacity(0.1)
        case .parsed: return Color.green.opacity(0.1)
        case .completed: return Color.green.opacity(0.1)
        case .error: return Color.red.opacity(0.1)
        }
    }
    
    private var statusBorderColor: Color {
        switch viewModel.state {
        case .idle: return Color.blue.opacity(0.3)
        case .parsing, .creating: return Color.orange.opacity(0.3)
        case .parsed: return Color.green.opacity(0.3)
        case .completed: return Color.green.opacity(0.3)
        case .error: return Color.red.opacity(0.3)
        }
    }
    
    // MARK: - Actions
    
    private func handleSubmit() {
        guard viewModel.canCreateTodo else { return }
        
        Task {
            await viewModel.createTodo()
        }
    }
    
    // MARK: - Smart Suggestions
    
    private var suggestionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                    suggestionChip(
                        suggestion: suggestion,
                        isSelected: index == selectedSuggestionIndex,
                        onTap: {
                            viewModel.input = suggestion
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
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .black : .white.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? .cyan : .white.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? .clear : .white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
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
    
    // MARK: - Focus Management
    
    func focusInput() {
        isInputFocused = true
    }
}



// MARK: - Preview
#Preview {
    let openAIService = OpenAIService()
    let modelContext = ModelContext(try! ModelContainer(for: Todo.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    let viewModel = TaskCreationViewModel(openAIService: openAIService, modelContext: modelContext)
    
    FloatingTaskInput(viewModel: viewModel, focusTrigger: false, selectedDate: Date())
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.05),
                    Color(red: 0.08, green: 0.08, blue: 0.08),
                    Color(red: 0.12, green: 0.12, blue: 0.12),
                    Color(red: 0.15, green: 0.15, blue: 0.15),
                    Color(red: 0.10, green: 0.10, blue: 0.10),
                    Color(red: 0.06, green: 0.06, blue: 0.06),
                    Color(red: 0.02, green: 0.02, blue: 0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .preferredColorScheme(.dark)
} 