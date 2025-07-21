//
//  RevolutionaryContentView.swift
//  todoai
//
//  Revolutionary AI-Era Main Interface
//

import SwiftUI
import SwiftData

struct RevolutionaryContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [Todo]
    @State private var currentInput = ""
    @State private var isTyping = false
    @State private var ambientPulse: Double = 0
    @State private var backgroundIntensity: Double = 1.0
    @State private var interfaceScale: CGFloat = 1.0
    
    private let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left sidebar with todos and calendar
                todoSidebar
                    .frame(width: 350)
                
                // Main revolutionary interface
                ZStack {
                    // Infinite space background with quantum effects
                    quantumSpaceBackground
                    
                    // Central AI orb
                    AIOrb()
                        .position(x: (geometry.size.width - 350) / 2, y: geometry.size.height / 2)
                        .onTapGesture {
                            focusOnOrb()
                        }
                    
                    // Floating task particles
                    ForEach(todos, id: \.createdAt) { todo in
                        TaskParticle(todo: todo, geometry: geometry)
                            .onTapGesture {
                                // Handle task tap
                            }
                    }
                    
                    // Conversational input interface
                    conversationalInterface
                }
            }
        }
        .preferredColorScheme(.dark)
        .scaleEffect(interfaceScale)
        .onReceive(timer) { _ in
            updateAmbientEffects()
        }
    }
    
    // MARK: - Quantum Space Background
    private var quantumSpaceBackground: some View {
        ZStack {
            // Deep space gradient
            RadialGradient(
                colors: [
                    Color(red: 0.02, green: 0.01, blue: 0.08),
                    Color(red: 0.01, green: 0.005, blue: 0.04),
                    Color.black
                ],
                center: .center,
                startRadius: 0,
                endRadius: 1000
            )
            .ignoresSafeArea()
            
            // Quantum field particles
            quantumFieldEffect
            
            // Breathing cosmic energy
            cosmicBreathingEffect
        }
        .opacity(backgroundIntensity)
    }
    
    // MARK: - Quantum Field Effect
    private var quantumFieldEffect: some View {
        Canvas { context, size in
            let particleCount = 100
            let time = Date().timeIntervalSince1970
            
            for i in 0..<particleCount {
                let x = CGFloat(i) / CGFloat(particleCount) * size.width
                let y = sin(time * 0.5 + Double(i) * 0.1) * 50 + size.height / 2
                let opacity = (sin(time + Double(i) * 0.2) + 1) / 4
                
                context.fill(
                    Circle().path(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                    with: .color(Color.cyan.opacity(opacity))
                )
            }
        }
        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: backgroundIntensity)
    }
    
    // MARK: - Cosmic Breathing Effect
    private var cosmicBreathingEffect: some View {
        ForEach(0..<3, id: \.self) { index in
            Circle()
                .stroke(
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    ),
                    lineWidth: 1
                )
                .frame(width: 400 + CGFloat(index * 100), height: 400 + CGFloat(index * 100))
                .opacity(0.3)
                .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 0.5 + Double(index)) * 0.1)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: backgroundIntensity)
        }
    }
    
    // MARK: - Conversational Interface
    private var conversationalInterface: some View {
        VStack {
            Spacer()
            
            // Revolutionary floating input
            QuantumInputField(
                currentInput: $currentInput,
                onSubmit: {
                    createTaskFromInput()
                }
            )
            .padding(.bottom, 80)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    // MARK: - Todo Sidebar
    private var todoSidebar: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Today")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(Date().formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Todo List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(todos, id: \.createdAt) { todo in
                        TodoRow(todo: todo, modelContext: modelContext)
                    }
                    
                    if todos.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.3))
                            
                            Text("No todos yet")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("Use the input below to add your first task")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 50)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            
            Spacer()
            
            // Quick stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(todos.filter { !$0.isCompleted }.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(todos.filter { $0.isCompleted }.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Completed")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.9),
                    Color(red: 0.05, green: 0.05, blue: 0.15).opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Helper Methods
    private func updateAmbientEffects() {
        ambientPulse += 1
    }
    
    private func focusOnOrb() {
        withAnimation(.easeInOut(duration: 0.5)) {
            interfaceScale = 1.05
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                interfaceScale = 1.0
            }
        }
    }
    
    private func createTaskFromInput() {
        guard !currentInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let todo = Todo(title: currentInput.trimmingCharacters(in: .whitespaces))
        modelContext.insert(todo)
        try? modelContext.save()
        currentInput = ""
    }
}

