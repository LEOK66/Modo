import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseDatabase

struct MainPageView: View {
    @Binding var selectedTab: Tab
    @EnvironmentObject var dailyCaloriesService: DailyCaloriesService
    @EnvironmentObject var userProfileService: UserProfileService
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingCalendar = false
    @State private var navigationPath = NavigationPath()
    @State private var isShowingProfile = false
    @State private var isShowingDailyChallengeDetail = false
    @StateObject private var challengeService = DailyChallengeService.shared
    
    // Services
    private let cacheService = TaskCacheService.shared
    private let databaseService = DatabaseService.shared
    private let taskManagerService = TaskManagerService()
    private let aiService = MainPageAIService()
    private let notificationService = NotificationSetupService()
    private let dayCompletionService = DayCompletionService()
    
    // Track current listener handle
    @State private var currentListenerHandle: DatabaseHandle? = nil
    @State private var currentListenerDate: Date? = nil
    @State private var isListenerActive = false
    @State private var listenerUpdateTask: Task<Void, Never>? = nil
    
    // Tasks stored by date (normalized to start of day)
    @State private var tasksByDate: [Date: [TaskItem]] = [:]
    
    // AI Task Generation
    @State private var isAITaskLoading = false
    
    // Currently selected date (normalized to start of day)
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    
    // Track newly added task for animation
    @State private var newlyAddedTaskId: UUID? = nil
    // CRITICAL FIX #3: Track if view is actually visible
    @State private var isViewVisible = false
    // Track notification observer to prevent duplicates
    @State private var notificationObserver: NSObjectProtocol? = nil
    // Track recently deleted task IDs to suppress flicker from stale cache/listener payloads
    @State private var pendingDeletedTaskIds: Set<UUID> = []
    // Track AI tasks being replaced for smooth animation
    @State private var replacingAITaskIds: Set<UUID> = []
    
    // Date range: past 12 months to future 3 months
    private var dateRange: (min: Date, max: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let minDate = calendar.date(byAdding: .month, value: -AppConstants.DateRange.pastMonths, to: today) ?? today
        let maxDate = calendar.date(byAdding: .month, value: AppConstants.DateRange.futureMonths, to: today) ?? today
        return (min: calendar.startOfDay(for: minDate), max: calendar.startOfDay(for: maxDate))
    }
    
    // Computed property to return tasks for selected date, sorted by time
    private var filteredTasks: [TaskItem] {
        tasks(for: selectedDate)
    }
    
    // MARK: - AI Task Generation
    
    /// Generate AI Tasks based on what's missing for the day
    private func generateAITask() {
        // Prevent duplicate clicks: if already generating, ignore
        if isAITaskLoading {
            print("⚠️ AI task generation already in progress, ignoring duplicate click")
            return
        }
        
        // Get existing tasks for the selected date
        let existingTasks = tasks(for: selectedDate)
        let existingAITasks = existingTasks.filter { $0.isAIGenerated }
        let hasAITasks = !existingAITasks.isEmpty
        let hasAnyTasks = !existingTasks.isEmpty
        
        if hasAITasks {
            // Replace mode: animate deletion of existing AI tasks, then generate all 4 tasks
            print("🔄 Replacing existing AI tasks: \(existingAITasks.count) tasks to delete")
            
            // Mark tasks as being replaced for animation
            replacingAITaskIds = Set(existingAITasks.map { $0.id })
            
            // Animate fade out with scale
            withAnimation(.easeInOut(duration: 0.4)) {
                // Animation will be handled by TaskListView
            }
            
            // Wait for animation to complete, then delete and generate new ones
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
            print("📝 Found existing non-AI tasks, will generate missing ones")
            startAITaskGeneration(replaceMode: false)
        } else {
            // No tasks at all - generate all 4 tasks (first time generation)
            print("✨ First time generation: no tasks exist, generating all 4 tasks")
            startAITaskGeneration(replaceMode: true)
        }
    }
    
    private func startAITaskGeneration(replaceMode: Bool = false) {
        // Prevent duplicate calls
        if isAITaskLoading {
            return
        }
        
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
            onEachTask: { task in
                // Add task to list
                self.addTask(task)
                // Trigger animation for newly added task
                self.newlyAddedTaskId = task.id
                print("🎉 AI Task added successfully!")
            },
            onComplete: {
                self.isAITaskLoading = false
            }
        )
        
