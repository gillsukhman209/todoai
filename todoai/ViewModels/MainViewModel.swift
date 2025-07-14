import Foundation
import SwiftData

@MainActor
class MainViewModel: ObservableObject {
    @Published var selectedTab: AppTab = .today
    @Published var isShowingAddTask = false
    @Published var isShowingSettings = false
    
    let dataService: DataService
    let taskListViewModel: TaskListViewModel
    
    init() {
        self.dataService = DataService()
        self.taskListViewModel = TaskListViewModel(dataService: dataService)
    }
    
    // MARK: - Navigation
    
    func selectTab(_ tab: AppTab) {
        selectedTab = tab
        // Refresh data when switching tabs
        taskListViewModel.loadData()
    }
    
    func showAddTask() {
        isShowingAddTask = true
    }
    
    func hideAddTask() {
        isShowingAddTask = false
    }
    
    func showSettings() {
        isShowingSettings = true
    }
    
    func hideSettings() {
        isShowingSettings = false
    }
    
    // MARK: - Quick Actions
    
    func getTasksForTab(_ tab: AppTab) -> [TaskModel] {
        switch tab {
        case .today:
            return taskListViewModel.todaysTasks
        case .all:
            return dataService.taskService.getPendingTasks()
        case .completed:
            return dataService.taskService.getCompletedTasks()
        }
    }
    
    var todaysTaskCount: Int {
        taskListViewModel.todaysTasks.count
    }
    
    var overdueTaskCount: Int {
        taskListViewModel.overdueTasks.count
    }
    
    var totalPendingTaskCount: Int {
        dataService.taskService.getPendingTasks().count
    }
}

enum AppTab: String, CaseIterable {
    case today = "Today"
    case all = "All Tasks"
    case completed = "Completed"
    
    var iconName: String {
        switch self {
        case .today: return "sun.max"
        case .all: return "list.bullet"
        case .completed: return "checkmark.circle"
        }
    }
} 