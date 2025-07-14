import SwiftUI

struct AddTaskView: View {
    @ObservedObject var viewModel: TaskListViewModel
    @Binding var isPresented: Bool
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedPriority = TaskPriority.medium
    @State private var selectedCategory: CategoryModel? = nil
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var estimatedDuration: Double = 30 // minutes
    @State private var hasEstimatedDuration = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Task title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Priority") {
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        Text("None").tag(CategoryModel?.none)
                        ForEach(viewModel.categories) { category in
                            Label(category.name, systemImage: category.icon)
                                .tag(CategoryModel?.some(category))
                        }
                    }
                }
                
                Section("Due Date") {
                    Toggle("Set due date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("Due date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                Section("Estimated Duration") {
                    Toggle("Set estimated time", isOn: $hasEstimatedDuration)
                    
                    if hasEstimatedDuration {
                        VStack(alignment: .leading) {
                            Text("Duration: \(Int(estimatedDuration)) minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Slider(value: $estimatedDuration, in: 5...180, step: 5) {
                                Text("Duration")
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Task")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(title.isEmpty)
                }
#else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(title.isEmpty)
                }
#endif
            }
        }
    }
    
    private func saveTask() {
        viewModel.createTask(
            title: title,
            description: description.isEmpty ? nil : description,
            dueDate: hasDueDate ? dueDate : nil,
            priority: selectedPriority,
            estimatedDuration: hasEstimatedDuration ? estimatedDuration * 60 : nil // Convert to seconds
        )
        
        // Set category if selected
        if let category = selectedCategory {
            viewModel.selectCategory(category)
            let tasks = viewModel.dataService.taskService.getAllTasks()
            if let newTask = tasks.first(where: { $0.title == title }) {
                newTask.category = category
                viewModel.dataService.save()
            }
        }
        
        isPresented = false
    }
}

#Preview {
    let dataService = DataService()
    let viewModel = TaskListViewModel(dataService: dataService)
    
    return AddTaskView(viewModel: viewModel, isPresented: .constant(true))
} 