        // Update replacing IDs if any
        if !replacingIds.isEmpty {
            replacingAITaskIds = replacingIds
        }
    }
    
    // MARK: - Notification Handling
    
    /// Setup notification observers
    private func setupNotifications() {
        notificationService.setupDailyChallengeNotification { task in
            // Delivered on main queue by NotificationSetupService
            self.addTask(task)
        }
        
        notificationService.setupWorkoutTaskNotification { task in
            // Delivered on main queue by NotificationSetupService
            self.addTask(task)
        }
    }
    
    /// Update DailyCaloriesService with today's calories (called asynchronously)
    private func updateCaloriesServiceIfNeeded(tasks: [TaskItem], date: Date) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        
        // Only calculate if it's today
        guard calendar.isDate(normalizedDate, inSameDayAs: today) else {
            return
        }
        
        // Calculate total calories from completed tasks
        // Diet tasks add calories, fitness tasks subtract calories
        let total = tasks
            .filter { $0.isDone }
            .reduce(0) { $0 + $1.totalCalories }
        
        // Update calories service (already handles async internally)
        dailyCaloriesService.updateCalories(total, for: normalizedDate)
    }
    
    // MARK: - Task Management Methods
    
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
    
    /// Load tasks if needed (check cache window, load from Firebase if outside window)
    private func loadTasksIfNeeded(for date: Date) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ MainPageView: No user logged in, skipping load")
            return
        }
        
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Check if date is in cache window
        let (window, _) = cacheService.getCurrentCacheWindow(centerDate: normalizedDate)
        
        if cacheService.isDateInCacheWindow(normalizedDate, windowMin: window.minDate, windowMax: window.maxDate) {
            // Date is in cache window, load from cache
            let tasks = cacheService.getTasks(for: normalizedDate, userId: userId)
            
            // Update in-memory state
            DispatchQueue.main.async {
                self.tasksByDate[normalizedDate] = tasks
            }
            
            print("✅ MainPageView: Loaded tasks from cache for \(date)")
        } else {
            // Date is outside cache window, load from Firebase and update cache window
            print("📡 MainPageView: Date outside cache window, loading from Firebase")
            
            // Update cache window first
            cacheService.updateCacheWindow(centerDate: normalizedDate, for: userId)
            
            // Load from Firebase
            databaseService.fetchTasksForDate(userId: userId, date: normalizedDate) { result in
                switch result {
                case .success(let tasks):
                    // Update cache (batch save - more efficient)
                    self.cacheService.saveTasksForDate(tasks, date: normalizedDate, userId: userId)
                    
                    // Update in-memory state
                    DispatchQueue.main.async {
                        self.tasksByDate[normalizedDate] = tasks
                    }
                    
                    print("✅ MainPageView: Loaded \(tasks.count) tasks from Firebase for \(date)")
                case .failure(let error):
                    print("❌ MainPageView: Failed to load tasks from Firebase - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Load all cached tasks within the current cache window into memory
    private func loadAllCachedTasksIntoMemory(centerDate: Date) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let (_, cached) = cacheService.getCurrentCacheWindow(centerDate: centerDate)
        // Merge cached tasks into in-memory map (overwrite with cache snapshot),
        // but filter out tasks recently deleted locally to avoid flicker.
        let filteredCached = cached.mapValues { tasks in
            tasks.filter { !pendingDeletedTaskIds.contains($0.id) }
        }
        DispatchQueue.main.async {
            self.tasksByDate = filteredCached
        }
        print("🗂️ MainPageView: Loaded \(cached.count) dates from local cache into memory")
        // Keep cache window tidy
        cacheService.updateCacheWindow(centerDate: centerDate, for: userId)
    }
    
    /// Add a task to the Map structure and save to cache + Firebase
    private func addTask(_ task: TaskItem) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ MainPageView: No user logged in, cannot save task")
            return
        }
        
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: task.timeDate)
        
        print("📝 MainPageView: Creating task - Title: \"\(task.title)\", Date: \(dateKey), Category: \(task.category), ID: \(task.id)")
        
        // Update in-memory state immediately (for UI responsiveness)
        if tasksByDate[dateKey] == nil {
            tasksByDate[dateKey] = []
        }
        tasksByDate[dateKey]?.append(task)
        
        // Update calories service after task added
        let todayTasks = tasks(for: selectedDate)
        updateCaloriesServiceIfNeeded(tasks: todayTasks, date: selectedDate)
        // Evaluate day completion for the task's date
        evaluateAndSyncDayCompletion(for: task.timeDate)
        
        // Update cache immediately
        cacheService.saveTask(task, date: task.timeDate, userId: userId)
        print("✅ MainPageView: Task saved to local cache")
        
        // Save to Firebase (background sync)
        databaseService.saveTask(userId: userId, task: task, date: task.timeDate) { result in
            switch result {
            case .success:
                print("✅ MainPageView: Task saved to Firebase - Title: \"\(task.title)\", ID: \(task.id)")
            case .failure(let error):
                print("❌ MainPageView: Failed to save task to Firebase - Title: \"\(task.title)\", Error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Remove a task from the Map structure and delete from cache + Firebase
    private func removeTask(_ task: TaskItem) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ MainPageView: No user logged in, cannot delete task")
            return
        }
        
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: task.timeDate)
        
        print("🗑️ MainPageView: Deleting task - Title: \"\(task.title)\", Date: \(dateKey), ID: \(task.id)")
        
        // If this is the daily challenge task, clear its linkage in the service
        if task.isDailyChallenge {
            DailyChallengeService.shared.handleChallengeTaskDeleted(taskId: task.id)
        }
        // Suppress flicker from incoming stale payloads
        pendingDeletedTaskIds.insert(task.id)
        
        // Update in-memory state immediately (for UI responsiveness)
        for (key, tasks) in tasksByDate {
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasksByDate[key]?.remove(at: index)
                // Remove empty arrays
                if tasksByDate[key]?.isEmpty == true {
                    tasksByDate.removeValue(forKey: key)
                }
                
                // Update calories service after task removed
                let todayTasks = self.tasks(for: self.selectedDate)
                self.updateCaloriesServiceIfNeeded(tasks: todayTasks, date: self.selectedDate)
                // Evaluate day completion for the removed task's date
                self.evaluateAndSyncDayCompletion(for: task.timeDate)
                
                // Update cache immediately
                cacheService.deleteTask(taskId: task.id, date: dateKey, userId: userId)
                print("✅ MainPageView: Task deleted from local cache")
                
                // Delete from Firebase (background sync)
                databaseService.deleteTask(userId: userId, taskId: task.id, date: dateKey) { result in
                    switch result {
                    case .success:
                        print("✅ MainPageView: Task deleted from Firebase - Title: \"\(task.title)\", ID: \(task.id)")
                        // Confirm deletion, stop suppressing
                        DispatchQueue.main.async {
                            self.pendingDeletedTaskIds.remove(task.id)
                        }
                    case .failure(let error):
                        print("❌ MainPageView: Failed to delete task from Firebase - Title: \"\(task.title)\", Error: \(error.localizedDescription)")
                        // On failure, also stop suppressing so task can be restored by listener
                        DispatchQueue.main.async {
                            self.pendingDeletedTaskIds.remove(task.id)
                        }
                    }
                }
                // Failsafe: clear suppression after timeout to avoid stuck state if callback never arrives
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    self.pendingDeletedTaskIds.remove(task.id)
                }
                
                return
            }
        }
    }
    
    /// Update a task (handles date changes) and save to cache + Firebase
    private func updateTask(_ newTask: TaskItem, oldTask: TaskItem) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ MainPageView: No user logged in, cannot update task")
            return
        }
        
        let calendar = Calendar.current
        let oldDateKey = calendar.startOfDay(for: oldTask.timeDate)
        let newDateKey = calendar.startOfDay(for: newTask.timeDate)
        
        let dateChanged = oldDateKey != newDateKey
        
        print("🔄 MainPageView: Updating task - Title: \"\(newTask.title)\", Date: \(newDateKey), ID: \(newTask.id)")
        
        // CRITICAL FIX #9: Optimistic update - update UI immediately
        updateTaskInMemory(newTask, oldTask: oldTask, oldDateKey: oldDateKey, newDateKey: newDateKey)
        
        // Notify DailyChallengeService to update challenge completion status (if task status changed)
        if oldTask.isDone != newTask.isDone {
            DailyChallengeService.shared.updateChallengeCompletion(taskId: newTask.id, isCompleted: newTask.isDone)
        }
        
        // Update calories service after task update
        let todayTasks = tasks(for: selectedDate)
        updateCaloriesServiceIfNeeded(tasks: todayTasks, date: selectedDate)
        // Evaluate day completion for affected dates
        evaluateAndSyncDayCompletion(for: oldTask.timeDate)
        evaluateAndSyncDayCompletion(for: newTask.timeDate)
        
        // CRITICAL FIX #10: Update cache in background
        Task.detached(priority: .background) {
            if oldDateKey == newDateKey {
                self.cacheService.updateTask(newTask, oldDate: oldDateKey, userId: userId)
            } else {
                self.cacheService.deleteTask(taskId: oldTask.id, date: oldDateKey, userId: userId)
                self.cacheService.saveTask(newTask, date: newDateKey, userId: userId)
            }
        }
        
        // CRITICAL FIX #11: Firebase update - use completion handler to track success
        databaseService.saveTask(userId: userId, task: newTask, date: newDateKey) { result in
            switch result {
            case .success:
                print("✅ MainPageView: Task updated in Firebase - Title: \"\(newTask.title)\", ID: \(newTask.id)")
            case .failure(let error):
                print("❌ MainPageView: Failed to update task in Firebase - Title: \"\(newTask.title)\", Error: \(error.localizedDescription)")
                
                // CRITICAL FIX #12: Rollback on failure
                DispatchQueue.main.async {
                    self.rollbackTaskUpdate(oldTask: oldTask, oldDateKey: oldDateKey, newDateKey: newDateKey)
                }
            }
        }
        
        // If date changed, delete old task from Firebase
        if dateChanged {
            databaseService.deleteTask(userId: userId, taskId: oldTask.id, date: oldDateKey) { result in
                switch result {
                case .success:
                    print("✅ MainPageView: Old task deleted from Firebase (date changed)")
                case .failure(let error):
                    print("❌ MainPageView: Failed to delete old task from Firebase - Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
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
    
    private func rollbackTaskUpdate(oldTask: TaskItem, oldDateKey: Date, newDateKey: Date) {
        print("🔄 MainPageView: Rolling back failed update")
        updateTaskInMemory(oldTask, oldTask: oldTask, oldDateKey: newDateKey, newDateKey: oldDateKey)
    }
    
    /// Get a task by its ID
    private func getTask(by id: UUID) -> TaskItem? {
        for tasks in tasksByDate.values {
            if let task = tasks.first(where: { $0.id == id }) {
                return task
            }
        }
        return nil
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    TopHeaderView(
                        isShowingCalendar: $isShowingCalendar,
                        isShowingProfile: $isShowingProfile,
                        selectedDate: selectedDate
                    )
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    
                    VStack(spacing: 16) {
                        CombinedStatsCard(tasks: filteredTasks)
                            .padding(.horizontal, 24)
                        
                        TasksHeader(
                            navigationPath: $navigationPath,
                            selectedDate: selectedDate,
                            onAITaskTap: { generateAITask() },
                            isAITaskLoading: $isAITaskLoading
                        )
                            .padding(.horizontal, 24)
                        
                        TaskListView(
                            tasks: filteredTasks,
                            selectedDate: selectedDate,
                            navigationPath: $navigationPath,
                            newlyAddedTaskId: $newlyAddedTaskId,
                            replacingAITaskIds: $replacingAITaskIds,
                            isShowingChallengeDetail: $isShowingDailyChallengeDetail,
                            onDeleteTask: { task in
                                removeTask(task)
                            },
                            onUpdateTask: { task in
                                if let oldTask = getTask(by: task.id) {
                                    updateTask(task, oldTask: oldTask)
                                }
                            }
                        )
                    }
                    .padding(.top, 12)
                    .id("content-\(selectedDate)")
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    ))
                    .animation(.easeInOut(duration: 0.3), value: selectedDate)
                    
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
                        selectedDate: $selectedDate,
                        dateRange: dateRange,
                        tasksByDate: tasksByDate
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
                DailyChallengeDetailView(
                    challenge: challengeService.currentChallenge,
                    isCompleted: challengeService.isChallengeCompleted,
                    isAddedToTasks: challengeService.isChallengeAddedToTasks,
                    onAddToTasks: {
                        guard let challenge = challengeService.currentChallenge else { return }
                        // Reuse same notification flow used in ProfilePageView
                        challengeService.addChallengeToTasks { taskId in
                            guard let taskId = taskId else { return }
                            let userInfo: [String: Any] = [
                                "taskId": taskId.uuidString,
                                "title": challenge.title,
                                "subtitle": challenge.subtitle,
                                "emoji": challenge.emoji,
                                "category": "fitness",
                                "type": challenge.type.rawValue,
                                "targetValue": challenge.targetValue
                            ]
                            NotificationCenter.default.post(
                                name: NSNotification.Name("AddDailyChallengeTask"),
                                object: nil,
                                userInfo: userInfo
                            )
                            isShowingDailyChallengeDetail = false
                        }
                    }
                )
            }
            .animation(.easeInOut(duration: 0.2), value: isShowingProfile)
            .navigationDestination(for: AddTaskDestination.self) { _ in
                AddTaskView(
                    selectedDate: selectedDate,
                    newlyAddedTaskId: $newlyAddedTaskId,
                    onTaskCreated: { task in
                        addTask(task)
                        newlyAddedTaskId = task.id
                    }
                )
            }
            .navigationDestination(for: TaskDetailDestination.self) { destination in
                TaskDetailDestinationView(
                    destination: destination,
                    getTask: { id in
                        getTask(by: id)
                    },
                    onUpdateTask: { newTask, oldTask in
                        updateTask(newTask, oldTask: oldTask)
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
            print("📍 MainPageView: onAppear called")
            isViewVisible = true
            // Load cached tasks for current user into memory so calendar dots persist
            loadAllCachedTasksIntoMemory(centerDate: selectedDate)
            setupListenerIfNeeded(for: selectedDate)
            setupNotifications()
            // Update calories service on appear
            let todayTasks = tasks(for: selectedDate)
            updateCaloriesServiceIfNeeded(tasks: todayTasks, date: selectedDate)
            // Schedule settlement at next midnight
            scheduleMidnightSettlement()
        }
        .onDisappear {
            print("📍 MainPageView: onDisappear called")
            isViewVisible = false
            stopCurrentListener()
            notificationService.removeAllObservers()
            cancelMidnightSettlement()
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            print("📅 MainPageView: Date changed from \(oldValue) to \(newValue)")
            guard isViewVisible else {
                print("⚠️ MainPageView: View not visible, skipping listener update")
                return
            }
            stopCurrentListener()
            setupListenerIfNeeded(for: newValue)
            // Update calories service when date changes
            let todayTasks = tasks(for: newValue)
            updateCaloriesServiceIfNeeded(tasks: todayTasks, date: newValue)
        }
        // Refresh in-memory tasks from cache when opening the calendar so day dots show up
        .onChange(of: isShowingCalendar) { _, newValue in
            if newValue == true {
                loadAllCachedTasksIntoMemory(centerDate: selectedDate)
            }
        }
    }
    
    private func setupListenerIfNeeded(for date: Date) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // CRITICAL FIX #4: Check if already listening to this date
        if let currentDate = currentListenerDate,
           calendar.isDate(currentDate, inSameDayAs: normalizedDate),
           isListenerActive {
            print("✅ MainPageView: Already listening to \(normalizedDate), skipping setup")
            return
        }
        
        // Stop any existing listener first
        stopCurrentListener()
        
        // Load tasks
        loadTasksIfNeeded(for: normalizedDate)
        
        // Set up new listener
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ MainPageView: No user logged in, skipping listener setup")
            return
        }
        
        print("🔌 MainPageView: Setting up listener for \(normalizedDate)")
        
        // Capture the expected date to validate callbacks
        let expectedDate = normalizedDate
        
        let handle = databaseService.listenToTasks(userId: userId, date: normalizedDate) { tasks in
            // CRITICAL FIX #5: Only process updates if view is visible and listener is active
            guard self.isViewVisible, self.isListenerActive else {
                print("⚠️ MainPageView: Ignoring listener update - view not visible or listener inactive")
                return
            }
            // Ensure this callback corresponds to the current listener/date
            let cal = Calendar.current
            guard let currentDate = self.currentListenerDate,
                  cal.isDate(currentDate, inSameDayAs: expectedDate) else {
                print("⚠️ MainPageView: Listener callback for stale date, ignoring")
                return
            }
            
            // CRITICAL FIX #6: Debounce rapid updates
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
            print("✅ MainPageView: Listener active for \(normalizedDate)")
        }
    }
    
    private func handleListenerUpdate(tasks: [TaskItem], date: Date, userId: String) {
           let calendar = Calendar.current
           let normalizedDate = calendar.startOfDay(for: date)
           
           // CRITICAL FIX #7: Compare data before updating to avoid unnecessary state changes
           let currentTasks = tasksByDate[normalizedDate] ?? []
           
           // Check if tasks actually changed
           if tasksAreEqual(currentTasks, tasks) {
               print("ℹ️ MainPageView: Tasks unchanged for \(normalizedDate), skipping update")
               return
           }
           
           print("🔄 MainPageView: Real-time update received for \(date) - \(tasks.count) tasks")
           
           // Filter out any tasks that are in local pending-deletion to avoid flicker
           let filteredTasks = tasks.filter { !pendingDeletedTaskIds.contains($0.id) }

           // CRITICAL FIX #8: Update cache without triggering additional Firebase operations
           // Use a flag or separate method that doesn't trigger listeners
           Task.detached(priority: .background) {
               self.cacheService.saveTasksForDate(filteredTasks, date: normalizedDate, userId: userId)
           }
           
           // Update in-memory state on main thread
           DispatchQueue.main.async {
               self.tasksByDate[normalizedDate] = filteredTasks
               // Update calories service after listener update
               let todayTasks = self.tasks(for: normalizedDate)
               self.updateCaloriesServiceIfNeeded(tasks: todayTasks, date: normalizedDate)
                // Evaluate day completion based on latest listener update
                self.evaluateAndSyncDayCompletion(for: normalizedDate)
           }
       }
    
    private func tasksAreEqual(_ tasks1: [TaskItem], _ tasks2: [TaskItem]) -> Bool {
        guard tasks1.count == tasks2.count else { return false }
        
        // Create dictionaries for efficient comparison
        let dict1 = Dictionary(uniqueKeysWithValues: tasks1.map { ($0.id, $0) })
        let dict2 = Dictionary(uniqueKeysWithValues: tasks2.map { ($0.id, $0) })
        
        // Check if all tasks are equal
        for (id, task1) in dict1 {
            guard let task2 = dict2[id] else { return false }
            
            // Compare key properties (add more if needed)
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
    
    
    // MARK: - Firebase Integration Methods
    
    
    /// Stop current real-time listener
    private func stopCurrentListener() {
        // Cancel any pending updates
        listenerUpdateTask?.cancel()
        listenerUpdateTask = nil
        
        // Stop Firebase listener
        if let handle = currentListenerHandle {
            databaseService.stopListening(handle: handle)
            print("🛑 MainPageView: Stopped listener for \(currentListenerDate?.description ?? "unknown")")
        }
        
        // Clear state
        currentListenerHandle = nil
        currentListenerDate = nil
        isListenerActive = false
    }

    /// Evaluate whether all tasks for a date are completed and sync status
    private func evaluateAndSyncDayCompletion(for date: Date) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let dayTasks = tasks(for: date)
        dayCompletionService.evaluateAndSyncDayCompletion(
            for: date,
            tasks: dayTasks,
            userId: userId,
            modelContext: modelContext
        )
    }

    /// Schedule a one-shot timer to settle today's completion at the next midnight
    private func scheduleMidnightSettlement() {
        dayCompletionService.scheduleMidnightSettlement { date in
            guard let userId = Auth.auth().currentUser?.uid else { return }
            let dayTasks = self.tasks(for: date)
            self.dayCompletionService.evaluateAndSyncDayCompletion(
                for: date,
                tasks: dayTasks,
                userId: userId,
                modelContext: self.modelContext
            )
        }
    }

    /// Cancel any scheduled midnight settlement timer
    private func cancelMidnightSettlement() {
        dayCompletionService.cancelMidnightSettlement()
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

// MARK: - Extracted Components
// TopHeaderView, CombinedStatsCard, TasksHeader, TaskRowCard, TaskListView, and TaskDetailDestinationView
// have been moved to separate files for better code organization.

#Preview {
    NavigationStack {
        StatefulPreviewWrapper(Tab.todos) { selection in
            MainPageView(selectedTab: selection)
        }
    }
}
