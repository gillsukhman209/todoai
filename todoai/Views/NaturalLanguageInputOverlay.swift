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