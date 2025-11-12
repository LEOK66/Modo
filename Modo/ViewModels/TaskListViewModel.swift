import Foundation
import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseDatabase
import Combine

/// ViewModel for managing task list state and business logic
///
/// This ViewModel handles:
/// - Task loading and caching
/// - Real-time Firebase synchronization
/// - Task CRUD operations
/// - AI task generation
/// - Day completion evaluation
/// - Notification setup
final class TaskListViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Tasks stored by date (normalized to start of day)
    @Published private(set) var tasksByDate: [Date: [TaskItem]] = [:]
    
    /// Currently selected date (normalized to start of day)
    @Published var selectedDate: Date
    
    /// Loading state for tasks
    @Published private(set) var isLoading: Bool = false
    
    /// Loading state for AI task generation
    @Published private(set) var isAITaskLoading: Bool = false
    
    /// Newly added task ID (for animation)
    @Published var newlyAddedTaskId: UUID? = nil
    
    /// Recently deleted task IDs (to suppress flicker from stale cache/listener payloads)
    @Published private(set) var pendingDeletedTaskIds: Set<UUID> = []
    
    /// AI tasks being replaced (for smooth animation)
    @Published private(set) var replacingAITaskIds: Set<UUID> = []
    
    /// Current listener state
    @Published private(set) var isListenerActive: Bool = false
    
    // MARK: - Private Properties
    
    /// Task repository for data access
    private let taskRepository: TaskRepository
    
    /// Task service for business operations
    private let taskService: TaskServiceProtocol
    
    /// AI service for task generation
    private let aiService: MainPageAIService
    
    /// Notification service for handling notifications
    private let notificationService: NotificationSetupService
    
    /// Day completion service for evaluating completion
    private let dayCompletionService: DayCompletionService
    
    /// Challenge service for daily challenge management
    private let challengeService: ChallengeServiceProtocol
    
    /// Daily calories service for updating calories
    private weak var dailyCaloriesService: DailyCaloriesService?
    
    /// Model context for SwiftData operations
    private var modelContext: ModelContext
    
    /// Current Firebase listener handle
    private var currentListenerHandle: DatabaseHandle? = nil
    
    /// Current listener date
    private var currentListenerDate: Date? = nil
    
    /// Listener update task for debouncing
    private var listenerUpdateTask: Task<Void, Never>? = nil
    
    /// Notification observer
    private var notificationObserver: NSObjectProtocol? = nil
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Date range: past 12 months to future 3 months
    private var dateRange: (min: Date, max: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let minDate = calendar.date(byAdding: .month, value: -AppConstants.DateRange.pastMonths, to: today) ?? today
        let maxDate = calendar.date(byAdding: .month, value: AppConstants.DateRange.futureMonths, to: today) ?? today
        return (min: calendar.startOfDay(for: minDate), max: calendar.startOfDay(for: maxDate))
    }
    
    /// Current user ID
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Initialization
    
    /// Initialize TaskListViewModel
    /// - Parameters:
    ///   - modelContext: Model context for SwiftData (required)
    ///   - selectedDate: Initial selected date (defaults to today)
    ///   - taskRepository: Task repository (defaults to new instance with ServiceContainer dependencies)
    ///   - taskService: Task service (defaults to ServiceContainer.shared.taskService)
    ///   - aiService: AI service (defaults to new instance)
    ///   - notificationService: Notification service (defaults to new instance)
    ///   - dayCompletionService: Day completion service (defaults to new instance)
    ///   - challengeService: Challenge service (defaults to ServiceContainer.shared.challengeService)
    ///   - dailyCaloriesService: Daily calories service (optional, will be set via setup() method)
    ///   
    /// Note: If taskRepository is not provided, it will be created using:
    /// - modelContext (from parameter)
    /// - databaseService (from ServiceContainer.shared)
    init(
        modelContext: ModelContext,
        selectedDate: Date = Calendar.current.startOfDay(for: Date()),
        taskRepository: TaskRepository? = nil,
        taskService: TaskServiceProtocol? = nil,
        aiService: MainPageAIService = MainPageAIService(),
        notificationService: NotificationSetupService = NotificationSetupService(),
        dayCompletionService: DayCompletionService = DayCompletionService(),
        challengeService: ChallengeServiceProtocol? = nil,
        dailyCaloriesService: DailyCaloriesService? = nil
    ) {
        // Set model context (will be updated in setup() if needed)
        self.modelContext = modelContext
        self.selectedDate = Calendar.current.startOfDay(for: selectedDate)
        
        // Get services from ServiceContainer or use provided ones
        let databaseService = ServiceContainer.shared.databaseService
        self.taskService = taskService ?? ServiceContainer.shared.taskService
        self.aiService = aiService
        self.notificationService = notificationService
        self.dayCompletionService = dayCompletionService
        self.challengeService = challengeService ?? ServiceContainer.shared.challengeService
        self.dailyCaloriesService = dailyCaloriesService
        
        // Create task repository if not provided
        if let repository = taskRepository {
            self.taskRepository = repository
        } else {
            self.taskRepository = TaskRepository(
                modelContext: modelContext,
                databaseService: databaseService
            )
        }
    }
    
    deinit {
        stopCurrentListener()
        notificationService.removeAllObservers()
        dayCompletionService.cancelMidnightSettlement()
    }
    
    // MARK: - Computed Properties
    
    /// Get tasks for selected date (sorted by time)
    var filteredTasks: [TaskItem] {
        tasks(for: selectedDate)
    }
    
    // MARK: - Public Methods
    
    /// Setup ViewModel with runtime dependencies
    /// - Parameters:
    ///   - modelContext: Model context from SwiftUI environment
    ///   - dailyCaloriesService: Daily calories service from environment
    func setup(modelContext: ModelContext, dailyCaloriesService: DailyCaloriesService) {
        // Update model context
        self.modelContext = modelContext
        
        // Update task repository with new model context
        // Note: We need to recreate the repository with the new context
        // For now, we'll store the modelContext and use it directly
        // In a production app, we might want to refactor Repository to accept context updates
        
        // Update daily calories service
        self.dailyCaloriesService = dailyCaloriesService
    }
    
    /// Setup view when it appears
    func onAppear() {
        print("📍 TaskListViewModel: onAppear called")
        loadAllCachedTasksIntoMemory(centerDate: selectedDate)
        setupListenerIfNeeded(for: selectedDate)
        setupNotifications()
        updateCaloriesServiceIfNeeded()
        scheduleMidnightSettlement()
    }
    
    /// Cleanup when view disappears
    func onDisappear() {
        print("📍 TaskListViewModel: onDisappear called")
        stopCurrentListener()
        notificationService.removeAllObservers()
        cancelMidnightSettlement()
    }
    
    /// Handle date change
    /// This is called when selectedDate changes externally (e.g., from calendar)
    /// Note: selectedDate should already be normalized when this is called
    func handleDateChange() {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: selectedDate)
        
        print("📅 TaskListViewModel: Date changed to \(normalizedDate)")
        
        // Stop current listener and setup new one for the new date
        stopCurrentListener()
        setupListenerIfNeeded(for: normalizedDate)
        updateCaloriesServiceIfNeeded()
    }
    
    /// Load tasks for a specific date
    func loadTasks(for date: Date) {
        guard let userId = userId else {
            print("⚠️ TaskListViewModel: No user logged in, skipping load")
            return
        }
        
        isLoading = true
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        taskRepository.loadTasks(userId: userId, date: normalizedDate) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let tasks):
                    self.tasksByDate[normalizedDate] = tasks
                    print("✅ TaskListViewModel: Loaded \(tasks.count) tasks for \(date)")
                case .failure(let error):
                    print("❌ TaskListViewModel: Failed to load tasks - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Add a task
    func addTask(_ task: TaskItem) {
        guard let userId = userId else {
            print("⚠️ TaskListViewModel: No user logged in, cannot save task")
            return
        }
        
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: task.timeDate)
        
        print("📝 TaskListViewModel: Creating task - Title: \"\(task.title)\", Date: \(dateKey), Category: \(task.category), ID: \(task.id)")
        
        // Update in-memory state immediately (for UI responsiveness)
        if tasksByDate[dateKey] == nil {
            tasksByDate[dateKey] = []
        }
        tasksByDate[dateKey]?.append(task)
        
        // Update calories service and day completion
        updateCaloriesServiceIfNeeded()
        evaluateAndSyncDayCompletion(for: task.timeDate)
        
        // Save to repository (handles cache and Firebase)
        taskRepository.saveTask(userId: userId, task: task, date: task.timeDate) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                print("✅ TaskListViewModel: Task saved - Title: \"\(task.title)\", ID: \(task.id)")
            case .failure(let error):
                print("❌ TaskListViewModel: Failed to save task - Title: \"\(task.title)\", Error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Remove a task
    func removeTask(_ task: TaskItem) {
        guard let userId = userId else {
            print("⚠️ TaskListViewModel: No user logged in, cannot delete task")
            return
        }
        
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: task.timeDate)
        
        print("🗑️ TaskListViewModel: Deleting task - Title: \"\(task.title)\", Date: \(dateKey), ID: \(task.id)")
        
        // If this is the daily challenge task, clear its linkage
        if task.isDailyChallenge {
            challengeService.handleChallengeTaskDeleted(taskId: task.id)
        }
        
        // Suppress flicker from incoming stale payloads
        pendingDeletedTaskIds.insert(task.id)
        
        // Update in-memory state immediately
        if var tasks = tasksByDate[dateKey],
           let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks.remove(at: index)
            tasksByDate[dateKey] = tasks.isEmpty ? nil : tasks
        }
        
        // Update calories service and day completion
        updateCaloriesServiceIfNeeded()
        evaluateAndSyncDayCompletion(for: task.timeDate)
        
        // Delete from repository (handles cache and Firebase)
        taskRepository.deleteTask(userId: userId, taskId: task.id, date: dateKey) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Confirm deletion, stop suppressing
                self.pendingDeletedTaskIds.remove(task.id)
            }
            
            switch result {
            case .success:
                print("✅ TaskListViewModel: Task deleted - Title: \"\(task.title)\", ID: \(task.id)")
            case .failure(let error):
                print("❌ TaskListViewModel: Failed to delete task - Title: \"\(task.title)\", Error: \(error.localizedDescription)")
                // On failure, also stop suppressing so task can be restored by listener
                DispatchQueue.main.async {
                    self.pendingDeletedTaskIds.remove(task.id)
                }
            }
        }
        
        // Failsafe: clear suppression after timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.pendingDeletedTaskIds.remove(task.id)
        }
    }
    
    /// Update a task
    func updateTask(_ newTask: TaskItem, oldTask: TaskItem) {
        guard let userId = userId else {
            print("⚠️ TaskListViewModel: No user logged in, cannot update task")
            return
        }
        
        let calendar = Calendar.current
        let oldDateKey = calendar.startOfDay(for: oldTask.timeDate)
        let newDateKey = calendar.startOfDay(for: newTask.timeDate)
        
        print("🔄 TaskListViewModel: Updating task - Title: \"\(newTask.title)\", Date: \(newDateKey), ID: \(newTask.id)")
        
        // Update in-memory state immediately (optimistic update)
        updateTaskInMemory(newTask, oldTask: oldTask, oldDateKey: oldDateKey, newDateKey: newDateKey)
        
        // Notify challenge service if task completion status changed
        if oldTask.isDone != newTask.isDone {
            challengeService.updateChallengeCompletion(taskId: newTask.id, isCompleted: newTask.isDone)
        }
        
        // Update calories service and day completion
        updateCaloriesServiceIfNeeded()
        evaluateAndSyncDayCompletion(for: oldTask.timeDate)
        if oldDateKey != newDateKey {
            evaluateAndSyncDayCompletion(for: newTask.timeDate)
        }
        
        // Update in repository (handles cache and Firebase)
        taskRepository.updateTask(userId: userId, newTask: newTask, oldTask: oldTask) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                print("✅ TaskListViewModel: Task updated - Title: \"\(newTask.title)\", ID: \(newTask.id)")
            case .failure(let error):
                print("❌ TaskListViewModel: Failed to update task - Title: \"\(newTask.title)\", Error: \(error.localizedDescription)")
                // Rollback on failure
                DispatchQueue.main.async {
                    self.rollbackTaskUpdate(oldTask: oldTask, oldDateKey: oldDateKey, newDateKey: newDateKey)
                }
            }
        }
    }
    
    /// Get a task by ID
    func getTask(by id: UUID) -> TaskItem? {
        for tasks in tasksByDate.values {
            if let task = tasks.first(where: { $0.id == id }) {
                return task
            }
        }
        return nil
    }
    
    /// Generate AI tasks
    func generateAITask() {
        // Prevent duplicate clicks
        guard !isAITaskLoading else {
            print("⚠️ TaskListViewModel: AI task generation already in progress, ignoring duplicate click")
            return
        }
        
        let existingTasks = tasks(for: selectedDate)
        let existingAITasks = existingTasks.filter { $0.isAIGenerated }
        let hasAITasks = !existingAITasks.isEmpty
        let hasAnyTasks = !existingTasks.isEmpty
        
        if hasAITasks {
            // Replace mode: animate deletion of existing AI tasks, then generate all 4 tasks
            print("🔄 TaskListViewModel: Replacing existing AI tasks: \(existingAITasks.count) tasks to delete")
            
            // Mark tasks as being replaced for animation
            replacingAITaskIds = Set(existingAITasks.map { $0.id })
            
            // Wait for animation to complete, then delete and generate new ones
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                
                // Delete tasks after animation
                for aiTask in existingAITasks {
                    self.removeTask(aiTask)
                }
                // Clear replacing state
                self.replacingAITaskIds.removeAll()
                
                // Generate new tasks after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.startAITaskGeneration(replaceMode: true)
                }
            }
        } else if hasAnyTasks {
            // There are tasks but no AI tasks - analyze and generate missing ones
            print("📝 TaskListViewModel: Found existing non-AI tasks, will generate missing ones")
            startAITaskGeneration(replaceMode: false)
        } else {
            // No tasks at all - generate all 4 tasks (first time generation)
            print("✨ TaskListViewModel: First time generation: no tasks exist, generating all 4 tasks")
            startAITaskGeneration(replaceMode: true)
        }
    }
    
    /// Toggle task completion
    func toggleTaskCompletion(_ task: TaskItem) {
        var updatedTask = task
        updatedTask.isDone.toggle()
        updateTask(updatedTask, oldTask: task)
    }
    
    /// Refresh tasks for selected date
    func refreshTasks() {
        loadTasks(for: selectedDate)
    }
    
    // MARK: - Private Methods
    
    /// Get tasks for a specific date (sorted by time)
    private func tasks(for date: Date) -> [TaskItem] {
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: date)
        return tasksByDate[dateKey]?.sorted { task1, task2 in
            // Daily challenge tasks always go to the end
            if task1.isDailyChallenge && !task2.isDailyChallenge {
                return false
            } else if !task1.isDailyChallenge && task2.isDailyChallenge {
                return true
            } else {
                // Both are daily challenge or both are not, sort by time
                return task1.timeDate < task2.timeDate
            }
        } ?? []
    }
    
    /// Load all cached tasks within the current cache window into memory
    private func loadAllCachedTasksIntoMemory(centerDate: Date) {
        guard let userId = userId else { return }
        
        // Get cached tasks from repository
        let (_, cached) = taskRepository.getAllCachedTasksInWindow(centerDate: centerDate)
        
        // Merge cached tasks into in-memory map (overwrite with cache snapshot),
        // but filter out tasks recently deleted locally to avoid flicker.
        let filteredCached = cached.mapValues { tasks in
            tasks.filter { !pendingDeletedTaskIds.contains($0.id) }
        }
        
        tasksByDate = filteredCached
        print("🗂️ TaskListViewModel: Loaded \(cached.count) dates from local cache into memory")
        
        // Keep cache window tidy
        taskRepository.updateCacheWindow(userId: userId, centerDate: centerDate)
    }
    
    /// Setup Firebase listener for a specific date
    private func setupListenerIfNeeded(for date: Date) {
        guard let userId = userId else {
            print("⚠️ TaskListViewModel: No user logged in, skipping listener setup")
            return
        }
        
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Check if already listening to this date
        if let currentDate = currentListenerDate,
           calendar.isDate(currentDate, inSameDayAs: normalizedDate),
           isListenerActive {
            print("✅ TaskListViewModel: Already listening to \(normalizedDate), skipping setup")
            return
        }
        
        // Stop any existing listener first
        stopCurrentListener()
        
        // Load tasks
        loadTasks(for: normalizedDate)
        
        // Set up new listener
        print("🔌 TaskListViewModel: Setting up listener for \(normalizedDate)")
        
        let expectedDate = normalizedDate
        
        let handle = taskRepository.listenToCloudTasks(userId: userId, date: normalizedDate) { [weak self] tasks in
            guard let self = self, self.isListenerActive else {
                print("⚠️ TaskListViewModel: Ignoring listener update - listener inactive")
                return
            }
            
            // Ensure this callback corresponds to the current listener/date
            guard let currentDate = self.currentListenerDate,
                  calendar.isDate(currentDate, inSameDayAs: expectedDate) else {
                print("⚠️ TaskListViewModel: Listener callback for stale date, ignoring")
                return
            }
            
            // Debounce rapid updates
            self.listenerUpdateTask?.cancel()
            self.listenerUpdateTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms debounce
                guard !Task.isCancelled else { return }
                self.handleListenerUpdate(tasks: tasks, date: expectedDate, userId: userId)
            }
        }
        
        if let handle = handle {
            currentListenerHandle = handle
            currentListenerDate = normalizedDate
            isListenerActive = true
            print("✅ TaskListViewModel: Listener active for \(normalizedDate)")
        }
    }
    
    /// Handle listener update
    private func handleListenerUpdate(tasks: [TaskItem], date: Date, userId: String) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Compare data before updating to avoid unnecessary state changes
        let currentTasks = tasksByDate[normalizedDate] ?? []
        
        // Check if tasks actually changed
        if tasksAreEqual(currentTasks, tasks) {
            print("ℹ️ TaskListViewModel: Tasks unchanged for \(normalizedDate), skipping update")
            return
        }
        
        print("🔄 TaskListViewModel: Real-time update received for \(date) - \(tasks.count) tasks")
        
        // Filter out any tasks that are in local pending-deletion to avoid flicker
        let filteredTasks = tasks.filter { !pendingDeletedTaskIds.contains($0.id) }
        
        // Update cache in background
        Task.detached(priority: .background) { [weak self] in
            self?.taskRepository.saveCachedTasks(userId: userId, date: normalizedDate, tasks: filteredTasks)
        }
        
        // Update in-memory state on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.tasksByDate[normalizedDate] = filteredTasks
            self.updateCaloriesServiceIfNeeded()
            self.evaluateAndSyncDayCompletion(for: normalizedDate)
        }
    }
    
    /// Check if two task arrays are equal
    private func tasksAreEqual(_ tasks1: [TaskItem], _ tasks2: [TaskItem]) -> Bool {
        guard tasks1.count == tasks2.count else { return false }
        
        // Create dictionaries for efficient comparison
        let dict1 = Dictionary(uniqueKeysWithValues: tasks1.map { ($0.id, $0) })
        let dict2 = Dictionary(uniqueKeysWithValues: tasks2.map { ($0.id, $0) })
        
        // Check if all tasks are equal
        for (id, task1) in dict1 {
            guard let task2 = dict2[id] else { return false }
            
            // Compare key properties
            if task1.title != task2.title ||
               task1.subtitle != task2.subtitle ||
               task1.isDone != task2.isDone ||
               task1.timeDate != task2.timeDate ||
               task1.meta != task2.meta {
                return false
            }
        }
        
        return true
    }
    
    /// Stop current Firebase listener
    private func stopCurrentListener() {
        // Cancel any pending updates
        listenerUpdateTask?.cancel()
        listenerUpdateTask = nil
        
        // Stop Firebase listener
        if let handle = currentListenerHandle {
            taskRepository.stopListening(handle: handle)
            print("🛑 TaskListViewModel: Stopped listener for \(currentListenerDate?.description ?? "unknown")")
        }
        
        // Clear state
        currentListenerHandle = nil
        currentListenerDate = nil
        isListenerActive = false
    }
    
    /// Update task in memory
    private func updateTaskInMemory(_ newTask: TaskItem, oldTask: TaskItem, oldDateKey: Date, newDateKey: Date) {
        if oldDateKey == newDateKey {
            // Same date: replace in place
            if var tasks = tasksByDate[oldDateKey],
               let index = tasks.firstIndex(where: { $0.id == oldTask.id }) {
                tasks[index] = newTask
                tasksByDate[oldDateKey] = tasks
            }
        } else {
            // Different date: remove from old, add to new
            if var oldTasks = tasksByDate[oldDateKey],
               let index = oldTasks.firstIndex(where: { $0.id == oldTask.id }) {
                oldTasks.remove(at: index)
                tasksByDate[oldDateKey] = oldTasks.isEmpty ? nil : oldTasks
            }
            
            var newTasks = tasksByDate[newDateKey] ?? []
            newTasks.append(newTask)
            tasksByDate[newDateKey] = newTasks
        }
    }
    
    /// Rollback task update
    private func rollbackTaskUpdate(oldTask: TaskItem, oldDateKey: Date, newDateKey: Date) {
        print("🔄 TaskListViewModel: Rolling back failed update")
        updateTaskInMemory(oldTask, oldTask: oldTask, oldDateKey: newDateKey, newDateKey: oldDateKey)
    }
    
    /// Start AI task generation
    private func startAITaskGeneration(replaceMode: Bool = false) {
        // Prevent duplicate calls
        guard !isAITaskLoading else { return }
        
        isAITaskLoading = true
        
        // Get current user profile
        let userProfile: UserProfile? = {
            let fetchDescriptor = FetchDescriptor<UserProfile>()
            return try? modelContext.fetch(fetchDescriptor).first
        }()
        
        // Use AI service to generate tasks
        let existingTasks = tasks(for: selectedDate)
        let replacingIds = aiService.generateAITasks(
            existingTasks: existingTasks,
            selectedDate: selectedDate,
            userProfile: userProfile,
            replaceMode: replaceMode,
            onEachTask: { [weak self] task in
                guard let self = self else { return }
                // Add task to list
                self.addTask(task)
                // Trigger animation for newly added task
                self.newlyAddedTaskId = task.id
                print("🎉 TaskListViewModel: AI Task added successfully!")
            },
            onComplete: { [weak self] in
                guard let self = self else { return }
                self.isAITaskLoading = false
            }
        )
        
        // Update replacing IDs if any
        if !replacingIds.isEmpty {
            replacingAITaskIds = replacingIds
        }
    }
    
    /// Setup notifications
    private func setupNotifications() {
        notificationService.setupDailyChallengeNotification { [weak self] task in
            self?.addTask(task)
        }
        
        notificationService.setupWorkoutTaskNotification { [weak self] task in
            self?.addTask(task)
        }
    }
    
    /// Update calories service if needed
    private func updateCaloriesServiceIfNeeded() {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: selectedDate)
        let today = calendar.startOfDay(for: Date())
        
        // Only calculate if it's today
        guard calendar.isDate(normalizedDate, inSameDayAs: today) else {
            return
        }
        
        // Calculate total calories from completed tasks
        let tasks = tasks(for: selectedDate)
        let total = tasks
            .filter { $0.isDone }
            .reduce(0) { $0 + $1.totalCalories }
        
        // Update calories service
        dailyCaloriesService?.updateCalories(total, for: normalizedDate)
    }
    
    /// Evaluate and sync day completion
    private func evaluateAndSyncDayCompletion(for date: Date) {
        guard let userId = userId else { return }
        let dayTasks = tasks(for: date)
        dayCompletionService.evaluateAndSyncDayCompletion(
            for: date,
            tasks: dayTasks,
            userId: userId,
            modelContext: modelContext
        )
    }
    
    /// Schedule midnight settlement
    private func scheduleMidnightSettlement() {
        dayCompletionService.scheduleMidnightSettlement { [weak self] date in
            guard let self = self, let userId = self.userId else { return }
            let dayTasks = self.tasks(for: date)
            self.dayCompletionService.evaluateAndSyncDayCompletion(
                for: date,
                tasks: dayTasks,
                userId: userId,
                modelContext: self.modelContext
            )
        }
    }
    
    /// Cancel midnight settlement
    private func cancelMidnightSettlement() {
        dayCompletionService.cancelMidnightSettlement()
    }
}

