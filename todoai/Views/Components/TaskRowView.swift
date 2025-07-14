import SwiftUI

struct TaskRowView: View {
    let task: TaskModel
    let onToggleComplete: (TaskModel) -> Void
    let onDelete: (TaskModel) -> Void
    
    var body: some View {
        HStack {
            // Completion button
            Button(action: { onToggleComplete(task) }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .gray)
                    .font(.title2)
            }
            .buttonStyle(BorderlessButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                // Task title
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                
                // Task description
                if let description = task.taskDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Task metadata
                HStack {
                    // Priority indicator
                    PriorityIndicator(priority: task.priority)
                    
                    // Category
                    if let category = task.category {
                        CategoryChip(category: category)
                    }
                    
                    Spacer()
                    
                    // Due date
                    if let dueDate = task.dueDate {
                        DueDateView(date: dueDate, isCompleted: task.isCompleted)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                onDelete(task)
            }
        }
    }
}

struct PriorityIndicator: View {
    let priority: TaskPriority
    
    var body: some View {
        Circle()
            .fill(priorityColor)
            .frame(width: 8, height: 8)
    }
    
    private var priorityColor: Color {
        switch priority {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
}

struct CategoryChip: View {
    let category: CategoryModel
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.caption2)
            Text(category.name)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(hex: category.color).opacity(0.2))
        .foregroundColor(Color(hex: category.color))
        .cornerRadius(8)
    }
}

struct DueDateView: View {
    let date: Date
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.caption2)
            Text(date, style: .date)
                .font(.caption2)
        }
        .foregroundColor(dateColor)
    }
    
    private var dateColor: Color {
        if isCompleted {
            return .secondary
        } else if date < Date() {
            return .red
        } else if Calendar.current.isDateInToday(date) {
            return .orange
        } else {
            return .secondary
        }
    }
}

// Helper extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    let task = TaskModel(
        title: "Sample Task",
        description: "This is a sample task description",
        dueDate: Date(),
        priority: .high
    )
    
    return TaskRowView(
        task: task,
        onToggleComplete: { _ in },
        onDelete: { _ in }
    )
    .padding()
} 