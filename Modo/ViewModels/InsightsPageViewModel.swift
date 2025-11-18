import Foundation
import SwiftUI
import SwiftData
import Combine
import FirebaseAuth

/// ViewModel for managing insights page state and business logic
///
/// This ViewModel handles:
/// - Chat message management
/// - AI task generation
/// - Image analysis
/// - Keyboard state management
/// - Attachment menu state
final class InsightsPageViewModel: ObservableObject {
    // MARK: - Published Properties - Chat State
    
    /// Input text for chat
    @Published var inputText: String = ""
    
    /// Whether input field is focused
    @Published var isInputFocused: Bool = false
    
    /// Whether clear confirmation is shown
    @Published var showClearConfirmation: Bool = false
    
    /// Whether task created toast is shown
    @Published var showTaskCreatedToast: Bool = false
    
    /// Whether database migration error alert is shown
    @Published var showDatabaseMigrationError: Bool = false
    
    // MARK: - Published Properties - Attachment State
    
    /// Whether attachment menu is shown
    @Published var showAttachmentMenu: Bool = false
    
    /// Whether photo picker is shown
    @Published var showPhotoPicker: Bool = false
    
    /// Selected image
    @Published var selectedImage: UIImage? = nil
    
    // MARK: - Published Properties - Keyboard State
    
    /// Keyboard height
    @Published var keyboardHeight: CGFloat = 0
    
    // MARK: - Published Properties - Drag State
    
    /// Drag start location for edge detection
    @Published var dragStartLocation: CGPoint? = nil
    
    // MARK: - Published Properties - Task State
    
    /// Sent task IDs to prevent duplicates
    @Published private(set) var sentTaskIds: Set<String> = []
    
    // MARK: - Private Properties
    
    /// Coach service for chat management
    private let coachService: ModoCoachService
    
    /// AI task generator for task creation
    private let aiTaskGenerator: AITaskGenerator
    
    /// User profile service
    private weak var userProfileService: UserProfileService?
    
    /// Auth service for user monitoring
    private weak var authService: AuthService?
    
    /// Model context for SwiftData operations
    private var modelContext: ModelContext?
    
    /// Keyboard show observer
    private var keyboardShowObserver: NSObjectProtocol?
    
    /// Keyboard hide observer
    private var keyboardHideObserver: NSObjectProtocol?
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties - Coach Service State
    
    /// Chat messages from coach service (exposed for View)
    @Published var messages: [FirebaseChatMessage] = []
    
    /// Whether coach service is processing (exposed for View)
    @Published var isProcessing: Bool = false
    
    // MARK: - Computed Properties
    
    /// Current user profile
    private var userProfile: UserProfile? {
        userProfileService?.currentProfile
    }
    
    // MARK: - Initialization
    
