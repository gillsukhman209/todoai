//
//  SimpleCommandPaletteView.swift
//  todoai
//
//  Simplified command palette without keyboard dependencies
//

import SwiftUI
import SwiftData

struct SimpleCommandPaletteView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [Todo]
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var isVisible = false
    @FocusState private var isSearchFocused: Bool
    
    // Pre-computed filtered results for speed
    private var filteredCommands: [SimpleCommand] {
        let baseCommands = SimpleCommand.allCommands(todos: todos, modelContext: modelContext)
        
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
                .fill(Color.black.opacity(0.8))
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
                
                // Footer
                paletteFooter
            }
            .frame(maxWidth: 600, maxHeight: 500)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
                .onSubmit {
                    if !searchText.isEmpty {
                        let createCommand = SimpleCommand.createTodo(title: searchText, modelContext: modelContext)
                        createCommand.execute()
                        dismissPalette()
                    }
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
                    SimpleCommandRow(
                        command: command,
                        isSelected: index == selectedIndex,
                        onExecute: {
                            command.execute()
                            dismissPalette()
                        }
                    )
                    .onTapGesture {
                        selectedIndex = index
                        command.execute()
                        dismissPalette()
                    }
                }
                
                // Create new todo command if searching
                if !searchText.isEmpty && !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    let createCommand = SimpleCommand.createTodo(title: searchText, modelContext: modelContext)
                    SimpleCommandRow(
                        command: createCommand,
                        isSelected: filteredCommands.count == selectedIndex,
                        onExecute: {
                            createCommand.execute()
                            dismissPalette()
                        }
                    )
                    .onTapGesture {
                        selectedIndex = filteredCommands.count
                        createCommand.execute()
                        dismissPalette()
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
            Text("Press Enter to create task")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
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
}

// MARK: - Simple Command Row
struct SimpleCommandRow: View {
    let command: SimpleCommand
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

// MARK: - Simple Command Model
struct SimpleCommand: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let execute: () -> Void
    
    static func allCommands(todos: [Todo], modelContext: ModelContext) -> [SimpleCommand] {
        var commands: [SimpleCommand] = []
        
        // Quick actions
        commands.append(SimpleCommand(
            title: "Clear All Completed",
            subtitle: "Remove all completed todos",
            icon: "trash.fill",
            color: .red,
            execute: {
                let completedTodos = todos.filter(\.isCompleted)
                for todo in completedTodos {
                    modelContext.delete(todo)
                }
                try? modelContext.save()
            }
        ))
        
        commands.append(SimpleCommand(
            title: "Mark All as Complete",
            subtitle: "Complete all remaining todos",
            icon: "checkmark.circle.fill",
            color: .green,
            execute: {
                for todo in todos where !todo.isCompleted {
                    todo.isCompleted = true
                }
                try? modelContext.save()
            }
        ))
        
        // View switching commands
        commands.append(SimpleCommand(
            title: "Switch to Calendar View",
            subtitle: "View todos in calendar layout",
            icon: "calendar",
            color: .blue,
            execute: {
                // This would trigger view change - implementation depends on app structure
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToCalendar"), object: nil)
            }
        ))
        
        commands.append(SimpleCommand(
            title: "Switch to Today View",
            subtitle: "View today's todos only",
            icon: "calendar.badge.clock",
            color: .orange,
            execute: {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToToday"), object: nil)
            }
        ))
        
        // Recent todos for quick completion
        let recentTodos = todos.filter { !$0.isCompleted }.suffix(3)
        for todo in recentTodos {
            commands.append(SimpleCommand(
                title: "Complete: \(todo.title)",
                subtitle: "Mark as done",
                icon: "checkmark.circle",
                color: .green,
                execute: {
                    todo.isCompleted = true
                    try? modelContext.save()
                }
            ))
        }
        
        // Individual todo commands
        let incompleteTodos = todos.filter { !$0.isCompleted }
        for todo in incompleteTodos.prefix(5) {
            commands.append(SimpleCommand(
                title: "Complete: \(todo.title)",
                subtitle: "Mark this todo as complete",
                icon: "checkmark.circle",
                color: .green,
                execute: {
                    todo.isCompleted = true
                    try? modelContext.save()
                }
            ))
        }
        
        return commands
    }
    
    static func createTodo(title: String, modelContext: ModelContext) -> SimpleCommand {
        SimpleCommand(
            title: "Create: \(title)",
            subtitle: "Add new todo",
            icon: "plus.circle.fill",
            color: .cyan,
            execute: {
                let todo = Todo(title: title.trimmingCharacters(in: .whitespaces))
                modelContext.insert(todo)
                try? modelContext.save()
            }
        )
    }
}