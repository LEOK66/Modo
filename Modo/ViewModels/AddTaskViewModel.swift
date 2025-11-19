import Foundation
import SwiftUI
import SwiftData
import Combine
import FirebaseAuth

/// ViewModel for managing add task form state and business logic
///
/// This ViewModel handles:
/// - Form state management
/// - AI task generation
/// - Form validation
/// - Task saving
final class AddTaskViewModel: ObservableObject {
    // MARK: - Published Properties - Form State
    
    /// Task title
    @Published var title: String = ""
    
    /// Task description
    @Published var description: String = ""
    
    /// Selected date for the task
    @Published var selectedDate: Date
    
    /// Selected time for the task
    @Published var timeDate: Date = Date()
    
    /// Selected category
    @Published var selectedCategory: TaskCategory? = nil
    
    /// Diet entries
    @Published var dietEntries: [DietEntry] = []
    
    /// Fitness entries
    @Published var fitnessEntries: [FitnessEntry] = []
    
    /// Editing diet entry index
    @Published var editingDietEntryIndex: Int? = nil
    
    /// Editing fitness entry index
    @Published var editingFitnessEntryIndex: Int? = nil
    
    // MARK: - Published Properties - UI State
    
    /// Whether time sheet is presented
    @Published var isTimeSheetPresented: Bool = false
    
    /// Whether duration sheet is presented
    @Published var isDurationSheetPresented: Bool = false
    
    /// Duration hours
    @Published var durationHoursInt: Int = 0
    
    /// Duration minutes
    @Published var durationMinutesInt: Int = 0
    
    /// Whether quick pick sheet is presented
    @Published var isQuickPickPresented: Bool = false
    
    /// Quick pick mode
    @Published var quickPickMode: QuickPickSheetView.QuickPickMode? = nil
    
    /// Quick pick search text
    @Published var quickPickSearch: String = ""
    
    /// Online foods
    @Published var onlineFoods: [MenuData.FoodItem] = []
    
    /// Whether online loading
    @Published var isOnlineLoading: Bool = false
    
    /// Recent foods (in-memory per session)
    @Published var recentFoods: [MenuData.FoodItem] = []
    
    /// Recent exercises (in-memory per session)
    @Published var recentExercises: [MenuData.ExerciseItem] = []
    
    // MARK: - Published Properties - Undo State
    
    /// Whether undo banner is shown
    @Published var showUndoBanner: Bool = false
    
    /// Undo message
    @Published var undoMessage: String = ""
    
    /// Last deleted diet context
    @Published var lastDeletedDiet: DeletedDietContext? = nil
    
    /// Last deleted fitness context
    @Published var lastDeletedFitness: DeletedFitnessContext? = nil
    
    /// Last cleared diet entries
    @Published var lastClearedDiet: [DietEntry]? = nil
    
    /// Last cleared fitness entries
    @Published var lastClearedFitness: [FitnessEntry]? = nil
    
    // MARK: - Published Properties - AI State
    
    /// Whether AI generate sheet is presented
    @Published var isAIGenerateSheetPresented: Bool = false
    
    /// Whether ask AI sheet is presented
    @Published var isAskAISheetPresented: Bool = false
    
    /// AI prompt text
    @Published var aiPromptText: String = ""
    
    /// Ask AI messages
    @Published var askAIMessages: [AskAIChatView.SimpleMessage] = []
    
    /// Whether AI is generating
    @Published var isAIGenerating: Bool = false
    
    /// AI generation error
    @Published var aiGenerateError: String? = nil
    
    /// Whether title is generating
    @Published var isTitleGenerating: Bool = false
    
    /// Whether description is generating
    @Published var isDescriptionGenerating: Bool = false
    
    // MARK: - Published Properties - Focus State
    
    /// Title focused
    @Published var titleFocused: Bool = false
    
    /// Description focused
    @Published var descriptionFocused: Bool = false
    
    /// Diet name focus index
    @Published var dietNameFocusIndex: Int? = nil
    
    /// Fitness name focus index
    @Published var fitnessNameFocusIndex: Int? = nil
    
    /// Pending scroll ID
    @Published var pendingScrollId: String? = nil
    
