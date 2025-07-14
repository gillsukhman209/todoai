import SwiftUI

struct CompletedTasksView: View {
    @ObservedObject var viewModel: TaskListViewModel
    
    var body: some View {
        VStack {
            if viewModel.isShowingCompletedTasks {
                if viewModel.tasks.isEmpty {
                    EmptyStateView(
                        title: "No completed tasks",
                        subtitle: "Complete some tasks to see them here",
                        systemImage: "checkmark.circle"
                    )
                } else {
                    List {
                        ForEach(viewModel.tasks) { task in
                            TaskRowView(
                                task: task,
                                onToggleComplete: viewModel.toggleTaskCompletion,
                                onDelete: viewModel.deleteTask
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
        .onAppear {
            viewModel.isShowingCompletedTasks = true
            viewModel.loadData()
        }
        .onDisappear {
            viewModel.isShowingCompletedTasks = false
        }
        .refreshable {
            viewModel.loadData()
        }
    }
}

#Preview {
    let dataService = DataService()
    let viewModel = TaskListViewModel(dataService: dataService)
    viewModel.isShowingCompletedTasks = true
    
    return CompletedTasksView(viewModel: viewModel)
} 