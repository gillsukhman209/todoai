//
//  InterfaceSelectorView.swift
//  todoai
//
//  Interface selector for ultra-fast todo redesigns
//

import SwiftUI
import SwiftData

enum TodoInterface: String, CaseIterable {
    case original = "Original"
    case hyperSpeed = "Hyper Speed"
    case gestureEnhanced = "Gesture Enhanced"
    case revolutionary = "Revolutionary"
    
    var icon: String {
        switch self {
        case .original: return "calendar"
        case .hyperSpeed: return "bolt.fill"
        case .gestureEnhanced: return "hand.tap.fill"
        case .revolutionary: return "sparkles"
        }
    }
    
    var description: String {
        switch self {
        case .original: return "Full-featured calendar view"
        case .hyperSpeed: return "Lightning-fast minimalist interface"
        case .gestureEnhanced: return "Pro gestures + command palette"
        case .revolutionary: return "AI-powered futuristic interface"
        }
    }
}

struct InterfaceSelectorView: View {
    @State private var selectedInterface: TodoInterface = .gestureEnhanced
    @State private var showingInterfaceSelector = false
    
    var body: some View {
        ZStack {
            // Main interface based on selection
            Group {
                switch selectedInterface {
                case .original:
                    ContentView()
                case .hyperSpeed:
                    HyperSpeedContentView()
                case .gestureEnhanced:
                    GestureEnhancedContentView()
                case .revolutionary:
                    RevolutionaryContentView()
                }
            }
            
            // Floating interface switcher
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    interfaceSwitcher
                }
            }
            .padding(24)
            
            // Interface selection sheet
            if showingInterfaceSelector {
                interfaceSelectionOverlay
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: selectedInterface)
    }
    
    // MARK: - Interface Switcher Button
    private var interfaceSwitcher: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showingInterfaceSelector.toggle()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: selectedInterface.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(selectedInterface.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .rotationEffect(.degrees(showingInterfaceSelector ? 180 : 0))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial.opacity(0.8))
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .scaleEffect(showingInterfaceSelector ? 1.05 : 1.0)
    }
    
    // MARK: - Interface Selection Overlay
    private var interfaceSelectionOverlay: some View {
        ZStack {
            // Backdrop
            Rectangle()
                .fill(.black.opacity(0.6))
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        showingInterfaceSelector = false
                    }
                }
            
            // Selection panel
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Choose Interface")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Select the perfect todo interface for maximum speed")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                
                // Interface options
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(TodoInterface.allCases, id: \.self) { interface in
                        interfaceCard(for: interface)
                    }
                }
                
                // Close button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        showingInterfaceSelector = false
                    }
                }) {
                    Text("Done")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.cyan.opacity(0.8))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 500)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(showingInterfaceSelector ? 1 : 0.9)
            .opacity(showingInterfaceSelector ? 1 : 0)
        }
    }
    
    // MARK: - Interface Card
    private func interfaceCard(for interface: TodoInterface) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedInterface = interface
            }
            
            // Auto-close after selection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                    showingInterfaceSelector = false
                }
            }
        }) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(interface == selectedInterface ? .cyan.opacity(0.3) : .white.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: interface.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(interface == selectedInterface ? .cyan : .white.opacity(0.8))
                }
                
                // Title
                Text(interface.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                // Description
                Text(interface.description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                // Selected indicator
                if interface == selectedInterface {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.cyan)
                        
                        Text("Selected")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.cyan)
                    }
                }
            }
            .padding(16)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(interface == selectedInterface ? .cyan.opacity(0.1) : .white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(interface == selectedInterface ? .cyan.opacity(0.5) : .white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(interface == selectedInterface ? 1.05 : 1.0)
    }
}

#Preview {
    InterfaceSelectorView()
}