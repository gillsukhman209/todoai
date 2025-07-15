import SwiftUI
import SwiftData

struct NaturalLanguageInputOverlay: View {
    @ObservedObject var viewModel: TaskCreationViewModel
    @Binding var isShowing: Bool
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                }
            
            // Modal content
            VStack(spacing: 0) {
                Spacer()
                
                // Natural Language Input Card
                VStack(spacing: 0) {
                    // Header with close button
                    HStack {
                        Text("Smart Task Creation")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color.primaryText)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.secondaryText)
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                    
                    // Natural Language Input
                    NaturalLanguageInputView(viewModel: viewModel)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    
                    // Example prompts
                    ExamplePromptsView()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.primaryBackground)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 15)
                .padding(.horizontal, 32)
                
                Spacer()
            }
        }
        .onAppear {
            viewModel.resetState()
        }
        .onDisappear {
            viewModel.resetState()
        }
    }
}

// MARK: - Example Prompts
struct ExamplePromptsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try these examples (automatic smart detection):")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.secondaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ExamplePromptCard(
                    icon: "phone",
                    text: "call dad at 6am",
                    color: .blue
                )
                
                ExamplePromptCard(
                    icon: "creditcard",
                    text: "pay PGE every Friday at 10am",
                    color: .green
                )
                
                ExamplePromptCard(
                    icon: "figure.strengthtraining.traditional",
                    text: "workout every Mon, Wed, Fri at 7pm",
                    color: .orange
                )
                
                ExamplePromptCard(
                    icon: "drop.fill",
                    text: "drink water every 30 minutes from 9am to 5pm",
                    color: .cyan
                )
            }
        }
    }
}

struct ExamplePromptCard: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview
#Preview {
    let openAIService = OpenAIService()
    let modelContext = ModelContext(try! ModelContainer(for: Todo.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    let viewModel = TaskCreationViewModel(openAIService: openAIService, modelContext: modelContext)
    
    NaturalLanguageInputOverlay(
        viewModel: viewModel,
        isShowing: .constant(true)
    )
    .background(
        LinearGradient(
            colors: [
                Color(red: 0.25, green: 0.12, blue: 0.40),
                Color(red: 0.08, green: 0.55, blue: 0.70)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
    .preferredColorScheme(.dark)
} 