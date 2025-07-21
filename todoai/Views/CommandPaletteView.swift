//
//  CommandPaletteView.swift
//  todoai
//
//  Lightning-fast command palette for instant task management
//  Inspired by developer tools and pro apps
//

import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct CommandPaletteView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [Todo]
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var isVisible = false
    @FocusState private var isSearchFocused: Bool
    
    #if canImport(UIKit)
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    #endif
    
    // Pre-computed filtered results for speed
    private var filteredCommands: [Command] {
        let baseCommands = Command.allCommands(todos: todos, modelContext: modelContext)
        
        if searchText.isEmpty {
            return baseCommands
        }
        
        return baseCommands.filter { command in
            command.title.localizedCaseInsensitiveContains(searchText) ||
            command.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            // Ultra-dark backdrop with blur
            Rectangle()
                .fill(.black.opacity(0.8))
                .background(.ultraThinMaterial.opacity(0.3))
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPalette()
                }
            
            // Command palette container
            VStack(spacing: 0) {
                // Search header
                searchHeader
                
                // Commands list
                commandsList
                
                // Footer with shortcuts
                paletteFooter
            }
            .frame(maxWidth: 600, maxHeight: 500)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.black.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .scaleEffect(isVisible ? 1 : 0.95)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
            isSearchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EscapeKeyPressed"))) { _ in
            dismissPalette()
        }
    }
    
    // MARK: - Search Header
    private var searchHeader: some View {
        HStack(spacing: 12) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            // Search field
            TextField("Search commands or type to create...", text: $searchText)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onChange(of: searchText) { _, _ in
                    selectedIndex = 0 // Reset selection on search
                }
            
            // Clear button
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    selectedIndex = 0
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }
    
    // MARK: - Commands List
    private var commandsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 2) {
                ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                    CommandRow(
                        command: command,
                        isSelected: index == selectedIndex,
                        onExecute: {
                            executeCommand(command)
                        }
                    )
                    .onTapGesture {
                        selectedIndex = index
                        executeCommand(command)
                    }
                }
                
                // Create new todo command if searching
                if !searchText.isEmpty && !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    let createCommand = Command.createTodo(title: searchText, modelContext: modelContext)
                    CommandRow(
                        command: createCommand,
                        isSelected: filteredCommands.count == selectedIndex,
                        onExecute: {
                            executeCommand(createCommand)
                        }
                    )
                    .onTapGesture {
                        selectedIndex = filteredCommands.count
                        executeCommand(createCommand)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 350)
    }
    
    // MARK: - Palette Footer
    private var paletteFooter: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Text("↑↓")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Text("navigate")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            HStack(spacing: 4) {
                Text("⏎")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Text("select")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            HStack(spacing: 4) {
                Text("esc")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Text("close")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Text("\(filteredCommands.count + (searchText.isEmpty ? 0 : 1)) commands")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.white.opacity(0.03))
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }
    
    // MARK: - Actions
    private func dismissPalette() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
    
    private func executeSelectedCommand() {
        let allCommands = filteredCommands + (searchText.isEmpty ? [] : [Command.createTodo(title: searchText, modelContext: modelContext)])
        
        guard selectedIndex < allCommands.count else { return }
        executeCommand(allCommands[selectedIndex])
    }
    
    private func executeCommand(_ command: Command) {
        #if canImport(UIKit)
        haptics.impactOccurred()
        #endif
        command.execute()
        dismissPalette()
    }
    
    private func navigateUp() {
        let totalCommands = filteredCommands.count + (searchText.isEmpty ? 0 : 1)
        selectedIndex = max(0, selectedIndex - 1)
        #if canImport(UIKit)
        haptics.impactOccurred()
        #endif
    }
    
    private func navigateDown() {
        let totalCommands = filteredCommands.count + (searchText.isEmpty ? 0 : 1)
        selectedIndex = min(totalCommands - 1, selectedIndex + 1)
        #if canImport(UIKit)
        haptics.impactOccurred()
        #endif
    }
}

// MARK: - Command Row
struct CommandRow: View {
    let command: Command
    let isSelected: Bool
    let onExecute: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Command icon
            ZStack {
                Circle()
                    .fill(command.color.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: command.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(command.color)
            }
            
            // Command text
            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                if !command.subtitle.isEmpty {
                    Text(command.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Keyboard shortcut hint
            if let shortcut = command.shortcut {
                Text(shortcut)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? .white.opacity(0.08) : .clear)
        )
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Command Model
struct Command: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let shortcut: String?
    let execute: () -> Void
    
    static func allCommands(todos: [Todo], modelContext: ModelContext) -> [Command] {
        var commands: [Command] = []
        
        // Quick actions
        commands.append(Command(
            title: "Clear All Completed",
            subtitle: "Remove all completed todos",
            icon: "trash.fill",
            color: .red,
            shortcut: "⌘⌫",
            execute: {
                let completedTodos = todos.filter(\.isCompleted)
                for todo in completedTodos {
                    modelContext.delete(todo)
                }
                try? modelContext.save()
            }
        ))
        
        commands.append(Command(
            title: "Mark All as Complete",
            subtitle: "Complete all remaining todos",
            icon: "checkmark.circle.fill",
            color: .green,
            shortcut: "⌘A",
            execute: {
                for todo in todos where !todo.isCompleted {
                    todo.isCompleted = true
                }
                try? modelContext.save()
            }
        ))
        
        commands.append(Command(
            title: "Focus Mode",
            subtitle: "Hide completed todos",
            icon: "eye.slash.fill",
            color: .blue,
            shortcut: "⌘F",
            execute: {
                // This would trigger a focus mode state change
                // Implementation depends on your app structure
            }
        ))
        
        // Individual todo commands
        let incompleteTodos = todos.filter { !$0.isCompleted }
        for todo in incompleteTodos.prefix(5) {
            commands.append(Command(
                title: "Complete: \(todo.title)",
                subtitle: "Mark this todo as complete",
                icon: "checkmark.circle",
                color: .green,
                shortcut: nil,
                execute: {
                    todo.isCompleted = true
                    try? modelContext.save()
                }
            ))
        }
        
        // Recent todos to delete
        let recentTodos = todos.suffix(3)
        for todo in recentTodos {
            commands.append(Command(
                title: "Delete: \(todo.title)",
                subtitle: "Permanently delete this todo",
                icon: "trash",
                color: .red,
                shortcut: nil,
                execute: {
                    modelContext.delete(todo)
                    try? modelContext.save()
                }
            ))
        }
        
        return commands
    }
    
    static func createTodo(title: String, modelContext: ModelContext) -> Command {
        Command(
            title: "Create: \(title)",
            subtitle: "Add new todo",
            icon: "plus.circle.fill",
            color: .cyan,
            shortcut: "⏎",
            execute: {
                let todo = Todo(title: title.trimmingCharacters(in: .whitespaces))
                modelContext.insert(todo)
                try? modelContext.save()
            }
        )
    }
}