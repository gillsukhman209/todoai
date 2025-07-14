import SwiftUI

struct MainNavigationView: View {
    @StateObject private var mainViewModel = MainViewModel()
    
    var body: some View {
        NavigationStack {
            TabView(selection: $mainViewModel.selectedTab) {
                TodayView(viewModel: mainViewModel.taskListViewModel)
                    .tabItem {
                        Label("Today", systemImage: "sun.max")
                    }
                    .tag(AppTab.today)
                
                TaskListView(viewModel: mainViewModel.taskListViewModel)
                    .tabItem {
                        Label("All Tasks", systemImage: "list.bullet")
                    }
                    .tag(AppTab.all)
                
                CompletedTasksView(viewModel: mainViewModel.taskListViewModel)
                    .tabItem {
                        Label("Completed", systemImage: "checkmark.circle")
                    }
                    .tag(AppTab.completed)
            }
            .navigationTitle(mainViewModel.selectedTab.rawValue)
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: mainViewModel.showAddTask) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: mainViewModel.showSettings) {
                        Image(systemName: "gear")
                    }
                }
#else
                ToolbarItem(placement: .primaryAction) {
                    Button(action: mainViewModel.showAddTask) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Button(action: mainViewModel.showSettings) {
                        Image(systemName: "gear")
                    }
                }
#endif
            }
        }
        .sheet(isPresented: $mainViewModel.isShowingAddTask) {
            AddTaskView(viewModel: mainViewModel.taskListViewModel, isPresented: $mainViewModel.isShowingAddTask)
        }
        .sheet(isPresented: $mainViewModel.isShowingSettings) {
            SettingsView(dataService: mainViewModel.dataService, isPresented: $mainViewModel.isShowingSettings)
        }
        .onChange(of: mainViewModel.selectedTab) { _, newTab in
            mainViewModel.selectTab(newTab)
        }
    }
}

#Preview {
    MainNavigationView()
} 