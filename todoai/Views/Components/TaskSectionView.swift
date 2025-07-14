import SwiftUI

struct TaskSectionView: View {
    let title: String
    let tasks: [TaskModel]
    let color: Color
    let onToggleComplete: (TaskModel) -> Void
    let onDelete: (TaskModel) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                
                Spacer()
                
                Text("\(tasks.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.2))
                    .cornerRadius(8)
            }
            
            // Tasks list
            if tasks.isEmpty {
                Text("No tasks in this section")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(tasks) { task in
                        TaskRowView(
                            task: task,
                            onToggleComplete: onToggleComplete,
                            onDelete: onDelete
                        )
                        .padding(.horizontal)
                        .background(.background)
                        
                        if task != tasks.last {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(Color(.quaternarySystemFill))
                .cornerRadius(12)
            }
        }
    }
}

#Preview {
    let sampleTasks = [
        TaskModel(
            title: "Complete project proposal",
            description: "Finish the Q4 project proposal for client review",
            dueDate: Date(),
            priority: .high
        ),
        TaskModel(
            title: "Team meeting",
            description: "Weekly team sync at 3 PM",
            dueDate: Date(),
            priority: .medium
        )
    ]
    
    return TaskSectionView(
        title: "Today",
        tasks: sampleTasks,
        color: .blue,
        onToggleComplete: { _ in },
        onDelete: { _ in }
    )
    .padding()
} 