    // MARK: - Published Properties - Loading State
    
    /// Whether form is loading
    @Published private(set) var isLoading: Bool = false
    
    /// Whether form is saving
    @Published private(set) var isSaving: Bool = false
    
    /// Error message
    @Published var errorMessage: String? = nil
    
    // MARK: - Private Properties
    
    /// AI service for task generation
    private let aiService: AddTaskAIService
    
    /// AI parser for parsing AI responses
    private let aiParser: AddTaskAIParser
    
    /// Task repository for saving tasks
    private let taskRepository: TaskRepository
    
    /// Model context for SwiftData operations
    private var modelContext: ModelContext
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Whether form can be saved (published property, updated only when relevant properties change)
    @Published var canSave: Bool = false
    
    /// Current user ID
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    /// Search debounce work item
    private var searchDebounceWork: DispatchWorkItem? = nil
    
    // MARK: - Initialization
    
    /// Initialize AddTaskViewModel
    /// - Parameters:
    ///   - selectedDate: Initial selected date
    ///   - modelContext: Model context for SwiftData (required)
    ///   - aiService: AI service for task generation (defaults to new instance)
    ///   - aiParser: AI parser for parsing AI responses (defaults to new instance)
    ///   - taskRepository: Task repository (defaults to new instance with ServiceContainer dependencies)
    ///   
    /// Note: If taskRepository is not provided, it will be created using:
    /// - modelContext (from parameter)
    /// - databaseService (from ServiceContainer.shared)
    init(
        selectedDate: Date,
        modelContext: ModelContext,
        aiService: AddTaskAIService = AddTaskAIService(),
        aiParser: AddTaskAIParser = AddTaskAIParser(),
        taskRepository: TaskRepository? = nil
    ) {
        self.selectedDate = selectedDate
        self.modelContext = modelContext
        self.aiService = aiService
        self.aiParser = aiParser
        
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
        
        // Set initial time to selected date
        self.timeDate = selectedDate
        
        // Setup canSave to update only when relevant properties change
        setupCanSaveObserver()
    }
    
    deinit {
        cancellables.removeAll()
        searchDebounceWork?.cancel()
    }
    
    // MARK: - Setup Methods
    
    /// Update model context with the actual one from SwiftUI environment
    /// This is called in onAppear because @Environment is only available when view's body is rendered
    /// - Parameter newModelContext: Model context from SwiftUI environment
    func updateModelContext(_ newModelContext: ModelContext) {
        self.modelContext = newModelContext
        // Note: Repository also holds modelContext, but it's not actively used currently
        // (it's for future SwiftData migration). So we don't need to update it.
    }
    
    // MARK: - Computed Properties
    
    /// Total diet calories
    var totalDietCalories: Int {
        dietEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
    }
    
    /// Total fitness calories
    var totalFitnessCalories: Int {
        fitnessEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
    }
    
    /// Net calories (diet - fitness)
    var netCalories: Int {
        totalDietCalories - totalFitnessCalories
    }
    
    // MARK: - Public Methods
    
