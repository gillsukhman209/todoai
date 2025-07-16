import SwiftUI
import SwiftData

struct NaturalLanguageInputView: View {
    @ObservedObject var viewModel: TaskCreationViewModel
    @FocusState private var isInputFocused: Bool
    @State private var showingPreview = false
    
    var body: some View {
        VStack(spacing: 16) {
            headerView
            mainInputSection
            statusMessageSection
            // Removed parsePreviewSection since we now directly create tasks
        }
        .background(backgroundView)
        .onAppear {
            // Auto-focus input when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.state)
    }
    
    private var headerView: some View {
        HStack {
            Text("Create Task")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.primaryText)
            
            Spacer()
            
            // Smart Detection indicator
            HStack(spacing: 8) {
                Text("Smart Detection")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.secondaryText)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    private var mainInputSection: some View {
        VStack(spacing: 12) {
            inputFieldSection
            suggestionBarSection
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    private var inputFieldSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Text input
                TextField(
                    "Try: 'workout every Mon, Wed, Fri at 7pm' or 'Buy groceries'",
                    text: $viewModel.input,
                    axis: .vertical
                )
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.primaryText)
                .focused($isInputFocused)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .onSubmit {
                    self.handleSubmit()
                }
                .onChange(of: viewModel.input) { oldValue, newValue in
                    self.updateSuggestions()
                }
                
                // Loading indicator or submit button
                trailingButtonView
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(inputFieldBackground)
        }
    }
    
    private var trailingButtonView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.accent))
            } else if viewModel.canCreateTodo {
                Button(action: self.handleSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var inputFieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.cardBackground)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isInputFocused ? Color.accent.opacity(0.5) : Color.white.opacity(0.2),
                        lineWidth: 1
                    )
            )
    }
    
    private var suggestionBarSection: some View {
        Group {
            if !viewModel.input.isEmpty {
                SmartSuggestionBar()
            }
        }
    }
    
    private var statusMessageSection: some View {
        Group {
            if !viewModel.statusMessage.isEmpty {
                HStack {
                    statusIcon
                    
                    Text(viewModel.statusMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(statusMessageColor)
                    
                    Spacer()
                    
                    dismissButton
                }
                .padding(.horizontal, 16)
                .transition(.opacity)
            }
        }
    }
    
    private var statusIcon: some View {
        Group {
            if case .error = viewModel.state {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
            } else if case .parsed = viewModel.state {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }
        }
    }
    
    private var dismissButton: some View {
        Group {
            if case .error = viewModel.state {
                Button("Dismiss") {
                    viewModel.dismissError()
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.accent)
            }
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.primaryBackground)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
    
    private func handleSubmit() {
        Task {
            await viewModel.createTodo()
        }
    }
    
    private var statusMessageColor: Color {
        if case .error = viewModel.state {
            return .red
        } else {
            return Color.secondaryText
        }
    }
    
    private func updateSuggestions() {
        // Automatically handles natural language detection in the background
        // No manual mode switching needed
    }
}



// MARK: - Smart Suggestion Bar
struct SmartSuggestionBar: View {
    var body: some View {
        HStack {
            Image(systemName: "lightbulb")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.accent.opacity(0.7))
            
            Text("Tip: Add time patterns like 'at 6pm', 'every Friday', or 'daily' for smart scheduling")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.tertiaryText)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accent.opacity(0.1))
        )
        .transition(.opacity)
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.accent)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Color.secondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    let openAIService = OpenAIService()
    let modelContext = ModelContext(try! ModelContainer(for: Todo.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    let viewModel = TaskCreationViewModel(openAIService: openAIService, modelContext: modelContext)
    
    VStack {
        NaturalLanguageInputView(viewModel: viewModel)
        Spacer()
    }
    .padding()
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