// MARK: - AI Orb
struct AIOrb: View {
    @State private var orbScale: CGFloat = 1.0
    @State private var orbGlow: Double = 0.5
    @State private var rotationAngle: Double = 0
    
    private let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.cyan.opacity(orbGlow * 0.8),
                            Color.blue.opacity(orbGlow * 0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .blur(radius: 10)
            
            // Main orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color.cyan.opacity(0.8),
                            Color.blue.opacity(0.7)
                        ],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: 40
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                        .blur(radius: 1)
                )
                .scaleEffect(orbScale)
                .rotationEffect(.degrees(rotationAngle))
        }
        .onReceive(timer) { _ in
            updateOrb()
        }
        .onAppear {
            startOrbAnimation()
        }
    }
    
    private func updateOrb() {
        rotationAngle += 0.5
        if rotationAngle >= 360 {
            rotationAngle = 0
        }
    }
    
    private func startOrbAnimation() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            orbGlow = 1.0
        }
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            orbScale = 1.1
        }
    }
}

// MARK: - Task Particle
struct TaskParticle: View {
    let todo: Todo
    let geometry: GeometryProxy
    
    @State private var orbitAngle: Double = Double.random(in: 0...360)
    @State private var orbitRadius: CGFloat = CGFloat.random(in: 120...280)
    @State private var particleScale: CGFloat = 1.0
    
    private let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Particle glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            particleColor.opacity(0.8),
                            particleColor.opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 15
                    )
                )
                .frame(width: 30, height: 30)
                .blur(radius: 3)
            
            // Main particle
            Circle()
                .fill(particleColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )
                .scaleEffect(particleScale)
            
            // Task label (appears on hover or when close)
            Text(todo.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.8))
                        .stroke(particleColor.opacity(0.6), lineWidth: 1)
                )
                .offset(y: -25)
                .opacity(0.8)
        }
        .position(particlePosition)
        .onReceive(timer) { _ in
            updateOrbit()
        }
        .onAppear {
            startParticleAnimation()
        }
    }
    
    private var particlePosition: CGPoint {
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        
        let x = centerX + cos(orbitAngle * .pi / 180) * orbitRadius
        let y = centerY + sin(orbitAngle * .pi / 180) * orbitRadius
        
        return CGPoint(x: x, y: y)
    }
    
    private var particleColor: Color {
        if todo.isCompleted {
            return .green
        } else {
            return .cyan
        }
    }
    
    private func updateOrbit() {
        orbitAngle += 0.3
        if orbitAngle >= 360 {
            orbitAngle = 0
        }
    }
    
    private func startParticleAnimation() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            particleScale = 1.2
        }
    }
}

// MARK: - Quantum Input Field
struct QuantumInputField: View {
    @Binding var currentInput: String
    let onSubmit: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            HStack {
                TextField("Tell me what you need to do...", text: $currentInput)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        onSubmit()
                    }
                
                if !currentInput.isEmpty {
                    Button(action: onSubmit) {
                        Circle()
                            .fill(Color.cyan.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(quantumInputBackground)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 40)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    private var quantumInputBackground: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)
                .opacity(0.8)
            
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.6),
                            Color.purple.opacity(0.4),
                            Color.blue.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

// MARK: - Todo Row
struct TodoRow: View {
    let todo: Todo
    let modelContext: ModelContext
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion button
            Button(action: toggleCompletion) {
                Circle()
                    .fill(todo.isCompleted ? Color.green : Color.clear)
                    .stroke(todo.isCompleted ? Color.green : Color.white.opacity(0.5), lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(todo.isCompleted ? 1 : 0)
                    )
            }
            .buttonStyle(.plain)
            
            // Task text
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(todo.isCompleted ? .white.opacity(0.5) : .white)
                    .strikethrough(todo.isCompleted)
                
                Text("Created \(todo.createdAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(todo.isCompleted ? Color.green : Color.cyan)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(todo.isCompleted ? 0.02 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func toggleCompletion() {
        withAnimation(.easeInOut(duration: 0.3)) {
            todo.isCompleted.toggle()
            try? modelContext.save()
        }
    }
}