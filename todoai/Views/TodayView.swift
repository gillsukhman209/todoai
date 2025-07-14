import SwiftUI

struct TodayView: View {
    @ObservedObject var viewModel: TaskListViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Quick stats
                StatsCardView(
                    todayCount: viewModel.todaysTasks.count,
                    overdueCount: viewModel.overdueTasks.count
                )
                
                // Overdue tasks section
                if !viewModel.overdueTasks.isEmpty {
                    TaskSectionView(
                        title: "Overdue",
                        tasks: viewModel.overdueTasks,
                        color: .red,
                        onToggleComplete: viewModel.toggleTaskCompletion,
                        onDelete: viewModel.deleteTask
                    )
                }
                
                // Today's tasks section
                TaskSectionView(
                    title: "Today",
                    tasks: viewModel.todaysTasks,
                    color: .blue,
                    onToggleComplete: viewModel.toggleTaskCompletion,
                    onDelete: viewModel.deleteTask
                )
                
                // Empty state
                if viewModel.todaysTasks.isEmpty && viewModel.overdueTasks.isEmpty {
                    EmptyStateView(
                        title: "No tasks for today",
                        subtitle: "Enjoy your free time! 🎉",
                        systemImage: "sun.max"
                    )
                }
            }
            .padding()
        }
        .refreshable {
            viewModel.loadData()
        }
        .onAppear {
            viewModel.loadData()
        }
    }
}

#Preview {
    let dataService = DataService()
    dataService.createSampleData()
    
    return TodayView(viewModel: TaskListViewModel(dataService: dataService))
} 