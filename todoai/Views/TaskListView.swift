import SwiftUI

struct TaskListView: View {
    @ObservedObject var viewModel: TaskListViewModel
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBar(text: $searchText)
                .onChange(of: searchText) { _, newValue in
                    viewModel.updateSearchText(newValue)
                }
            
            // Category filter
            CategoryFilterView(
                categories: viewModel.categories,
                selectedCategory: viewModel.selectedCategory,
                onCategorySelected: viewModel.selectCategory
            )
            
            // Task list
            if viewModel.tasks.isEmpty {
                EmptyStateView(
                    title: "No tasks found",
                    subtitle: searchText.isEmpty ? "Add your first task!" : "Try a different search term",
                    systemImage: "list.bullet"
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
        .onAppear {
            viewModel.loadData()
        }
        .refreshable {
            viewModel.loadData()
        }
    }
}

#Preview {
    let dataService = DataService()
    dataService.createSampleData()
    
    return TaskListView(viewModel: TaskListViewModel(dataService: dataService))
} 