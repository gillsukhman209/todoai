import SwiftUI
import SwiftData

struct APIKeySetupView: View {
    @Binding var isPresented: Bool
    @State private var apiKey: String = ""
    @State private var isSecure: Bool = true
    @State private var showSuccessMessage: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(Color.accent)
                
                Text("OpenAI API Setup")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.primaryText)
                
                Text("Enter your OpenAI API key to enable smart task creation")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // API Key Input
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.secondaryText)
                
                HStack {
                    Group {
                        if isSecure {
                            SecureField("sk-...", text: $apiKey)
                        } else {
                            TextField("sk-...", text: $apiKey)
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.primaryText)
                    .textFieldStyle(.plain)
                    
                    Button(action: { isSecure.toggle() }) {
                        Image(systemName: isSecure ? "eye" : "eye.slash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            // Success message
            if showSuccessMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.green)
                    
                    Text("API key saved successfully!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                }
                .transition(.opacity)
            }
            
            // Info section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.accent)
                    
                    Text("How to get your API key:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.secondaryText)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Go to platform.openai.com")
                    Text("2. Sign in or create an account")
                    Text("3. Navigate to API Keys section")
                    Text("4. Create a new secret key")
                    Text("5. Copy and paste it here")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accent.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.accent.opacity(0.2), lineWidth: 1)
                    )
            )
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Save") {
                    saveAPIKey()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(32)
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
        .onAppear {
            loadAPIKey()
        }
        .animation(.easeInOut(duration: 0.25), value: showSuccessMessage)
    }
    
    private func loadAPIKey() {
        apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    }
    
    private func saveAPIKey() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)
        UserDefaults.standard.set(trimmedKey, forKey: "openai_api_key")
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showSuccessMessage = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.25, green: 0.12, blue: 0.40),
                Color(red: 0.08, green: 0.55, blue: 0.70)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        APIKeySetupView(isPresented: .constant(true))
            .padding(32)
    }
    .preferredColorScheme(.dark)
} 