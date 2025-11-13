import Foundation
import SwiftUI
import SwiftData
import Combine
import FirebaseAuth

/// ViewModel for managing task detail state and business logic
///
/// This ViewModel handles:
/// - Task loading
/// - Task editing
/// - Task deletion
/// - Task completion toggling
/// - Form state management
/// - Calories calculation
final class DetailTaskViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Current task
    @Published private(set) var task: TaskItem?
    
    /// Original task (for rollback)
    @Published private(set) var originalTask: TaskItem?
    
    /// Whether task is being edited
    @Published var isEditing: Bool = false
    
    /// Loading state
    @Published private(set) var isLoading: Bool = false
    
    /// Whether task is being saved
    @Published private(set) var isSaving: Bool = false
    
    /// Whether task is being deleted
    @Published private(set) var isDeleting: Bool = false
    
    /// Error message
    @Published var errorMessage: String? = nil
    
    // MARK: - Form State (Editing)
    
    /// Task title text
    @Published var titleText: String = ""
    
    /// Task description text
    @Published var descriptionText: String = ""
    
    /// Task time date (for time picker)
    @Published var timeDate: Date = Date()
    
    /// Selected category
    @Published var selectedCategory: TaskCategory? = nil
    
    /// Diet entries
    @Published var dietEntries: [DietEntry] = []
    
    /// Fitness entries
    @Published var fitnessEntries: [FitnessEntry] = []
    
    /// Duration hours (for fitness)
    @Published var durationHoursInt: Int = 0
    
    /// Duration minutes (for fitness)
    @Published var durationMinutesInt: Int = 0
    
    /// Currently editing diet entry index
    @Published var editingDietEntryIndex: Int? = nil
    
    /// Currently editing fitness entry index
    @Published var editingFitnessEntryIndex: Int? = nil
    
    // MARK: - Published Properties - UI State
    
    /// Whether time sheet is presented
    @Published var isTimeSheetPresented: Bool = false
    
    /// Whether duration sheet is presented
    @Published var isDurationSheetPresented: Bool = false
    
    /// Whether quick pick sheet is presented
    @Published var isQuickPickPresented: Bool = false
    
    /// Quick pick mode
    @Published var quickPickMode: QuickPickSheetView.QuickPickMode? = nil
    
    /// Quick pick search text
    @Published var quickPickSearch: String = ""
    
    /// Recent foods (in-memory per session)
    @Published var recentFoods: [MenuData.FoodItem] = []
    
    /// Recent exercises (in-memory per session)
    @Published var recentExercises: [MenuData.ExerciseItem] = []
    
    /// Online foods
    @Published var onlineFoods: [MenuData.FoodItem] = []
    
    /// Whether online loading
    @Published var isOnlineLoading: Bool = false
    
    /// Pending scroll ID
    @Published var pendingScrollId: String? = nil
    
    // MARK: - Private Properties
    
    /// Task repository for data access
    private let taskRepository: TaskRepository
    
    /// Task edit helper for editing operations
    private let taskEditHelper: TaskEditHelper
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Current user ID
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Initialization
    
    /// Initialize DetailTaskViewModel
    /// - Parameters:
    ///   - task: Initial task (optional, can be loaded later)
    ///   - modelContext: Model context for SwiftData (required for repository)
    ///   - taskRepository: Task repository (defaults to new instance with ServiceContainer dependencies)
    ///   - taskEditHelper: Task edit helper (defaults to new instance)
    ///   
    /// Note: If taskRepository is not provided, it will be created using:
    /// - modelContext (from parameter)
    /// - databaseService (from ServiceContainer.shared)
    init(
        task: TaskItem? = nil,
        modelContext: ModelContext,
        taskRepository: TaskRepository? = nil,
        taskEditHelper: TaskEditHelper = TaskEditHelper()
    ) {
        self.task = task
        self.originalTask = task
        self.taskEditHelper = taskEditHelper
        
        // Create task repository if not provided
        if let repository = taskRepository {
            self.taskRepository = repository
        } else {
            let databaseService = ServiceContainer.shared.databaseService
            self.taskRepository = TaskRepository(
                modelContext: modelContext,
                databaseService: databaseService
            )
        }
        
        // Load task data if task is provided
        if let task = task {
            loadTaskData(from: task)
        }
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Load task by ID (placeholder - task is passed from parent)
    /// - Parameter taskId: Task ID to load
    func loadTask(id: UUID) {
        // Task is loaded from parent view via getTask callback
        // This method is kept for compatibility
        isLoading = false
    }
    
    /// Load task data into form fields
    /// - Parameter task: Task to load
    func loadTaskData(from task: TaskItem) {
        self.task = task
        self.originalTask = task
        
        titleText = task.title
        descriptionText = task.subtitle
        selectedCategory = task.category
        
        // Extract time from task.timeDate for time picker
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: task.timeDate)
        if let hour = timeComponents.hour, let minute = timeComponents.minute {
            // Create a Date with today's date and the task's time
            let today = Date()
            timeDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
        } else {
            timeDate = Date()
        }
        
        // Create deep copies to avoid mutating the original task
        dietEntries = task.dietEntries.map { entry in
            DietEntry(
                food: entry.food,
                customName: entry.customName,
                quantityText: entry.quantityText,
                unit: entry.unit,
                caloriesText: entry.caloriesText
            )
        }
        
        fitnessEntries = task.fitnessEntries.map { entry in
            var newEntry = FitnessEntry()
            newEntry.exercise = entry.exercise
            newEntry.customName = entry.customName
            newEntry.minutesInt = entry.minutesInt
            newEntry.caloriesText = entry.caloriesText
            return newEntry
        }
        
        // Set duration if fitness entry exists
        if let firstFitnessEntry = fitnessEntries.first {
            durationHoursInt = firstFitnessEntry.minutesInt / 60
            durationMinutesInt = firstFitnessEntry.minutesInt % 60
        }
    }
    
    /// Recalculate calories for a diet entry
    /// - Parameter index: Index of the diet entry
    func recalcEntryCalories(_ index: Int) {
        guard index < dietEntries.count else { return }
        guard dietEntries[index].food != nil else { return }
        let calculatedCalories = TaskEditHelper.dietEntryCalories(dietEntries[index])
        dietEntries[index].caloriesText = String(calculatedCalories)
    }
    
    /// Recalculate calories from duration for fitness entry
    func recalcCaloriesFromDurationIfNeeded() {
        guard selectedCategory == .fitness else { return }
        guard let idx = editingFitnessEntryIndex, idx < fitnessEntries.count else { return }
        let totalMinutes = max(0, durationHoursInt * 60 + durationMinutesInt)
        fitnessEntries[idx].minutesInt = totalMinutes
        if let per30 = fitnessEntries[idx].exercise?.calPer30Min {
            let estimated = Int(round(Double(per30) * Double(totalMinutes) / 30.0))
            fitnessEntries[idx].caloriesText = String(estimated)
        }
    }
    
    /// Build updated TaskItem from form state
    /// - Returns: Updated TaskItem
    func buildUpdatedTask() -> TaskItem? {
        guard let oldTask = task else { return nil }
        
        // Merge time from timeDate (hour:minute) with old task's date
        let calendar = Calendar.current
        let oldDateKey = calendar.startOfDay(for: oldTask.timeDate)
        
        // Extract time components from the new timeDate (selected by user)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
        
        // Merge time with old task's date
        let newTimeDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                        minute: timeComponents.minute ?? 0,
                                        second: 0,
                                        of: oldDateKey) ?? oldDateKey
        
        // Calculate end time for fitness tasks
        let endTimeValue: String?
        if selectedCategory == .fitness {
            let totalMinutes = fitnessEntries.map { $0.minutesInt }.reduce(0, +)
            if totalMinutes > 0 {
                let endDate = calendar.date(byAdding: .minute, value: totalMinutes, to: newTimeDate) ?? newTimeDate
                let df = DateFormatter()
                df.locale = .current
                df.timeStyle = .short
                df.dateStyle = .none
                endTimeValue = df.string(from: endDate)
            } else {
                endTimeValue = nil
            }
        } else {
            endTimeValue = nil
        }
        
        // Build calories meta text
        let metaText: String = {
            switch selectedCategory {
            case .diet:
                let totalCalories = dietEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
                return "+\(totalCalories) cal"
            case .fitness:
                let totalCalories = fitnessEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
                return "-\(totalCalories) cal"
            default:
                return ""
            }
        }()
        
        // Determine the correct emphasis color based on the selected category
        let emphasisHexValue: String = {
            switch selectedCategory {
            case .diet: return "16A34A"
            case .fitness: return "364153"
            case .others: return "364153"
            case .none: return oldTask.emphasisHex
            }
        }()
        
        // Truncate subtitle
        let truncatedSubtitle = TaskEditHelper.truncateSubtitle(descriptionText)
        
        // Format time string for display
        let df = DateFormatter()
        df.locale = .current
        df.timeStyle = .short
        df.dateStyle = .none
        let timeString = df.string(from: newTimeDate)
        
        // Create new TaskItem with updated values, preserving the original id
        return TaskItem(
            id: oldTask.id,
            title: titleText.isEmpty ? oldTask.title : titleText,
            subtitle: truncatedSubtitle,
            time: timeString,
            timeDate: newTimeDate,
            endTime: endTimeValue,
            meta: metaText,
            isDone: oldTask.isDone,
            emphasisHex: emphasisHexValue,
            category: selectedCategory ?? oldTask.category,
            dietEntries: dietEntries,
            fitnessEntries: fitnessEntries,
            isAIGenerated: oldTask.isAIGenerated,
            isDailyChallenge: oldTask.isDailyChallenge
        )
    }
    
    /// Update task
    /// - Parameter updatedTask: Updated task
    func updateTask(_ updatedTask: TaskItem) {
        guard let oldTask = task else {
            errorMessage = "No task to update"
            return
        }
        
        guard let userId = userId else {
            errorMessage = "No user logged in"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        // Update task in repository
        taskRepository.updateTask(userId: userId, newTask: updatedTask, oldTask: oldTask) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isSaving = false
                
                switch result {
                case .success:
                    self.task = updatedTask
                    self.originalTask = updatedTask
                    self.isEditing = false
                    print("✅ DetailTaskViewModel: Task updated successfully")
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("❌ DetailTaskViewModel: Failed to update task - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Save changes from form
    /// - Parameter completion: Optional completion handler called when save completes
    func saveChanges(completion: ((Result<TaskItem, Error>) -> Void)? = nil) {
        guard let updatedTask = buildUpdatedTask() else {
            let error = NSError(domain: "DetailTaskViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to build updated task"])
            errorMessage = error.localizedDescription
            completion?(.failure(error))
            return
        }
        
        guard let oldTask = task else {
            let error = NSError(domain: "DetailTaskViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "No task to update"])
            errorMessage = error.localizedDescription
            completion?(.failure(error))
            return
        }
        
        guard let userId = userId else {
            let error = NSError(domain: "DetailTaskViewModel", code: 3, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
            errorMessage = error.localizedDescription
            completion?(.failure(error))
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        // Update task in repository
        taskRepository.updateTask(userId: userId, newTask: updatedTask, oldTask: oldTask) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isSaving = false
                
                switch result {
                case .success:
                    self.task = updatedTask
                    self.originalTask = updatedTask
                    self.isEditing = false
                    completion?(.success(updatedTask))
                    print("✅ DetailTaskViewModel: Task updated successfully")
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion?(.failure(error))
                    print("❌ DetailTaskViewModel: Failed to update task - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Delete task
    /// - Parameter completion: Completion handler called when task is deleted
    func deleteTask(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let task = task else {
            completion(.failure(NSError(domain: "DetailTaskViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No task to delete"])))
            return
        }
        
        guard let userId = userId else {
            completion(.failure(NSError(domain: "DetailTaskViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])))
            return
        }
        
        isDeleting = true
        errorMessage = nil
        
        // Delete task from repository
        taskRepository.deleteTask(userId: userId, taskId: task.id, date: task.timeDate) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isDeleting = false
                
                switch result {
                case .success:
                    self.task = nil
                    self.originalTask = nil
                    completion(.success(()))
                    print("✅ DetailTaskViewModel: Task deleted successfully")
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion(.failure(error))
                    print("❌ DetailTaskViewModel: Failed to delete task - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Toggle task completion
    func toggleCompletion() {
        guard var currentTask = task else {
            return
        }
        
        currentTask.isDone.toggle()
        updateTask(currentTask)
    }
    
    /// Start editing
    func startEditing() {
        guard let task = task else {
            return
        }
        
        originalTask = task
        loadTaskData(from: task) // Reload data when entering edit mode
        isEditing = true
    }
    
    /// Cancel editing
    func cancelEditing() {
        if let original = originalTask {
            loadTaskData(from: original) // Reload original data
        }
        isEditing = false
        errorMessage = nil
    }
    
    /// Update task from external source (e.g., from parent view)
    /// - Parameter task: Updated task
    func updateTaskFromExternal(_ task: TaskItem) {
        self.task = task
        if !isEditing {
            self.originalTask = task
            loadTaskData(from: task)
        }
    }
    
    /// Dismiss keyboard
    func dismissKeyboard() {
        // Note: Focus states are managed in View, but we can clear editing indices
        editingDietEntryIndex = nil
        editingFitnessEntryIndex = nil
    }
    
    /// Add diet entry and open quick pick
    func addDietEntry() {
        dietEntries.append(DietEntry(quantityText: "1", unit: "serving", caloriesText: ""))
        editingDietEntryIndex = dietEntries.count - 1
        quickPickMode = .food
        quickPickSearch = ""
        isQuickPickPresented = true
    }
    
    /// Edit diet entry at index
    func editDietEntry(at index: Int) {
        editingDietEntryIndex = index
        quickPickMode = .food
        quickPickSearch = ""
        isQuickPickPresented = true
    }
    
    /// Delete diet entry at index
    func deleteDietEntry(at index: Int) {
        guard index < dietEntries.count else { return }
        dietEntries.remove(at: index)
    }
    
    /// Add fitness entry and open quick pick
    func addFitnessEntry() {
        fitnessEntries.append(FitnessEntry())
        editingFitnessEntryIndex = fitnessEntries.count - 1
        quickPickMode = .exercise
        quickPickSearch = ""
        isQuickPickPresented = true
    }
    
    /// Edit fitness entry at index
    func editFitnessEntry(at index: Int) {
        editingFitnessEntryIndex = index
        quickPickMode = .exercise
        quickPickSearch = ""
        isQuickPickPresented = true
    }
    
    /// Delete fitness entry at index
    func deleteFitnessEntry(at index: Int) {
        guard index < fitnessEntries.count else { return }
        fitnessEntries.remove(at: index)
    }
    
    /// Clear editing indices when quick pick is dismissed
    func clearEditingIndices() {
        editingDietEntryIndex = nil
        editingFitnessEntryIndex = nil
    }
}

