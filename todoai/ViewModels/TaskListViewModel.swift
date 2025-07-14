import Foundation
import SwiftData

@MainActor
class TaskListViewModel: ObservableObject {
    @Published var tasks: [TaskModel] = []
    @Published var categories: [CategoryModel] = []
    @Published var selectedCategory: CategoryModel? = nil
    @Published var isShowingCompletedTasks = false
    @Published var searchText = ""
    
    let dataService: DataService
    
    init(dataService: DataService) {
        self.dataService = dataService
        loadData()
    }
    
    // MARK: - Data Loading
    
    func loadData() {
        loadCategories()
        loadTasks()
    }
    
    private func loadCategories() {
        categories = dataService.categoryService.getAllCategories()
    }
    
    private func loadTasks() {
        if isShowingCompletedTasks {
            tasks = dataService.taskService.getCompletedTasks()
        } else if let selectedCategory = selectedCategory {
            tasks = dataService.taskService.getTasks(for: selectedCategory)
                .filter { !$0.isCompleted }
        } else {
            tasks = dataService.taskService.getPendingTasks()
        }
        
        // Apply search filter if needed
        if !searchText.isEmpty {
            tasks = tasks.filter { task in
                task.title.localizedCaseInsensitiveContains(searchText) ||
                (task.taskDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    // MARK: - Task Actions
    
    func createTask(
        title: String,
        description: String? = nil,
        dueDate: Date? = nil,
        priority: TaskPriority = .medium,
        estimatedDuration: TimeInterval? = nil
    ) {
        let _ = dataService.taskService.createTask(
            title: title,
            description: description,
            dueDate: dueDate,
            priority: priority,
            category: selectedCategory,
            estimatedDuration: estimatedDuration
        )
        dataService.save()
        loadTasks()
    }
    
    func toggleTaskCompletion(_ task: TaskModel) {
        if task.isCompleted {
            dataService.taskService.uncompleteTask(task)
        } else {
            dataService.taskService.completeTask(task)
        }
        loadTasks()
    }
    
    func deleteTask(_ task: TaskModel) {
        dataService.taskService.deleteTask(task)
        loadTasks()
    }
    
    func updateTask(_ task: TaskModel) {
        dataService.taskService.updateTask(task)
        loadTasks()
    }
    
    // MARK: - Filtering and Sorting
    
    func selectCategory(_ category: CategoryModel?) {
        selectedCategory = category
        loadTasks()
    }
    
    func toggleShowCompleted() {
        isShowingCompletedTasks.toggle()
        loadTasks()
    }
    
    func updateSearchText(_ text: String) {
        searchText = text
        loadTasks()
    }
    
    // MARK: - Computed Properties
    
    var todaysTasks: [TaskModel] {
        dataService.taskService.getTasksDueToday()
    }
    
    var overdueTasks: [TaskModel] {
        dataService.taskService.getOverdueTasks()
    }
    
    var tasksByPriority: [TaskPriority: [TaskModel]] {
        Dictionary(grouping: tasks.filter { !$0.isCompleted }) { $0.priority }
    }
    
    // MARK: - Development Support
    
    func createSampleData() {
        dataService.createSampleData()
        loadData()
    }
} 