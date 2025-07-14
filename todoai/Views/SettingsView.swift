import SwiftUI

struct SettingsView: View {
    let dataService: DataService
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Development") {
                    Button("Create Sample Data") {
                        dataService.createSampleData()
                    }
                    
                    Button("Clear All Data", role: .destructive) {
                        // Note: This is a placeholder for development
                        // In production, this would need proper confirmation
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("Phase 1")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
#else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
#endif
            }
        }
    }
}

#Preview {
    SettingsView(dataService: DataService(), isPresented: .constant(true))
} 