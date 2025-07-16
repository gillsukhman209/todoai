import SwiftUI
import SwiftData

struct FloatingTaskInputContainer: View {
    @ObservedObject var viewModel: TaskCreationViewModel
    let focusTrigger: Bool
    
    var body: some View {
        FloatingTaskInput(viewModel: viewModel, focusTrigger: focusTrigger)
    }
}

struct FloatingTaskInput: View {
    @ObservedObject var viewModel: TaskCreationViewModel
    let focusTrigger: Bool
    @FocusState private var isInputFocused: Bool
    @State private var showingExamples = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Examples tooltip (shows when input is focused and empty)
            if showingExamples && viewModel.input.isEmpty && isInputFocused {
                ExampleTooltip()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // Main input container
            HStack(spacing: 12) {
                // AI icon
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.accent)
                    .frame(width: 20)
                
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
                    updateSuggestions()
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
                 .onChange(of: isInputFocused) { oldValue, newValue in
             withAnimation(.easeInOut(duration: 0.2)) {
                 showingExamples = newValue
             }
         }
         .onChange(of: focusTrigger) { oldValue, newValue in
             isInputFocused = true
         }
    }
    
    private var inputBackground: some View {
        // Clean light mode input background
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.9))
            .stroke(
                isInputFocused ? Color.accent.opacity(0.4) : Color.black.opacity(0.1),
                lineWidth: isInputFocused ? 2 : 1
            )
            .shadow(
                color: isInputFocused ? Color.accent.opacity(0.15) : Color.black.opacity(0.08),
                radius: isInputFocused ? 12 : 6,
                x: 0,
                y: isInputFocused ? 6 : 3
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
    
    private func updateSuggestions() {
        // Can add smart suggestions logic here if needed
    }
    
    // MARK: - Focus Management
    
    func focusInput() {
        isInputFocused = true
    }
}

// MARK: - Example Tooltip
struct ExampleTooltip: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try these examples:")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ExampleCard(
                    icon: "phone",
                    text: "call dad at 6am",
                    color: .blue
                )
                
                ExampleCard(
                    icon: "creditcard",
                    text: "pay PGE every Friday at 10am",
                    color: .green
                )
                
                ExampleCard(
                    icon: "figure.strengthtraining.traditional",
                    text: "workout every Mon, Wed, Fri at 7pm",
                    color: .orange
                )
                
                ExampleCard(
                    icon: "drop.fill",
                    text: "drink water every 30 minutes from 9am to 5pm",
                    color: .cyan
                )
            }
        }
        .padding(16)
        .background(
            ZStack {
                // Liquid glass base
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.cardBackground)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.8)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.thickMaterial)
                            .opacity(0.3)
                    )
                
                // Liquid glass border
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.glassBorder, lineWidth: 1)
                
                // Inner glass highlight
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.clear,
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .opacity(0.6)
            }
        )
        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 6)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct ExampleCard: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
                .frame(width: 14)
            
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            ZStack {
                // Liquid glass base
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                    )
                
                // Liquid glass border
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                
                // Inner glass highlight
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
                    .opacity(0.6)
            }
        )
    }
}

// MARK: - Preview
#Preview {
    let openAIService = OpenAIService()
    let modelContext = ModelContext(try! ModelContainer(for: Todo.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    let viewModel = TaskCreationViewModel(openAIService: openAIService, modelContext: modelContext)
    
    FloatingTaskInput(viewModel: viewModel, focusTrigger: false)
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