    /// Generate task automatically using AI
    func generateTaskAutomatically() {
        guard !isAIGenerating else {
            return
        }
        
        isAIGenerating = true
        aiGenerateError = nil
        
        // Generate task using AI service
        aiService.generateTaskAutomatically(
            for: selectedDate,
            modelContext: modelContext
        ) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isAIGenerating = false
                
                switch result {
                case .success(let aiResponse):
                    // Parse AI response using parser
                    let parsedContent = self.aiParser.parseTaskContent(aiResponse)
                    
                    // Fill form with parsed content
                    self.fillFormWithParsedContent(parsedContent)
                case .failure(let error):
                    self.aiGenerateError = error.localizedDescription
                    print("❌ AddTaskViewModel: Failed to generate task - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Generate or refine title using AI
    func generateOrRefineTitle() {
        guard !isTitleGenerating else {
            return
        }
        
        isTitleGenerating = true
        
        // Generate title using AI service
        aiService.generateOrRefineTitle(
            currentTitle: title,
            modelContext: modelContext
        ) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isTitleGenerating = false
                
                switch result {
                case .success(let generatedTitle):
                    self.title = generatedTitle
                case .failure(let error):
                    self.aiGenerateError = error.localizedDescription
                    print("❌ AddTaskViewModel: Failed to generate title - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Generate description using AI
    func generateDescription() {
        guard !isDescriptionGenerating else {
            return
        }
        
        isDescriptionGenerating = true
        
        // Generate description using AI service
        aiService.generateDescription(
            currentTitle: title,
            modelContext: modelContext
        ) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isDescriptionGenerating = false
                
                switch result {
                case .success(let titleAndDescription):
                    // Update both title and description if title was empty
                    if self.title.isEmpty {
                        self.title = titleAndDescription.title
                    }
                    self.description = titleAndDescription.description
                case .failure(let error):
                    self.aiGenerateError = error.localizedDescription
                    print("❌ AddTaskViewModel: Failed to generate description - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Validate form
    /// - Returns: True if form is valid, false otherwise
    func validateForm() -> Bool {
        // Title is required
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Title is required"
            return false
        }
        
        // Category is required
        guard selectedCategory != nil else {
            errorMessage = "Category is required"
            return false
        }
        
        // For diet category, at least one diet entry is required
        if selectedCategory == .diet && dietEntries.isEmpty {
            errorMessage = "At least one diet entry is required"
            return false
        }
        
        // For fitness category, at least one fitness entry is required
        if selectedCategory == .fitness && fitnessEntries.isEmpty {
            errorMessage = "At least one fitness entry is required"
            return false
        }
        
        errorMessage = nil
        return true
    }
    
    /// Create task from form data (does not save, just creates the task)
    /// - Returns: Created task or nil if validation fails
    func createTask() -> TaskItem? {
        guard validateForm() else {
            return nil
        }
        
        guard let category = selectedCategory else {
            return nil
        }
        
        // Create task item
        return createTaskItem(category: category)
    }
    
    /// Reset form
    func resetForm() {
        title = ""
        description = ""
        timeDate = selectedDate
        selectedCategory = nil
        dietEntries = []
        fitnessEntries = []
        editingDietEntryIndex = nil
        editingFitnessEntryIndex = nil
        errorMessage = nil
        aiGenerateError = nil
    }
    
    /// Dismiss keyboard
    func dismissKeyboard() {
        titleFocused = false
        descriptionFocused = false
        dietNameFocusIndex = nil
        fitnessNameFocusIndex = nil
    }
    
    /// Handle undo action
    func handleUndoAction() {
        if let snapshot = lastClearedDiet {
            dietEntries = snapshot
            lastClearedDiet = nil
        } else if let snapshotF = lastClearedFitness {
            fitnessEntries = snapshotF
            lastClearedFitness = nil
        } else if let ctx = lastDeletedDiet {
            dietEntries.insert(ctx.entry, at: min(ctx.index, dietEntries.count))
            lastDeletedDiet = nil
        } else if let ctx = lastDeletedFitness {
            fitnessEntries.insert(ctx.entry, at: min(ctx.index, fitnessEntries.count))
            lastDeletedFitness = nil
        }
        showUndoBanner = false
    }
    
    /// Delete diet entry at index
    func deleteDietEntry(at index: Int) {
        guard index < dietEntries.count else { return }
        let removed = dietEntries.remove(at: index)
        lastDeletedDiet = DeletedDietContext(entry: removed, index: index)
        undoMessage = "Diet item deleted"
        showUndoBanner = true
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showUndoBanner = false
            self?.lastDeletedDiet = nil
        }
    }
    
    /// Delete fitness entry at index
    func deleteFitnessEntry(at index: Int) {
        guard index < fitnessEntries.count else { return }
        let removed = fitnessEntries.remove(at: index)
        lastDeletedFitness = DeletedFitnessContext(entry: removed, index: index)
        undoMessage = "Exercise deleted"
        showUndoBanner = true
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showUndoBanner = false
            self?.lastDeletedFitness = nil
        }
    }
    
    /// Clear all diet entries
    func clearAllDietEntries() {
        let count = dietEntries.count
        lastClearedDiet = dietEntries
        dietEntries.removeAll()
        undoMessage = count > 1 ? "Diet items cleared" : "Diet item cleared"
        showUndoBanner = true
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showUndoBanner = false
            self?.lastClearedDiet = nil
        }
    }
    
    /// Clear all fitness entries
    func clearAllFitnessEntries() {
        lastClearedFitness = fitnessEntries
        fitnessEntries.removeAll()
        undoMessage = "Exercises cleared"
        showUndoBanner = true
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showUndoBanner = false
            self?.lastClearedFitness = nil
        }
    }
    
    /// Add diet entry
    func addDietEntry() {
        dietEntries.append(DietEntry(quantityText: "1", unit: "serving", caloriesText: ""))
        editingDietEntryIndex = dietEntries.count - 1
        quickPickMode = .food
        quickPickSearch = ""
        isQuickPickPresented = true
    }
    
    /// Add fitness entry
    func addFitnessEntry() {
        fitnessEntries.append(FitnessEntry())
        editingFitnessEntryIndex = fitnessEntries.count - 1
        quickPickMode = .exercise
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
    
    /// Edit fitness entry at index
    func editFitnessEntry(at index: Int) {
        editingFitnessEntryIndex = index
        quickPickMode = .exercise
        quickPickSearch = ""
        isQuickPickPresented = true
    }
    
    /// Recalculate calories for diet entry at index
    func recalcEntryCalories(at index: Int) {
        guard index < dietEntries.count else { return }
        guard dietEntries[index].food != nil else { return }
        let calculatedCalories = TaskEditHelper.dietEntryCalories(dietEntries[index])
        dietEntries[index].caloriesText = String(calculatedCalories)
    }
    
    /// Recalculate calories from duration if needed
    func recalcCaloriesFromDurationIfNeeded() {
        guard selectedCategory == .fitness else { return }
        guard let idx = editingFitnessEntryIndex, idx < fitnessEntries.count else { return }
        let h = durationHoursInt
        let m = durationMinutesInt
        let totalMinutes = max(0, h * 60 + m)
        // Always persist duration, even for custom exercises (no per30)
        fitnessEntries[idx].minutesInt = totalMinutes
        if let per30 = fitnessEntries[idx].exercise?.calPer30Min {
            let estimated = Int(round(Double(per30) * Double(totalMinutes) / 30.0))
            fitnessEntries[idx].caloriesText = String(estimated)
        }
    }
    
    /// Search foods with debounce
    func searchFoods(query: String, completion: @escaping ([MenuData.FoodItem]) -> Void) {
        searchDebounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            OffClient.searchFoodsCached(query: query, limit: 50) { results in
                DispatchQueue.main.async {
                    completion(results)
                }
            }
        }
        searchDebounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
    
    // MARK: - Private Methods - Setup
    
    /// Setup canSave observer to update only when relevant properties change
    private func setupCanSaveObserver() {
        // Combine publishers for title, selectedCategory, and fitnessEntries
        Publishers.CombineLatest3(
            $title,
            $selectedCategory,
            $fitnessEntries
        )
        .map { title, category, fitnessEntries -> Bool in
            print("canSave triggered")
            let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            guard let category = category else { return false }
            switch category {
            case .diet:
                return hasTitle
            case .fitness:
                return hasTitle && !fitnessEntries.isEmpty
            case .others:
                return hasTitle
            }
        }
        .assign(to: &$canSave)
    }
    
    /// Total fitness duration in minutes
    var totalFitnessDurationMinutes: Int {
        fitnessEntries.map { $0.minutesInt }.reduce(0, +)
    }
    
    /// Formatted time string
    var formattedTime: String {
        let df = DateFormatter()
        df.locale = .current
        df.timeStyle = .short
        df.dateStyle = .none
        return df.string(from: timeDate)
    }
    
    /// Formatted duration string
    func formattedDuration(h: Int, m: Int) -> String {
        return TaskEditHelper.formattedDuration(hours: h, minutes: m)
    }
    
    /// Calculate end time for fitness tasks
    func calculateEndTime(startTime: Date, durationMinutes: Int) -> String? {
        guard durationMinutes > 0 else { return nil }
        let endDate = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: startTime) ?? startTime
        let df = DateFormatter()
        df.locale = .current
        df.timeStyle = .short
        df.dateStyle = .none
        return df.string(from: endDate)
    }
    
    /// Truncate subtitle text
    func truncatedSubtitle(_ text: String) -> String {
        return TaskEditHelper.truncateSubtitle(text)
    }
    
    /// Emphasis hex for category
    var emphasisHexForCategory: String {
        switch selectedCategory {
        case .diet: return AppColors.successGreen
        case .fitness: return AppColors.primaryPurple
        case .others: return AppColors.primaryPurple
        case .none: return AppColors.primaryPurple
        }
    }
    
    /// Select category and initialize entries if needed
    func selectCategory(_ category: TaskCategory) {
        selectedCategory = category
        
        if category == .diet && dietEntries.isEmpty {
            dietEntries.append(DietEntry(quantityText: "1", unit: "serving", caloriesText: ""))
        } else if category == .fitness && fitnessEntries.isEmpty {
            fitnessEntries.append(FitnessEntry())
        }
    }
    
    /// Clear editing indices when quick pick is dismissed
    func clearEditingIndices() {
        editingDietEntryIndex = nil
        editingFitnessEntryIndex = nil
    }
    
    // MARK: - Private Methods
    
    /// Fill form with parsed content
    private func fillFormWithParsedContent(_ parsedContent: AddTaskAIParser.ParsedTaskContent) {
        if let parsedTitle = parsedContent.title, !parsedTitle.isEmpty {
            title = parsedTitle
        }
        
        if let parsedDescription = parsedContent.description, !parsedDescription.isEmpty {
            description = parsedDescription
        }
        
        if let parsedCategory = parsedContent.category {
            selectedCategory = parsedCategory
        }
        
        if let parsedTime = parsedContent.timeDate {
            timeDate = parsedTime
        }
        
        if !parsedContent.foods.isEmpty {
            dietEntries = parsedContent.foods
        }
        
        if !parsedContent.exercises.isEmpty {
            fitnessEntries = parsedContent.exercises
        }
    }
    
    /// Create task item from form data
    private func createTaskItem(category: TaskCategory) -> TaskItem {
        // Merge time from timeDate (hour:minute) with selectedDate's date
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
        let finalDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                     minute: timeComponents.minute ?? 0,
                                     second: 0,
                                     of: selectedDate) ?? selectedDate
        
        // Calculate end time for fitness tasks
        let endTimeValue: String?
        if category == .fitness && totalFitnessDurationMinutes > 0 {
            endTimeValue = calculateEndTime(startTime: finalDate, durationMinutes: totalFitnessDurationMinutes)
        } else {
            endTimeValue = nil
        }
        
        // Build calories meta text
        let metaText: String = {
            switch category {
            case .diet:
                return "+\(totalDietCalories) cal"
            case .fitness:
                return "-\(totalFitnessCalories) cal"
            default:
                return ""
            }
        }()
        
        // Only save entries from the selected category
        let finalDietEntries: [DietEntry]
        let finalFitnessEntries: [FitnessEntry]
        
        switch category {
        case .diet:
            finalDietEntries = dietEntries
            finalFitnessEntries = []
        case .fitness:
            finalDietEntries = []
            finalFitnessEntries = fitnessEntries
        case .others:
            finalDietEntries = []
            finalFitnessEntries = []
        }
        
        // Create task item
        return TaskItem(
            title: title.isEmpty ? "New Task" : title,
            subtitle: truncatedSubtitle(description),
            time: formattedTime,
            timeDate: finalDate,  // Use merged date+time
            endTime: endTimeValue,
            meta: metaText,
            isDone: false,
            emphasisHex: emphasisHexForCategory,
            category: category,
            dietEntries: finalDietEntries,
            fitnessEntries: finalFitnessEntries,
            createdAt: Date(),
            updatedAt: Date(),
            isAIGenerated: false,
            isDailyChallenge: false
        )
    }
}

// MARK: - Supporting Types

/// Deleted diet context for undo functionality
struct DeletedDietContext {
    let entry: DietEntry
    let index: Int
}

/// Deleted fitness context for undo functionality
struct DeletedFitnessContext {
    let entry: FitnessEntry
    let index: Int
}

