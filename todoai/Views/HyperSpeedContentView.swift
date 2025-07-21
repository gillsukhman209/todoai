//
//  HyperSpeedContentView.swift
//  todoai
//
//  Ultra-Fast Todo Interface - Designed for Speed
//  Zero friction, maximum productivity
//

import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct HyperSpeedContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [Todo]
    @State private var quickInput = ""
    @State private var isInputActive = false
    @State private var lastTapTime = Date()
    @FocusState private var isInputFocused: Bool
    
    // Speed optimizations
    @State private var cachedTodoCount = 0
    @State private var cachedCompletedCount = 0
    #if canImport(UIKit)
    private let haptics = UIImpactFeedbackGenerator(style: .light)
    #endif
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Ultra minimal background
                hyperSpeedBackground
                
                VStack(spacing: 0) {
                    // Lightning fast header
                    hyperSpeedHeader
                    
                    // Instant todo list
                    instantTodoList
                    
                    Spacer()
                    
                    // Zero-latency input
                    zeroLatencyInput
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            precomputeStats()
        }
        .onChange(of: todos) { _, _ in
            precomputeStats()
        }
    }
    
    // MARK: - Ultra Minimal Background
    private var hyperSpeedBackground: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.02, green: 0.02, blue: 0.04),
                        Color(red: 0.01, green: 0.01, blue: 0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .ignoresSafeArea()
    }
    
    // MARK: - Lightning Fast Header
    private var hyperSpeedHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TODOS")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .kerning(-0.5)
                
                HStack(spacing: 8) {
                    Text("\(cachedTodoCount - cachedCompletedCount)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    
                    Text("active")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Circle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 3, height: 3)
                    
                    Text("\(cachedCompletedCount)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                    
                    Text("done")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Quick stats indicator
            VStack(spacing: 4) {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 8, height: 8)
                    .opacity(0.8)
                
                Text("LIVE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.cyan.opacity(0.8))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Instant Todo List
    private var instantTodoList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 1) {
                ForEach(todos, id: \.createdAt) { todo in
                    HyperSpeedTodoRow(
                        todo: todo,
                        modelContext: modelContext,
                        onUpdate: precomputeStats
                    )
                }
                
                if todos.isEmpty {
                    speedEmptyState
                }
            }
            .padding(.horizontal, 24)
        }
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Speed-Optimized Empty State
    private var speedEmptyState: some View {
        VStack(spacing: 16) {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 2)
                .frame(width: 60, height: 60)
                .overlay(
                    Text("✓")
                        .font(.system(size: 28, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.3))
                )
            
            Text("Start typing to add todos")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.top, 80)
    }
    
    // MARK: - Zero Latency Input
    private var zeroLatencyInput: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                TextField("", text: $quickInput)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .onSubmit {
                        createTodoInstantly()
                    }
                    .onChange(of: quickInput) { _, newValue in
                        if newValue.count == 1 && !isInputActive {
                            isInputActive = true
                            #if canImport(UIKit)
                            haptics.impactOccurred()
                            #endif
                        }
                    }
                    .placeholder(when: quickInput.isEmpty && !isInputFocused) {
                        Text("Type and hit enter...")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                    }
                
                if !quickInput.isEmpty {
                    Button(action: createTodoInstantly) {
                        Circle()
                            .fill(.cyan)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                            )
                    }
                    .transition(.scale.combined(with: .opacity))
                    .scaleEffect(isInputFocused ? 1.1 : 1.0)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial.opacity(0.1))
                    .overlay(
                        Rectangle()
                            .stroke(.white.opacity(isInputFocused ? 0.3 : 0.1), lineWidth: 1)
                    )
            )
            .onTapGesture {
                isInputFocused = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: isInputFocused)
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9), value: quickInput.isEmpty)
    }
    
    // MARK: - Speed Optimized Functions
    private func createTodoInstantly() {
        guard !quickInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let todo = Todo(title: quickInput.trimmingCharacters(in: .whitespaces))
        modelContext.insert(todo)
        
        // Instant feedback
        #if canImport(UIKit)
        haptics.impactOccurred()
        #endif
        
        quickInput = ""
        
        // Async save to not block UI
        Task {
            try? await MainActor.run {
                try? modelContext.save()
            }
        }
    }
    
    private func precomputeStats() {
        cachedTodoCount = todos.count
        cachedCompletedCount = todos.filter(\.isCompleted).count
    }
}

// MARK: - Hyper Speed Todo Row
struct HyperSpeedTodoRow: View {
    let todo: Todo
    let modelContext: ModelContext
    let onUpdate: () -> Void
    
    @State private var isPressed = false
    @State private var deleteOffset: CGFloat = 0
    #if canImport(UIKit)
    private let haptics = UIImpactFeedbackGenerator(style: .light)
    #endif
    
    var body: some View {
        HStack(spacing: 16) {
            // Instant completion toggle
            Button(action: toggleInstantly) {
                ZStack {
                    Circle()
                        .stroke(todo.isCompleted ? .green : .white.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if todo.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                            .scaleEffect(isPressed ? 1.3 : 1.0)
                    }
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(isPressed ? 0.9 : 1.0)
            
            // Todo text
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(todo.isCompleted ? .white.opacity(0.4) : .white)
                    .strikethrough(todo.isCompleted, color: .white.opacity(0.4))
                    .lineLimit(2)
                
                Text(timeAgo(from: todo.createdAt))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(todo.isCompleted ? .green.opacity(0.6) : .cyan.opacity(0.6))
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(todo.isCompleted ? .white.opacity(0.02) : .white.opacity(0.05))
                .overlay(
                    Rectangle()
                        .stroke(.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .offset(x: deleteOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width < -50 {
                        deleteOffset = value.translation.width + 50
                    }
                }
                .onEnded { value in
                    if value.translation.width < -100 {
                        deleteTodo()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            deleteOffset = 0
                        }
                    }
                }
        )
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: deleteOffset)
    }
    
    private func toggleInstantly() {
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
        
        // Async save
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
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            deleteOffset = -400
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            modelContext.delete(todo)
            try? modelContext.save()
            onUpdate()
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d"
        }
    }
}

// MARK: - Extensions
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}