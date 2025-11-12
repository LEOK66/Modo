import SwiftUI
import SwiftData
import FirebaseAuth

struct MainPageView: View {
    @Binding var selectedTab: Tab
    @EnvironmentObject var dailyCaloriesService: DailyCaloriesService
    @EnvironmentObject var userProfileService: UserProfileService
    @Environment(\.modelContext) private var modelContext
    
    // UI State (only UI-related state)
    @State private var isShowingCalendar = false
    @State private var navigationPath = NavigationPath()
    @State private var isShowingProfile = false
    @State private var isShowingDailyChallengeDetail = false
    
    // ViewModels - all business logic is handled here
    @StateObject private var taskListViewModel: TaskListViewModel
    @StateObject private var challengeViewModel = DailyChallengeViewModel(
        challengeService: ServiceContainer.shared.challengeService,
        taskRepository: nil
    )
    
    init(selectedTab: Binding<Tab>) {
        self._selectedTab = selectedTab
        
        // Create temporary model context for ViewModel initialization
        // The actual modelContext from @Environment will be used via setup() method
        let schema = Schema([UserProfile.self, FirebaseChatMessage.self, DailyCompletion.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let tempModelContext = ModelContext(container)
        
        // Create ViewModel directly with default parameters
        // Repository and services will be created automatically using ServiceContainer
        self._taskListViewModel = StateObject(wrappedValue: TaskListViewModel(
            modelContext: tempModelContext
        ))
    }
    
    // Date range for calendar
    private var dateRange: (min: Date, max: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let minDate = calendar.date(byAdding: .month, value: -AppConstants.DateRange.pastMonths, to: today) ?? today
        let maxDate = calendar.date(byAdding: .month, value: AppConstants.DateRange.futureMonths, to: today) ?? today
        return (min: calendar.startOfDay(for: minDate), max: calendar.startOfDay(for: maxDate))
    }
    
    // Computed property to return tasks for selected date
    private var filteredTasks: [TaskItem] {
        taskListViewModel.filteredTasks
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    TopHeaderView(
                        isShowingCalendar: $isShowingCalendar,
                        isShowingProfile: $isShowingProfile,
                        selectedDate: taskListViewModel.selectedDate
                    )
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    
                    VStack(spacing: 16) {
                        CombinedStatsCard(tasks: filteredTasks)
                            .padding(.horizontal, 24)
                        
                        TasksHeader(
                            navigationPath: $navigationPath,
                            selectedDate: taskListViewModel.selectedDate,
                            onAITaskTap: { taskListViewModel.generateAITask() },
                            isAITaskLoading: Binding(
                                get: { taskListViewModel.isAITaskLoading },
                                set: { _ in }
                            )
                        )
                            .padding(.horizontal, 24)
                        
                        TaskListView(
                            tasks: filteredTasks,
                            selectedDate: taskListViewModel.selectedDate,
                            navigationPath: $navigationPath,
                            newlyAddedTaskId: $taskListViewModel.newlyAddedTaskId,
                            replacingAITaskIds: Binding(
                                get: { taskListViewModel.replacingAITaskIds },
                                set: { _ in }
                            ),
                            isShowingChallengeDetail: $isShowingDailyChallengeDetail,
                            onDeleteTask: { task in
                                taskListViewModel.removeTask(task)
                            },
                            onUpdateTask: { task in
                                if let oldTask = taskListViewModel.getTask(by: task.id) {
                                    taskListViewModel.updateTask(task, oldTask: oldTask)
                                }
                            }
                        )
                    }
                    .padding(.top, 12)
                    .id("content-\(taskListViewModel.selectedDate)")
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    ))
                    .animation(.easeInOut(duration: 0.3), value: taskListViewModel.selectedDate)
                    
                    // MARK: - Bottom Bar with navigation
                    BottomBar(selectedTab: $selectedTab)
                        .background(Color.white)
                }
                
                if isShowingCalendar {
                    // Dimming background that dismisses on tap
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut) { isShowingCalendar = false }
                        }
                    // Popup content centered
                    CalendarPopupView(
                        showCalendar: $isShowingCalendar,
                        selectedDate: Binding(
                            get: { taskListViewModel.selectedDate },
                            set: { newDate in
                                let calendar = Calendar.current
                                let normalizedDate = calendar.startOfDay(for: newDate)
                                // Update selectedDate (this will trigger onChange)
                                taskListViewModel.selectedDate = normalizedDate
                            }
                        ),
                        dateRange: dateRange,
                        tasksByDate: taskListViewModel.tasksByDate
                    )
                        .transition(.scale.combined(with: .opacity))
                }
                
                if isShowingProfile {
                    ProfilePageView(isPresented: $isShowingProfile)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            // Challenge detail sheet from main page
            .sheet(isPresented: $isShowingDailyChallengeDetail) {
                DailyChallengeDetailView(viewModel: challengeViewModel)
            }
            .animation(.easeInOut(duration: 0.2), value: isShowingProfile)
            .navigationDestination(for: AddTaskDestination.self) { _ in
                AddTaskView(
                    selectedDate: taskListViewModel.selectedDate,
                    newlyAddedTaskId: $taskListViewModel.newlyAddedTaskId,
                    onTaskCreated: { task in
                        taskListViewModel.addTask(task)
                        taskListViewModel.newlyAddedTaskId = task.id
                    }
                )
            }
            .navigationDestination(for: TaskDetailDestination.self) { destination in
                TaskDetailDestinationView(
                    destination: destination,
                    getTask: { id in
                        taskListViewModel.getTask(by: id)
                    },
                    onUpdateTask: { newTask, oldTask in
                        taskListViewModel.updateTask(newTask, oldTask: oldTask)
                    }
                )
            }
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        let horizontalAmount = value.translation.width
                        let verticalAmount = value.translation.height
                        
                        // Only handle horizontal swipes (ignore vertical)
                        if abs(horizontalAmount) > abs(verticalAmount) {
                            if horizontalAmount > 0 {
                                // Swipe from left to right: navigate to profile
                                withAnimation {
                                    isShowingProfile = true
                                }
                            } else if horizontalAmount < 0 {
                                // Swipe from right to left: go to insights tab
                                withAnimation {
                                    selectedTab = .insights
                                }
                            }
                        }
                    }
            )
        }
        .onAppear {
            // Setup ViewModel with correct dependencies (modelContext and dailyCaloriesService)
            taskListViewModel.setup(modelContext: modelContext, dailyCaloriesService: dailyCaloriesService)
            
            // Initialize ViewModels
            taskListViewModel.onAppear()
            challengeViewModel.onAppear()
        }
        .onDisappear {
            // Cleanup ViewModels
            taskListViewModel.onDisappear()
            challengeViewModel.onDisappear()
        }
        .onChange(of: taskListViewModel.selectedDate) { oldValue, newValue in
            // Handle date change in ViewModel
            taskListViewModel.handleDateChange()
        }
        // Refresh tasks when opening calendar
        .onChange(of: isShowingCalendar) { _, newValue in
            if newValue == true {
                // Calendar will use tasksByDate from ViewModel directly
            }
        }
    }
}

// MARK: - Navigation Destination Type
enum AddTaskDestination: Hashable {
    case addTask
}

enum TaskDetailDestination: Hashable {
    case detail(taskId: UUID)
    
    var taskId: UUID? {
        if case .detail(let id) = self { return id }
        return nil
    }
}

private enum ProfileDestination: Hashable {
    case profile
}

#Preview {
    NavigationStack {
        StatefulPreviewWrapper(Tab.todos) { selection in
            MainPageView(selectedTab: selection)
        }
    }
}