    /// Initialize ViewModel with dependencies
    /// - Parameters:
    ///   - coachService: Coach service for chat management
    ///   - aiTaskGenerator: AI task generator for task creation
    init(
        coachService: ModoCoachService = ModoCoachService(),
        aiTaskGenerator: AITaskGenerator = AITaskGenerator()
    ) {
        self.coachService = coachService
        self.aiTaskGenerator = aiTaskGenerator
        
        // Observe coach service messages
        coachService.$messages
            .receive(on: DispatchQueue.main)
            .assign(to: &$messages)
        
        // Observe coach service processing state
        coachService.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isProcessing)
        
    }
    
    // MARK: - Setup Methods
    
    /// Setup ViewModel with dependencies
    /// - Parameters:
    ///   - modelContext: Model context for SwiftData operations
    ///   - userProfileService: User profile service
    ///   - authService: Auth service for user monitoring
    func setup(
        modelContext: ModelContext,
        userProfileService: UserProfileService,
        authService: AuthService
    ) {
        self.modelContext = modelContext
        self.userProfileService = userProfileService
        self.authService = authService
        
        // Load chat history
        loadChatHistory()
        
        // Setup keyboard observers
        setupKeyboardObservers()
        
        // Observe user changes
        observeUserChanges()
        
        // Observe database migration errors
        setupDatabaseErrorObserver()
    }
    
    /// Load chat history from SwiftData
    private func loadChatHistory() {
        guard let modelContext = modelContext else { return }
        coachService.loadHistory(from: modelContext, userProfile: userProfile)
    }
    
    /// Observe user changes
    private func observeUserChanges() {
        // Note: User changes are handled in View's onChange modifier
        // This method is kept for potential future use
    }
    
    /// Handle user change (called from View)
    func handleUserChange() {
        guard let modelContext = modelContext else { return }
        coachService.resetForNewUser()
        coachService.loadHistory(from: modelContext, userProfile: userProfile)
    }
    
    // MARK: - Keyboard Management
    
    /// Setup keyboard observers
    private func setupKeyboardObservers() {
        keyboardShowObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                // Use async to avoid "Publishing changes from within view updates" warning
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self?.keyboardHeight = keyboardFrame.height
                    }
                }
            }
        }
        
        keyboardHideObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Use async to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.3)) {
                    self?.keyboardHeight = 0
                }
            }
        }
    }
    
    /// Remove keyboard observers
    func removeKeyboardObservers() {
        if let showObserver = keyboardShowObserver {
            NotificationCenter.default.removeObserver(showObserver)
        }
        if let hideObserver = keyboardHideObserver {
            NotificationCenter.default.removeObserver(hideObserver)
        }
    }
    
    // MARK: - Message Management
    
    /// Send message to coach service
    func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        coachService.sendMessage(inputText, userProfile: userProfile)
        inputText = ""
    }
    
    /// Clear chat history
    func clearChatHistory() {
        // Pass the modelContext to ensure coachService has access
        coachService.clearHistory(with: modelContext)
        showClearConfirmation = false
    }
    
    // MARK: - Image Management
    
    /// Handle image selection
    /// - Parameter image: Selected image
    func handleImageSelection(_ image: UIImage) {
        // Show user message
        let userMessage = "📷 [Food photo uploaded]"
        coachService.sendUserMessage(userMessage)
        
        // Convert image to base64 for API
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { return }
        let base64String = imageData.base64EncodedString()
        
        // Send to OpenAI Vision API for food analysis
        Task {
            await coachService.analyzeFoodImage(base64Image: base64String, userProfile: userProfile)
        }
    }
    
    // MARK: - Task Generation
    
    /// Handle accept button press for message
    /// - Parameter message: Message to accept
    func handleAcceptTask(for message: FirebaseChatMessage) {
        // Check if already processed to prevent duplicates
        guard !message.actionTaken else {
            print("⚠️ Task already accepted for this message, skipping...")
            return
        }
        
        // Mark as taken immediately and save to database
        message.actionTaken = true
        try? modelContext?.save()
        
        // Generate task using AI generator
        handleAcceptWithAIGenerator(for: message)
        
        // Send confirmation message
        let confirmMessage = FirebaseChatMessage(
            content: "Great! I've created your personalized plan with detailed exercises and meals. You'll find it in your Main Page! 💪",
            isFromUser: false
        )
        coachService.messages.append(confirmMessage)
        coachService.saveMessage(confirmMessage)
    }
    
    /// Handle reject button press for message
    /// - Parameter message: Message to reject
    func handleRejectTask(for message: FirebaseChatMessage) {
        // Check if already processed
        guard !message.actionTaken else {
            print("⚠️ Task already rejected for this message, skipping...")
            return
        }
        
        // Mark as taken and save
        message.actionTaken = true
        try? modelContext?.save()
        
        coachService.rejectWorkoutPlan(for: message)
    }
    
    /// Handle accept with AI generator
    /// - Parameter message: Message to process
    private func handleAcceptWithAIGenerator(for message: FirebaseChatMessage) {
        print("🎯 ========== ACCEPT BUTTON PRESSED ==========")
        print("   Message ID: \(message.id)")
        print("   Message Type: \(message.messageType)")
        print("   Message content: \(message.content.prefix(100))")
        
        // ✅ PRIORITY 1: Check if message has structured plan data (from Function Calling)
        if message.messageType == "nutrition_plan", let nutritionPlan = message.nutritionPlan {
            print("   ✅ Found nutrition plan in message with \(nutritionPlan.meals.count) meals")
            print("   Meals: \(nutritionPlan.meals.map { $0.name }.joined(separator: ", "))")
            // Directly send notification using the plan data
            for meal in nutritionPlan.meals {
                sendNutritionTaskNotification(meal: meal, date: nutritionPlan.date)
            }
            return
        }
        
        if message.messageType == "workout_plan", let workoutPlan = message.workoutPlan {
            print("   ✅ Found workout plan in message with \(workoutPlan.exercises.count) exercises")
            // Directly send notification using the plan data
            sendWorkoutTaskNotification(plan: workoutPlan)
            return
        }
        
        if message.messageType == "multi_day_plan" {
            // ⚠️ Safe access to multiDayPlan - may be nil for old messages from before this feature
            if let multiDayPlan = message.multiDayPlan {
                print("   ✅ Found multi-day plan in message with \(multiDayPlan.days.count) days")
                print("   Type: \(multiDayPlan.planType)")
                // Send notifications for each day
                for day in multiDayPlan.days {
                    if let workout = day.workout {
                        sendWorkoutTaskNotification(plan: workout)
                    }
                    if let nutrition = day.nutrition {
                        for meal in nutrition.meals {
                            sendNutritionTaskNotification(meal: meal, date: nutrition.date)
                        }
                    }
                }
                return
            } else {
                print("   ⚠️ Message marked as multi_day_plan but data is nil (possibly old message)")
                print("   Falling back to text analysis")
                // Continue to fallback logic below
            }
        }
        
        // ✅ FALLBACK: If no structured data, use text analysis (old method)
        print("   ⚠️ No structured plan found, falling back to text analysis")
        print("   Using unified AITaskGenerator")
        
        let content = message.content.lowercased()
        
        // Step 1: Detect task type
        let isWorkout = content.contains("workout") ||
                       content.contains("exercise") ||
                       content.contains("training") ||
                       content.contains("fitness")
        
        let isNutrition = content.contains("meal") ||
                         content.contains("food") ||
                         content.contains("breakfast") ||
                         content.contains("lunch") ||
                         content.contains("dinner") ||
                         content.contains("nutrition")
        
        print("   Task type detected - Workout: \(isWorkout), Nutrition: \(isNutrition)")
        
        // Step 2: Extract date(s)
        let targetDate = extractDateFromRecentMessages() ?? Date()
        print("   Target date: \(targetDate)")
        
        // Step 3: Detect multi-day plan
        let isMultiDay = content.contains("day 1") ||
                        content.contains("day 2") ||
                        content.contains("days") ||
                        content.contains("week")
        
        // Step 4: Call unified AITaskGenerator
        if isMultiDay {
            // Multi-day plan
            handleMultiDayGeneration(
                startDate: targetDate,
                includeWorkout: isWorkout,
                includeNutrition: isNutrition
            )
        } else if isWorkout && isNutrition {
            // Both workout and nutrition for single day
            handleBothTasksGeneration(for: targetDate)
        } else if isWorkout {
            // Workout only
            handleWorkoutGeneration(for: targetDate)
        } else if isNutrition {
            // Nutrition only
            handleNutritionGeneration(for: targetDate)
        } else {
            // Fallback: default to workout
            print("   ⚠️ Could not determine task type, defaulting to workout")
            handleWorkoutGeneration(for: targetDate)
        }
    }
    
    /// Handle workout generation
    /// - Parameter date: Date for workout
    private func handleWorkoutGeneration(for date: Date) {
        print("🏋️ ========== GENERATING WORKOUT TASK ==========")
        print("   Date: \(date)")
        
        aiTaskGenerator.generateWorkoutTask(
            for: date,
            userProfile: userProfile
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let aiTask):
                    print("   ✅ Workout task generated successfully")
                    print("   Title: \(aiTask.title)")
                    print("   Exercises: \(aiTask.exercises.count)")
                    self?.addAIGeneratedTask(aiTask)
                case .failure(let error):
                    print("   ❌ Failed to generate workout: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Handle nutrition generation
    /// - Parameter date: Date for nutrition
    private func handleNutritionGeneration(for date: Date) {
        print("🍽️ ========== GENERATING NUTRITION TASKS ==========")
        print("   Date: \(date)")
        
        // Generate all 3 meals
        aiTaskGenerator.generateSpecificNutritionTasks(
            ["breakfast", "lunch", "dinner"],
            for: date,
            userProfile: userProfile
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let aiTasks):
                    print("   ✅ Generated \(aiTasks.count) nutrition tasks")
                    for (index, task) in aiTasks.enumerated() {
                        print("   Task \(index + 1): \(task.title) - \(task.meals.first?.name ?? "N/A")")
                        self?.addAIGeneratedTask(task)
                    }
                case .failure(let error):
                    print("   ❌ Failed to generate nutrition: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Handle both tasks generation
    /// - Parameter date: Date for tasks
    private func handleBothTasksGeneration(for date: Date) {
        print("🏋️🍽️ Generating both workout and nutrition for \(date)")
        
        // Generate workout
        handleWorkoutGeneration(for: date)
        
        // Generate nutrition
        handleNutritionGeneration(for: date)
    }
    
    /// Handle multi-day generation
    /// - Parameters:
    ///   - startDate: Start date for multi-day plan
    ///   - includeWorkout: Whether to include workout
    ///   - includeNutrition: Whether to include nutrition
    private func handleMultiDayGeneration(startDate: Date, includeWorkout: Bool, includeNutrition: Bool) {
        print("📅 Generating multi-day plan starting from \(startDate)")
        
        // Extract number of days from message if specified, default to 3
        let recentUserMessages = coachService.messages.filter { $0.isFromUser }.suffix(3)
        var numberOfDays = 3 // default
        
        for message in recentUserMessages.reversed() {
            let content = message.content.lowercased()
            // Look for patterns like "3 days", "5-day", "week" (7 days)
            if let regex = try? NSRegularExpression(pattern: #"(\d+)[\s\-]?days?"#, options: .caseInsensitive),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range(at: 1), in: content),
               let days = Int(content[range]) {
                numberOfDays = min(days, 7) // Cap at 7 days
                print("   Detected \(numberOfDays)-day plan")
                break
            } else if content.contains("week") {
                numberOfDays = 7
                print("   Detected weekly plan (7 days)")
                break
            }
        }
        
        // Generate dates array
        let calendar = Calendar.current
        let dates = (0..<numberOfDays).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startDate)
        }
        
        // Generate for each day
        for (index, date) in dates.enumerated() {
            print("   Day \(index + 1): \(date)")
            
            if includeWorkout {
                handleWorkoutGeneration(for: date)
            }
            
            if includeNutrition {
                handleNutritionGeneration(for: date)
            }
        }
    }
    
    /// Add AI generated task
    /// - Parameter aiTask: AI generated task
    private func addAIGeneratedTask(_ aiTask: AIGeneratedTask) {
        // Create unique ID for this task to prevent duplicates
        let taskId = "\(aiTask.type)_\(aiTask.title)_\(aiTask.date.timeIntervalSince1970)"
        
        print("➕ Adding AI generated task: \(aiTask.title) for \(aiTask.date)")
        print("   Task ID: \(taskId)")
        
        // Check if this task was already sent
        guard !sentTaskIds.contains(taskId) else {
            print("   ⚠️ Task already sent, skipping to prevent duplicate: \(taskId)")
            return
        }
        
        // Mark as sent
        sentTaskIds.insert(taskId)
        
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: aiTask.date)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current
        let dateString = dateFormatter.string(from: normalizedDate)
        
        switch aiTask.type {
        case .workout:
            // Convert workout task to notification format
            let exercisesData = aiTask.exercises.map { exercise -> [String: Any] in
                return [
                    "name": exercise.name,
                    "sets": exercise.sets,
                    "reps": exercise.reps,
                    "restSec": exercise.restSec,
                    "durationMin": exercise.durationMin,
                    "calories": exercise.calories
                ]
            }
            
            let userInfo: [String: Any] = [
                "date": dateString,
                "time": "09:00 AM",
                "duration": String(aiTask.totalDuration),
                "totalDuration": aiTask.totalDuration,
                "description": "Generated by Modo Coach AI",
                "theme": aiTask.title,
                "goal": "general_fitness",
                "exercises": exercisesData,
                "totalCalories": aiTask.totalCalories,
                "isNutrition": false,
                "isAIGenerated": true
            ]
            
            NotificationCenter.default.post(
                name: NSNotification.Name("CreateWorkoutTask"),
                object: nil,
                userInfo: userInfo
            )
            
        case .nutrition:
            // Convert nutrition task to notification format with detailed food items
            guard let meal = aiTask.meals.first else { return }
            
            // Convert food items to detailed array
            let foodItemsData = meal.foodItems.map { foodItem -> [String: Any] in
                return [
                    "name": foodItem.name,
                    "calories": foodItem.calories
                ]
            }
            
            // Create detailed description showing each food item with calories
            let detailedDescription = meal.foodItems.map {
                "\($0.name) (~\($0.calories) cal)"
            }.joined(separator: "\n")
            
            let userInfo: [String: Any] = [
                "date": dateString,
                "time": meal.time,
                "duration": "0",
                "description": detailedDescription,
                "goal": "nutrition",
                "exercises": [],
                "isNutrition": true,
                "calories": aiTask.totalCalories,
                "mealName": meal.name,
                "foodItems": foodItemsData,
                "isAIGenerated": true
            ]
            
            NotificationCenter.default.post(
                name: NSNotification.Name("CreateWorkoutTask"),
                object: nil,
                userInfo: userInfo
            )
        }
        
        // Show success feedback
        showTaskCreatedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.showTaskCreatedToast = false
        }
    }
    
    /// Extract date from recent messages
    /// - Returns: Extracted date or nil
    private func extractDateFromRecentMessages() -> Date? {
        print("📅 Extracting date from recent messages...")
        
        // Look at the last 5 user messages for date mentions
        let recentUserMessages = coachService.messages.filter { $0.isFromUser }.suffix(5)
        let calendar = Calendar.current
        let today = Date()
        
        print("   Found \(recentUserMessages.count) recent user messages")
        
        for message in recentUserMessages.reversed() {
            let content = message.content.lowercased()
            print("   Checking message: \(content.prefix(50))...")
            
            // Check for relative dates
            if content.contains("tomorrow") {
                let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: today)!
                print("   ✅ Found 'tomorrow' - returning \(tomorrowDate)")
                return tomorrowDate
            } else if content.contains("today") {
                print("   ✅ Found 'today' - returning \(today)")
                return today
            } else if content.contains("yesterday") {
                let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: today)!
                print("   ✅ Found 'yesterday' - returning \(yesterdayDate)")
                return yesterdayDate
            } else if content.contains("next week") {
                let nextWeekDate = calendar.date(byAdding: .day, value: 7, to: today)!
                print("   ✅ Found 'next week' - returning \(nextWeekDate)")
                return nextWeekDate
            } else if content.contains("this week") {
                print("   ✅ Found 'this week' - returning today")
                return today
            }
            
            // Check for day names (Monday, Tuesday, etc.)
            let dayNames = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            for (index, dayName) in dayNames.enumerated() {
                if content.contains(dayName) {
                    // Find the next occurrence of this day
                    let targetWeekday = (index + 2) % 7 // 1=Sunday, 2=Monday, etc.
                    let currentWeekday = calendar.component(.weekday, from: today)
                    var daysToAdd = targetWeekday - currentWeekday
                    if daysToAdd <= 0 {
                        daysToAdd += 7 // Go to next week
                    }
                    let targetDate = calendar.date(byAdding: .day, value: daysToAdd, to: today)!
                    print("   ✅ Found '\(dayName)' - returning \(targetDate)")
                    return targetDate
                }
            }
            
            // Check for "in X days"
            if let regex = try? NSRegularExpression(pattern: #"in\s+(\d+)\s+days?"#, options: .caseInsensitive),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let daysRange = Range(match.range(at: 1), in: content),
               let days = Int(content[daysRange]) {
                let targetDate = calendar.date(byAdding: .day, value: days, to: today)!
                print("   ✅ Found 'in \(days) days' - returning \(targetDate)")
                return targetDate
            }
        }
        
        print("   ⚠️ No date found in recent messages, defaulting to today")
        return today
    }
    
    // MARK: - Lifecycle Methods
    
    /// Called when view appears
    func onAppear() {
        // Setup is handled in setup() method
    }
    
    /// Called when view disappears
    func onDisappear() {
        removeKeyboardObservers()
    }
    
    /// Setup observer for database migration errors
    private func setupDatabaseErrorObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DatabaseMigrationError"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showDatabaseMigrationError = true
        }
    }
    
    // MARK: - Direct Notification Senders (from structured plan data)
    
    /// Send notification for nutrition task directly from meal plan data
    /// - Parameters:
    ///   - meal: Meal data
    ///   - date: Date string
    private func sendNutritionTaskNotification(meal: NutritionPlanData.Meal, date: String) {
        print("📤 Sending nutrition task notification for: \(meal.name)")
        
        let foodItemsData = meal.foods.map { foodString -> [String: Any] in
            // Simple parsing: assume "Food Name (~XXX cal)" format
            let calories = meal.calories / meal.foods.count // Distribute equally
            return [
                "name": foodString,
                "calories": calories
            ]
        }
        
        let detailedDescription = meal.foods.joined(separator: "\n")
        
        let userInfo: [String: Any] = [
            "date": date,
            "time": meal.time,
            "duration": "0",
            "description": detailedDescription,
            "goal": "nutrition",
            "exercises": [],
            "isNutrition": true,
            "calories": meal.calories,
            "mealName": meal.name,
            "foodItems": foodItemsData,
            "isAIGenerated": true
        ]
        
        NotificationCenter.default.post(
            name: NSNotification.Name("CreateWorkoutTask"),
            object: nil,
            userInfo: userInfo
        )
    }
    
    /// Send notification for workout task directly from workout plan data
    /// - Parameter plan: Workout plan data
    private func sendWorkoutTaskNotification(plan: WorkoutPlanData) {
        print("📤 Sending workout task notification")
        
        let exercisesData = plan.exercises.map { exercise -> [String: Any] in
            return [
                "name": exercise.name,
                "sets": exercise.sets,
                "reps": exercise.reps,
                "restSec": exercise.restSec ?? 60,
                "durationMin": 5, // Estimate
                "calories": 50 // Estimate
            ]
        }
        
        let userInfo: [String: Any] = [
            "date": plan.date,
            "time": "09:00 AM",
            "duration": String(plan.exercises.count * 15),
            "totalDuration": plan.exercises.count * 15,
            "description": "Generated by Modo Coach AI",
            "theme": plan.goal.capitalized,
            "goal": plan.goal,
            "exercises": exercisesData,
            "totalCalories": plan.dailyKcalTarget ?? 0,
            "isNutrition": false,
            "isAIGenerated": true
        ]
        
        NotificationCenter.default.post(
            name: NSNotification.Name("CreateWorkoutTask"),
            object: nil,
            userInfo: userInfo
        )
    }
}

