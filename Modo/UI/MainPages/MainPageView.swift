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
    @State private var midnightTimer: Timer? = nil
    @State private var isShowingProfile = false
    
    // Cache and database services
    private let cacheService = TaskCacheService.shared
    private let databaseService = DatabaseService.shared
    private let progressService = ProgressCalculationService.shared
    
    // Track current listener handle
    @State private var currentListenerHandle: DatabaseHandle? = nil
    @State private var currentListenerDate: Date? = nil
    @State private var isListenerActive = false
    @State private var listenerUpdateTask: Task<Void, Never>? = nil
    
    
    // Can refactor this to different file to reuse struct
    struct TaskItem: Identifiable, Codable {
        let id: UUID
        let title: String
        let subtitle: String
        let time: String
        let timeDate: Date // For sorting tasks by time
        let endTime: String? // For fitness tasks with duration
        let meta: String
        var isDone: Bool
        let emphasisHex: String
        let category: AddTaskView.Category // diet, fitness, others
        var dietEntries: [AddTaskView.DietEntry]
        var fitnessEntries: [AddTaskView.FitnessEntry]
        var createdAt: Date // For sync conflict resolution
        var updatedAt: Date // For sync conflict resolution
        var isAIGenerated: Bool // Mark if task is AI generated
        
        init(id: UUID = UUID(), title: String, subtitle: String, time: String, timeDate: Date, endTime: String? = nil, meta: String, isDone: Bool = false, emphasisHex: String, category: AddTaskView.Category, dietEntries: [AddTaskView.DietEntry], fitnessEntries: [AddTaskView.FitnessEntry], createdAt: Date = Date(), updatedAt: Date = Date(), isAIGenerated: Bool = false) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.time = time
            self.timeDate = timeDate
            self.endTime = endTime
            self.meta = meta
            self.isDone = isDone
            self.emphasisHex = emphasisHex
            self.category = category
            self.dietEntries = dietEntries
            self.fitnessEntries = fitnessEntries
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isAIGenerated = isAIGenerated
        }
        
        // Calculate total calories for this task
        // Diet tasks add calories, fitness tasks subtract calories, others don't affect calories
        var totalCalories: Int {
            switch category {
            case .diet:
                return dietEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
            case .fitness:
                return -fitnessEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
            case .others:
                return 0
            }
        }
        
        // Custom Codable implementation to handle Date serialization
        private enum CodingKeys: String, CodingKey {
            case id, title, subtitle, time, timeDate, endTime, meta, isDone, emphasisHex, category, dietEntries, fitnessEntries, createdAt, updatedAt, isAIGenerated
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            title = try container.decode(String.self, forKey: .title)
            subtitle = try container.decode(String.self, forKey: .subtitle)
            time = try container.decode(String.self, forKey: .time)
            // Decode timeDate as timestamp (milliseconds)
            let timeDateTimestamp = try container.decode(Int64.self, forKey: .timeDate)
            timeDate = Date(timeIntervalSince1970: Double(timeDateTimestamp) / 1000.0)
            endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
            meta = try container.decode(String.self, forKey: .meta)
            isDone = try container.decode(Bool.self, forKey: .isDone)
            emphasisHex = try container.decode(String.self, forKey: .emphasisHex)
            category = try container.decode(AddTaskView.Category.self, forKey: .category)
            // Backwards compatibility: use decodeIfPresent for new fields
            dietEntries = try container.decodeIfPresent([AddTaskView.DietEntry].self, forKey: .dietEntries) ?? []
            fitnessEntries = try container.decodeIfPresent([AddTaskView.FitnessEntry].self, forKey: .fitnessEntries) ?? []
            // Decode timestamps
            let createdAtTimestamp = try container.decodeIfPresent(Int64.self, forKey: .createdAt) ?? Int64(Date().timeIntervalSince1970 * 1000)
            createdAt = Date(timeIntervalSince1970: Double(createdAtTimestamp) / 1000.0)
            let updatedAtTimestamp = try container.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? Int64(Date().timeIntervalSince1970 * 1000)
            updatedAt = Date(timeIntervalSince1970: Double(updatedAtTimestamp) / 1000.0)
            // Decode isAIGenerated (defaults to false for backwards compatibility)
            isAIGenerated = try container.decodeIfPresent(Bool.self, forKey: .isAIGenerated) ?? false
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(title, forKey: .title)
            try container.encode(subtitle, forKey: .subtitle)
            try container.encode(time, forKey: .time)
            // Encode timeDate as timestamp (milliseconds)
            try container.encode(Int64(timeDate.timeIntervalSince1970 * 1000.0), forKey: .timeDate)
            try container.encodeIfPresent(endTime, forKey: .endTime)
            try container.encode(meta, forKey: .meta)
            try container.encode(isDone, forKey: .isDone)
            try container.encode(emphasisHex, forKey: .emphasisHex)
            try container.encode(category, forKey: .category)
            try container.encode(dietEntries, forKey: .dietEntries)
            try container.encode(fitnessEntries, forKey: .fitnessEntries)
            // Encode timestamps (milliseconds)
            try container.encode(Int64(createdAt.timeIntervalSince1970 * 1000.0), forKey: .createdAt)
            try container.encode(Int64(updatedAt.timeIntervalSince1970 * 1000.0), forKey: .updatedAt)
            try container.encode(isAIGenerated, forKey: .isAIGenerated)
        }
    }
    
    // Tasks stored by date (normalized to start of day)
    @State private var tasksByDate: [Date: [TaskItem]] = [:]
    
    // AI Task Generator
    @StateObject private var aiTaskGenerator = AITaskGenerator()
    @State private var showAITaskLoading = false
    
    // Currently selected date (normalized to start of day)
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    
    // Track newly added task for animation
    @State private var newlyAddedTaskId: UUID? = nil
    // CRITICAL FIX #3: Track if view is actually visible
    @State private var isViewVisible = false
    // Track notification observer to prevent duplicates
    @State private var notificationObserver: NSObjectProtocol? = nil
    
    // Date range: past 12 months to future 3 months
    private var dateRange: (min: Date, max: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let minDate = calendar.date(byAdding: .month, value: -12, to: today) ?? today
        let maxDate = calendar.date(byAdding: .month, value: 3, to: today) ?? today
        return (min: calendar.startOfDay(for: minDate), max: calendar.startOfDay(for: maxDate))
    }
    
    // Computed property to return tasks for selected date, sorted by time
    private var filteredTasks: [TaskItem] {
        tasks(for: selectedDate)
    }
    
    // MARK: - AI Task Generation
    
    /// Generate AI Tasks based on what's missing for the day
    private func generateAITask() {
        print("🎲 Smart AI Task Generation for \(selectedDate)")
        showAITaskLoading = true
        
        // Get current user profile
        let userProfile: UserProfile? = {
            let fetchDescriptor = FetchDescriptor<UserProfile>()
            return try? modelContext.fetch(fetchDescriptor).first
        }()
        
        // Analyze existing tasks for the selected date
        let existingTasks = tasks(for: selectedDate)
        let analysis = analyzeExistingTasks(existingTasks)
        
        print("📊 Task Analysis:")
        print("   - Fitness: \(analysis.hasFitness ? "✅" : "❌")")
        print("   - Breakfast: \(analysis.hasBreakfast ? "✅" : "❌")")
        print("   - Lunch: \(analysis.hasLunch ? "✅" : "❌")")
        print("   - Dinner: \(analysis.hasDinner ? "✅" : "❌")")
        print("💡 Will generate: \(analysis.missingTasks.joined(separator: ", "))")
        
        // Generate tasks one by one
        aiTaskGenerator.generateMissingTasksSequentially(
            missing: analysis.missingTasks,
            for: selectedDate,
            userProfile: userProfile,
            onEachTask: { aiTask in
                // Create task immediately as each one is generated
                DispatchQueue.main.async {
                    self.createTaskFromAIGenerated(aiTask)
                    print("✅ Generated and added: \(aiTask.title)")
                    // Animation is triggered by setting newlyAddedTaskId in createTaskFromAIGenerated
                    // It will auto-clear after 1.5 seconds via TaskListView's onChange
                }
            },
            onComplete: {
                DispatchQueue.main.async {
                    self.showAITaskLoading = false
                    print("✅ All AI tasks generation completed")
                }
            }
        )
    }
    
    struct TaskAnalysis {
        let hasFitness: Bool
        let hasBreakfast: Bool
        let hasLunch: Bool
        let hasDinner: Bool
        let missingTasks: [String] // ["fitness", "breakfast", "lunch", "dinner"]
    }
    
    /// Analyze existing tasks to determine what's missing
    private func analyzeExistingTasks(_ tasks: [TaskItem]) -> TaskAnalysis {
        print("🔍 Analyzing \(tasks.count) existing tasks:")
        for (index, task) in tasks.enumerated() {
            let categoryStr = task.category == .fitness ? "fitness" : task.category == .diet ? "diet" : "others"
            print("   \(index + 1). [\(categoryStr)] \(task.title) at \(task.time)")
        }
        
        let hasFitness = tasks.contains { $0.category == .fitness }
        
        // Check for meals by time or keywords
        let hasBreakfast = tasks.contains { task in
            task.category == .diet && (
                (task.time.contains("AM") && !task.time.contains("12:")) ||
                task.title.lowercased().contains("breakfast")
            )
        }
        
        let hasLunch = tasks.contains { task in
            task.category == .diet && (
                (task.time.contains("12:") || task.time.contains("01:") || task.time.contains("02:")) ||
                task.title.lowercased().contains("lunch")
            )
        }
        
        let hasDinner = tasks.contains { task in
            task.category == .diet && (
                (task.time.contains("PM") && !task.time.contains("12:") && !task.time.contains("01:") && !task.time.contains("02:")) ||
                task.title.lowercased().contains("dinner")
            )
        }
        
        // Build list of missing tasks
        var missingTasks: [String] = []
        if !hasFitness {
            missingTasks.append("fitness")
        }
        if !hasBreakfast {
            missingTasks.append("breakfast")
        }
        if !hasLunch {
            missingTasks.append("lunch")
        }
        if !hasDinner {
            missingTasks.append("dinner")
        }
        
        // If all tasks are present, add a snack as bonus
        if missingTasks.isEmpty {
            missingTasks.append("snack")
        }
        
        return TaskAnalysis(
            hasFitness: hasFitness,
            hasBreakfast: hasBreakfast,
            hasLunch: hasLunch,
            hasDinner: hasDinner,
            missingTasks: missingTasks
        )
    }
    
    /// Create TaskItem from AI Generated Task
    private func createTaskFromAIGenerated(_ aiTask: AIGeneratedTask) {
        let task: TaskItem
        
        switch aiTask.type {
        case .workout:
            // Create workout task
            let exerciseNames = aiTask.exercises.map { $0.name }
            let subtitle = exerciseNames.prefix(3).joined(separator: ", ") + (exerciseNames.count > 3 ? "..." : "")
            
            // Create more detailed description
            let description = """
            Total Duration: \(aiTask.totalDuration) min
            Exercises: \(aiTask.exercises.count)
            Estimated Calories: \(aiTask.totalCalories) cal
            
            Workout Details:
            """ + "\n" + aiTask.exercises.map { exercise in
                "• \(exercise.name): \(exercise.sets) sets × \(exercise.reps) reps, \(exercise.restSec)s rest (~\(exercise.calories) cal)"
            }.joined(separator: "\n")
            
            let fitnessEntries = aiTask.exercises.map { exercise in
                AddTaskView.FitnessEntry(
                    exercise: nil,
                    customName: exercise.name,
                    minutesInt: exercise.durationMin,
                    caloriesText: String(exercise.calories)
                )
            }
            
            // Use random time for AI tasks (morning workout)
            let startTime = "09:00 AM"
            let calendar = Calendar.current
            let startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: aiTask.date) ?? aiTask.date
            let endDate = calendar.date(byAdding: .minute, value: aiTask.totalDuration, to: startDate) ?? startDate
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "hh:mm a"
            let endTime = timeFormatter.string(from: endDate)
            
            task = TaskItem(
                title: aiTask.title,
                subtitle: subtitle,
                time: startTime,
                timeDate: startDate,
                endTime: endTime,
                meta: "\(aiTask.totalDuration) min • \(aiTask.exercises.count) exercises • -\(aiTask.totalCalories) cal",
                isDone: false,
                emphasisHex: "8B5CF6",
                category: .fitness,
                dietEntries: [],
                fitnessEntries: fitnessEntries,
                isAIGenerated: true
            )
            
            print("✅ Created AI workout task: \(task.title)")
            
        case .nutrition:
            // Create nutrition task for single meal
            let meal = aiTask.meals.first!
            let foodNames = meal.foodItems.map { $0.name }
            let subtitle = foodNames.prefix(3).joined(separator: ", ") + (foodNames.count > 3 ? "..." : "")
            
            // Create more detailed description
            let description = """
            Meal: \(meal.name)
            Total Calories: \(aiTask.totalCalories) kcal
            Items: \(meal.foodItems.count)
            
            Food Items:
            """ + "\n" + meal.foodItems.map { "• \($0.name) (~\($0.calories) cal)" }.joined(separator: "\n")
            
            let dietEntries = meal.foodItems.map { foodItem in
                // Create as custom food item
                AddTaskView.DietEntry(
                    food: nil,
                    customName: foodItem.name,
                    caloriesText: String(foodItem.calories)
                )
            }
            
            // Use meal time
            let startTime = meal.time
            let calendar = Calendar.current
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "hh:mm a"
            let startDate = timeFormatter.date(from: startTime).flatMap { parsedTime in
                let components = calendar.dateComponents([.hour, .minute], from: parsedTime)
                return calendar.date(bySettingHour: components.hour ?? 8, minute: components.minute ?? 0, second: 0, of: aiTask.date)
            } ?? aiTask.date
            
            task = TaskItem(
                title: aiTask.title,
                subtitle: subtitle,
                time: startTime,
                timeDate: startDate,
                endTime: nil,
                meta: "\(aiTask.totalCalories)kcal",
                isDone: false,
                emphasisHex: "10B981",
                category: .diet,
                dietEntries: dietEntries,
                fitnessEntries: [],
                isAIGenerated: true
            )
            
            print("✅ Created AI nutrition task: \(task.title)")
        }
        
        // Add task to list
        addTask(task)
        
        // Trigger animation for newly added task
        newlyAddedTaskId = task.id
        
        // Show success feedback
        print("🎉 AI Task added successfully!")
    }
    
    // MARK: - Notification Handling
    
    /// Setup notification observer for workout/nutrition task creation from AI
    private func setupWorkoutTaskNotification() {
        print("🔔 MainPageView: Setting up workout task notification observer")
        
        // Remove existing observer first to prevent duplicates
        if let existingObserver = notificationObserver {
            print("   🗑️ Removing existing observer")
            NotificationCenter.default.removeObserver(existingObserver)
            notificationObserver = nil
        }
        
        // Add new observer and store the token
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CreateWorkoutTask"),
            object: nil,
            queue: .main
        ) { notification in
            print("📬 ========== MainPageView: RECEIVED NOTIFICATION ==========")
            print("   Notification object: \(String(describing: notification.object))")
            print("   User info keys: \(notification.userInfo?.keys.map { String(describing: $0) } ?? [])")
            
            guard let userInfo = notification.userInfo,
                  let dateString = userInfo["date"] as? String,
                  let goal = userInfo["goal"] as? String else {
                print("⚠️ MainPageView: Missing required userInfo data")
                return
            }
            
            // Check if this is a nutrition plan
            let isNutrition = userInfo["isNutrition"] as? Bool ?? false
            print("   Task type: \(isNutrition ? "Nutrition" : "Workout")")
            
            // Parse date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            guard let date = dateFormatter.date(from: dateString) else { return }
            
            // Get time (from user or default)
            let timeString = userInfo["time"] as? String ?? (isNutrition ? "08:00 AM" : "09:00 AM")
            
            // Get description (full details)
            let description = userInfo["description"] as? String ?? ""
            
            print("   Description preview: \(description.prefix(100))...")
            
            // Create task title and meta based on type
            let taskTitle: String
            let meta: String
            let subtitle: String
            let emphasisColor: String
            let category: AddTaskView.Category
            
            // Create entries arrays for both task types
            var fitnessEntries: [AddTaskView.FitnessEntry] = []
            var dietEntries: [AddTaskView.DietEntry] = []  // ✅ Define at top level
            var totalCalories = 0
            var durationMinutes = 0  // Will be calculated based on type
            
            if isNutrition {
                // Nutrition task - create DietEntries for each food item
                let calories = userInfo["calories"] as? Int ?? 2000
                
                // Use mealName if provided, otherwise use generic title
                if let mealName = userInfo["mealName"] as? String {
                    taskTitle = mealName // "Breakfast", "Lunch", "Dinner", "Snack"
                } else {
                    taskTitle = "🥗 AI Generated Nutrition Plan"
                }
                
                // ✅ Create DietEntry for each food item (similar to FitnessEntry for exercises)
                let foodItemsData = userInfo["foodItems"] as? [[String: Any]] ?? []
                
                for foodData in foodItemsData {
                    guard let name = foodData["name"] as? String else { continue }
                    let foodCalories = foodData["calories"] as? Int ?? 0
                    
                    // Create as custom food item (not from standard library)
                    let entry = AddTaskView.DietEntry(
                        food: nil,  // Not from standard library
                        customName: name,
                        caloriesText: String(foodCalories)
                    )
                    dietEntries.append(entry)
                }
                
                // Extract food names for subtitle
                let foodNames = foodItemsData.compactMap { $0["name"] as? String }
                subtitle = foodNames.prefix(3).joined(separator: ", ") + (foodNames.count > 3 ? "..." : "")
                
                meta = "\(calories)kcal"
                emphasisColor = "10B981"  // Green for nutrition
                category = .diet
                totalCalories = calories
                
                // Nutrition doesn't have duration
                let durationString = userInfo["duration"] as? String ?? "0"
                durationMinutes = Int(durationString) ?? 0
            } else {
                // Workout task - create FitnessEntries
                let exercisesData = userInfo["exercises"] as? [[String: Any]] ?? []
                let theme = userInfo["theme"] as? String ?? "Workout"
                totalCalories = userInfo["totalCalories"] as? Int ?? 0
                
                // Create FitnessEntry for each exercise
                for exerciseData in exercisesData {
                    guard let name = exerciseData["name"] as? String else { continue }
                    let durationMin = exerciseData["durationMin"] as? Int ?? 5
                    let calories = exerciseData["calories"] as? Int ?? 30
                    
                    // Create as custom exercise (not from standard library)
                    let entry = AddTaskView.FitnessEntry(
                        exercise: nil,  // Not from standard library
                        customName: name,
                        minutesInt: durationMin,
                        caloriesText: String(calories)
                    )
                    fitnessEntries.append(entry)
                }
                
                // Set title with theme (no "AI-" prefix, will use AI badge instead)
                var cleanTheme = theme
                    .replacingOccurrences(of: " Workout", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: " Training", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: " Session", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                
                // If theme is too long or empty, use default
                if cleanTheme.isEmpty || cleanTheme.lowercased() == "workout" {
                    cleanTheme = "Fitness"
                } else if cleanTheme.count > 30 {
                    cleanTheme = String(cleanTheme.prefix(30))
                }
                
                taskTitle = cleanTheme  // No "AI-" prefix, use isAIGenerated flag instead
                
                // Subtitle shows first 3 exercises (consistent with createTaskFromAIGenerated)
                let exerciseNames = exercisesData.compactMap { $0["name"] as? String }
                subtitle = exerciseNames.prefix(3).joined(separator: ", ") + (exerciseNames.count > 3 ? "..." : "")
                
                // Calculate pure workout time from individual exercises
                let pureWorkoutTime = exercisesData.reduce(0) { sum, exercise in
                    sum + (exercise["durationMin"] as? Int ?? 0)
                }
                
                // Total duration already includes warm-up/cool-down (calculated in InsightPageView)
                let actualDuration = userInfo["totalDuration"] as? Int ?? pureWorkoutTime
                
                print("   Pure workout time: \(pureWorkoutTime) min")
                print("   Total duration (with warm-up/transitions): \(actualDuration) min")
                print("   Exercises: \(exercisesData.count)")
                
                // Meta shows total duration, exercises, and calories (negative for burned calories)
                meta = "\(actualDuration) min • \(exerciseNames.count) exercises • -\(totalCalories) cal"
                emphasisColor = "8B5CF6"  // Purple for workout
                category = .fitness
                
                // Use actual duration for endTime calculation
                durationMinutes = actualDuration
            }
            
            // Parse time and calculate end time
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "hh:mm a"
            
            var startDate: Date
            var endDate: Date
            var displayTime: String
            var displayEndTime: String
            
            if let parsedTime = timeFormatter.date(from: timeString) {
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
                
                if let hour = timeComponents.hour, let minute = timeComponents.minute {
                    startDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
                    if durationMinutes > 0 {
                        endDate = calendar.date(byAdding: .minute, value: durationMinutes, to: startDate) ?? startDate
                    } else {
                        endDate = calendar.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
                    }
                    
                    displayTime = timeFormatter.string(from: startDate)
                    displayEndTime = timeFormatter.string(from: endDate)
                } else {
                    let defaultHour = isNutrition ? 8 : 9
                    startDate = calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: date) ?? date
                    if durationMinutes > 0 {
                        endDate = calendar.date(byAdding: .minute, value: durationMinutes, to: startDate) ?? startDate
                    } else {
                        endDate = calendar.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
                    }
                    displayTime = isNutrition ? "08:00 AM" : "09:00 AM"
                    displayEndTime = timeFormatter.string(from: endDate)
                }
            } else {
                let calendar = Calendar.current
                let defaultHour = isNutrition ? 8 : 9
                startDate = calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: date) ?? date
                if durationMinutes > 0 {
                    endDate = calendar.date(byAdding: .minute, value: durationMinutes, to: startDate) ?? startDate
                } else {
                    endDate = calendar.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
                }
                displayTime = isNutrition ? "08:00 AM" : "09:00 AM"
                displayEndTime = timeFormatter.string(from: endDate)
            }
            
            // Check if task is AI-generated (from InsightPageView or AI Generate button)
            let isAIGenerated = userInfo["isAIGenerated"] as? Bool ?? false
            
            // Create task with detailed entries (both diet and fitness)
            let task = TaskItem(
                title: taskTitle,
                subtitle: subtitle,
                time: displayTime,
                timeDate: startDate,
                endTime: displayEndTime,
                meta: meta,
                isDone: false,
                emphasisHex: emphasisColor,
                category: category,
                dietEntries: dietEntries,  // ✅ Use created diet entries
                fitnessEntries: fitnessEntries,
                isAIGenerated: isAIGenerated
            )
            
            // Add to tasks
            self.addTask(task)
            
            let taskType = isNutrition ? "Nutrition" : "Workout"
            print("✅ MainPageView: \(taskType) task created - \(taskTitle) at \(displayTime)")
            print("   Exercises: \(fitnessEntries.count), Total Calories: \(totalCalories)kcal")
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
        return tasksByDate[dateKey]?.sorted { $0.timeDate < $1.timeDate } ?? []
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
                    case .failure(let error):
                        print("❌ MainPageView: Failed to delete task from Firebase - Title: \"\(task.title)\", Error: \(error.localizedDescription)")
                    }
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
                            showAITaskLoading: $showAITaskLoading
                        )
                            .padding(.horizontal, 24)
                        
                        TaskListView(
                            tasks: filteredTasks,
                            navigationPath: $navigationPath,
                            newlyAddedTaskId: $newlyAddedTaskId,
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
            setupListenerIfNeeded(for: selectedDate)
            setupWorkoutTaskNotification()
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
            
            // Remove notification observer to prevent memory leaks and duplicates
            if let observer = notificationObserver {
                print("🔕 MainPageView: Removing workout task notification observer")
                NotificationCenter.default.removeObserver(observer)
                notificationObserver = nil
            }
            
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
           
           // CRITICAL FIX #8: Update cache without triggering additional Firebase operations
           // Use a flag or separate method that doesn't trigger listeners
           Task.detached(priority: .background) {
               self.cacheService.saveTasksForDate(tasks, date: normalizedDate, userId: userId)
           }
           
           // Update in-memory state on main thread
           DispatchQueue.main.async {
               self.tasksByDate[normalizedDate] = tasks
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
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        
        // Defer settlement for the current day until midnight
        if calendar.isDate(normalizedDate, inSameDayAs: today) {
            print("⏳ MainPageView: Deferring day completion settlement until midnight for \(normalizedDate)")
            return
        }
        let dayTasks = tasks(for: normalizedDate)
        // Only check when there's at least one task that day
        guard !dayTasks.isEmpty else {
            progressService.markDayAsNotCompleted(userId: userId, date: normalizedDate, modelContext: modelContext)
            return
        }
        let isCompleted = progressService.isDayCompleted(tasks: dayTasks, date: normalizedDate)
        if isCompleted {
            progressService.markDayAsCompleted(userId: userId, date: normalizedDate, modelContext: modelContext)
        } else {
            progressService.markDayAsNotCompleted(userId: userId, date: normalizedDate, modelContext: modelContext)
        }
    }

    /// Schedule a one-shot timer to settle today's completion at the next midnight
    private func scheduleMidnightSettlement() {
        cancelMidnightSettlement()
        let calendar = Calendar.current
        // Next midnight start of tomorrow
        guard let nextMidnight = calendar.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime, direction: .forward) else { return }
        let interval = max(1, nextMidnight.timeIntervalSinceNow)
        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            let today = Date()
            let normalizedToday = calendar.startOfDay(for: today.addingTimeInterval(-60)) // small backoff
            // Evaluate settlement for the day that just ended
            self.evaluateAndSyncDayCompletion(for: normalizedToday)
            // Reschedule for the following midnight
            self.scheduleMidnightSettlement()
        }
        RunLoop.main.add(midnightTimer!, forMode: .common)
        print("🕛 MainPageView: Scheduled midnight settlement at \(nextMidnight)")
    }

    /// Cancel any scheduled midnight settlement timer
    private func cancelMidnightSettlement() {
        midnightTimer?.invalidate()
        midnightTimer = nil
    }
}

// MARK: - Navigation Destination Type
private enum AddTaskDestination: Hashable {
    case addTask
}

private enum TaskDetailDestination: Hashable {
    case detail(taskId: UUID)
    
    var taskId: UUID? {
        if case .detail(let id) = self { return id }
        return nil
    }
}

private enum ProfileDestination: Hashable {
    case profile
}

private struct TopHeaderView: View {
    @Binding var isShowingCalendar: Bool
    @Binding var isShowingProfile: Bool
    let selectedDate: Date
    @EnvironmentObject var userProfileService: UserProfileService
    
    private var fallbackAvatar: some View {
        Text("A")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color(hexString: "101828"))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Button(action: {
                withAnimation {
                    isShowingProfile = true
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle().stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
                        )
                    
                    // Display user avatar or default
                    Group {
                        if let urlString = userProfileService.profileImageURL, !urlString.isEmpty {
                            if urlString.hasPrefix("http") || urlString.hasPrefix("https") {
                                if let url = URL(string: urlString) {
                                    // Use cached image with placeholder
                                    CachedAsyncImage(url: url) {
                                        // Placeholder: show default avatar or fallback
                                        if let name = userProfileService.avatarName, !name.isEmpty, UIImage(named: name) != nil {
                                            Image(name)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                        } else {
                                            fallbackAvatar
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                        }
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                } else {
                                    fallbackAvatar
                                }
                            } else {
                                fallbackAvatar
                            }
                        } else if let name = userProfileService.avatarName, !name.isEmpty, UIImage(named: name) != nil {
                            Image(name)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            fallbackAvatar
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // Centered date look
            Text(Self.formattedDate(selectedDate: selectedDate))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hexString: "101828"))

            Spacer()

            // Calendar
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    isShowingCalendar = true
                }
            } label: {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 40, height: 40)
                    .overlay(
                        CalendarIcon(strokeColor: .white, size: 20)
                    )
            }
        }
    }

    private static func formattedDate(selectedDate: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selected = calendar.startOfDay(for: selectedDate)
        
        if calendar.isDate(selected, inSameDayAs: today) {
            return "Today"
        }
        
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("MMMM d")
        df.locale = .current
        return df.string(from: selectedDate)
    }
}

// Displays Completed Diet and Fitness Tasks (Should factor out to Components.swift)
private struct CombinedStatsCard: View {
    let tasks: [MainPageView.TaskItem]
    
    private var completedCount: Int {
        tasks.filter { $0.isDone }.count
    }
    
    private var totalCount: Int {
        tasks.count
    }
    
    private var dietCount: Int {
        tasks.filter { $0.category == .diet && !$0.isDone }.count
    }
    
    private var fitnessCount: Int {
        tasks.filter { $0.category == .fitness && !$0.isDone }.count
    }
    
    private var totalCalories: Int {
        tasks.filter { $0.isDone }.reduce(0) { total, task in
            total + task.totalCalories
        }
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            .overlay(
                HStack(spacing: 0) {
                    StatItem(value: "\(completedCount)/\(totalCount)", label: "Completed", tint: Color(hexString: "101828"))
                    StatItem(value: "\(dietCount)", label: "Diet", tint: Color(hexString: "00A63E"))
                    StatItem(value: "\(fitnessCount)", label: "Fitness", tint: Color(hexString: "155DFC"))
                    StatItem(value: "\(totalCalories)", label: "Calories", tint: Color(hexString: "4ECDC4"))
                }
                .frame(maxWidth: .infinity)
                .padding(12)
            )
            .frame(width: 327, height: 92)
    }


   // Formats the Text for statistics
    private struct StatItem: View {
        let value: String
        let label: String
        let tint: Color

        var body: some View {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(tint)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hexString: "6A7282"))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct TasksHeader: View {
    @Binding var navigationPath: NavigationPath
    let selectedDate: Date
    let onAITaskTap: () -> Void
    @Binding var showAITaskLoading: Bool
    
    private var headerText: String {

        return "Modo's Tasks"
    }

    var body: some View {
        ZStack {
            // Center title
            Text(headerText)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hexString: "101828"))
            
            // Left and right buttons
            HStack {
                // AI Tasks button (left side with gradient)
                Button(action: {
                    onAITaskTap()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text(showAITaskLoading ? "..." : "AI")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .frame(width: 60, height: 36)
                    .background(
                        LinearGradient(
                            colors: [Color(hexString: "8B5CF6"), Color(hexString: "6366F1")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color(hexString: "8B5CF6").opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                Spacer()
                
                // Add Task button (right side, minimalist)
                Button(action: {
                    navigationPath.append(AddTaskDestination.addTask)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Add")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .frame(width: 70, height: 36)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .frame(height: 60)
        .background(Color.white)
    }
}

private struct TaskRowCard: View {
    let title: String
    let subtitle: String
    let time: String
    let endTime: String?
    let meta: String
    @Binding var isDone: Bool
    let emphasis: Color
    let category: AddTaskView.Category
    let isAIGenerated: Bool
    @State private var checkboxScale: CGFloat = 1.0
    @State private var strikethroughProgress: CGFloat = 0.0

    init(title: String, subtitle: String, time: String, endTime: String?, meta: String, isDone: Binding<Bool>, emphasis: Color, category: AddTaskView.Category, isAIGenerated: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.time = time
        self.endTime = endTime
        self.meta = meta
        self._isDone = isDone
        self.emphasis = emphasis
        self.category = category
        self.isAIGenerated = isAIGenerated
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox button
            Button {
                let willBeDone = !isDone
                
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    isDone.toggle()
                    triggerCompletionHaptic()
                }
                // Checkbox bounce animation
                withAnimation(.easeOut(duration: 0.15)) {
                    checkboxScale = 1.3
                }
                withAnimation(.easeIn(duration: 0.15).delay(0.15)) {
                    checkboxScale = 1.0
                }
                // Strikethrough animation
                if willBeDone {
                    withAnimation(.easeInOut(duration: 0.4).delay(0.1)) {
                        strikethroughProgress = 1.0
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        strikethroughProgress = 0.0
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(isDone ? emphasis : Color.white)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(Color(hexString: "E5E7EB"), lineWidth: isDone ? 0 : 1)
                        )
                        .scaleEffect(checkboxScale)
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(checkboxScale)
                    }
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Text(title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isDone ? emphasis : Color(hexString: "101828"))
                            
                            // Animated strikethrough line
                            if strikethroughProgress > 0 {
                                Path { path in
                                    let y = geometry.size.height / 2
                                    let startX: CGFloat = 0
                                    let endX = geometry.size.width * strikethroughProgress
                                    path.move(to: CGPoint(x: startX, y: y))
                                    path.addLine(to: CGPoint(x: endX, y: y))
                                }
                                .stroke(
                                    emphasis,
                                    style: StrokeStyle(
                                        lineWidth: 2,
                                        lineCap: .round
                                    )
                                )
                                .animation(.none, value: strikethroughProgress)
                            }
                        }
                    }
                    .frame(height: 20) // Fixed height for GeometryReader
                }
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "6A7282"))
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    // Time display
                    if let endTime = endTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text("\(time) - \(endTime)")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(Color(hexString: "364153"))
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text(time)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(Color(hexString: "364153"))
                    }
                    
                    // AI badge if task is AI generated
                    if isAIGenerated {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .semibold))
                            Text("AI")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [Color(hexString: "8B5CF6"), Color(hexString: "6366F1")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                    }
                }
            }
            Spacer(minLength: 0)
            
            // Meta information (calories and exercises for fitness, calories for diet)
            if !meta.isEmpty {
                if category == .fitness {
                    // For fitness tasks, show calories and exercises count in 2 lines
                    VStack(alignment: .trailing, spacing: 4) {
                        // Extract calories from meta (format: "XX min • Y exercises • -ZZZ cal")
                        if let calMatch = meta.range(of: #"-?\d+\s*cal"#, options: .regularExpression) {
                            Text(meta[calMatch].replacingOccurrences(of: " ", with: ""))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(emphasis)
                        }
                        // Extract exercises count
                        if let exMatch = meta.range(of: #"\d+\s*exercises?"#, options: .regularExpression) {
                            Text(meta[exMatch])
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hexString: "6A7282"))
                        }
                    }
                } else {
                    // For diet and other tasks, show meta as is
                    Text(meta)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(emphasis)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isDone ? emphasis.opacity(0.25) : Color(hexString: "E5E7EB"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func triggerCompletionHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}


// Helper view for task detail navigation
private struct TaskDetailDestinationView: View {
    let destination: TaskDetailDestination
    let getTask: (UUID) -> MainPageView.TaskItem?
    let onUpdateTask: (MainPageView.TaskItem, MainPageView.TaskItem) -> Void
    
    var body: some View {
        Group {
            if let taskId = destination.taskId,
               let task = getTask(taskId) {
                DetailPageView(
                    taskId: taskId,
                    getTask: getTask,
                    onUpdateTask: onUpdateTask
                )
            } else {
                // Fallback view if task not found
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hexString: "9CA3AF"))
                    Text("Task not found")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hexString: "6A7282"))
                    Text("The task may have been deleted")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "9CA3AF"))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hexString: "F9FAFB"))
            }
        }
    }
}

private struct TaskListView: View {
    let tasks: [MainPageView.TaskItem]
    @Binding var navigationPath: NavigationPath
    @Binding var newlyAddedTaskId: UUID?
    let onDeleteTask: (MainPageView.TaskItem) -> Void
    let onUpdateTask: (MainPageView.TaskItem) -> Void
    @State private var deletingTaskIds: Set<UUID> = []

    var body: some View {
        Group {
            if tasks.isEmpty {
                ScrollView {
                    EmptyTasksView()
                }
            } else {
                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        List {
                            ForEach(tasks, id: \.id) { task in
                                let isNewlyAdded = newlyAddedTaskId == task.id
                                
                                TaskRowCard(
                                    title: task.title,
                                    subtitle: task.subtitle,
                                    time: task.time,
                                    endTime: task.endTime,
                                    meta: task.meta,
                                    isDone: Binding(
                                        get: { task.isDone },
                                        set: { newValue in
                                            // Create a new TaskItem with updated isDone
                                            let updatedTask = MainPageView.TaskItem(
                                                id: task.id,
                                                title: task.title,
                                                subtitle: task.subtitle,
                                                time: task.time,
                                                timeDate: task.timeDate,
                                                endTime: task.endTime,
                                                meta: task.meta,
                                                isDone: newValue,
                                                emphasisHex: task.emphasisHex,
                                                category: task.category,
                                                dietEntries: task.dietEntries,
                                                fitnessEntries: task.fitnessEntries,
                                                isAIGenerated: task.isAIGenerated
                                            )
                                            onUpdateTask(updatedTask)
                                        }
                                    ),
                                    emphasis: Color(hexString: task.emphasisHex),
                                    category: task.category,
                                    isAIGenerated: task.isAIGenerated
                                )
                                .scaleEffect(isNewlyAdded ? 1.05 : 1.0)
                                .shadow(
                                    color: isNewlyAdded ? Color(hexString: task.emphasisHex).opacity(0.3) : Color.clear,
                                    radius: isNewlyAdded ? 12 : 0,
                                    x: 0,
                                    y: 0
                                )
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isNewlyAdded)
                                .id(task.id)
                                .offset(x: deletingTaskIds.contains(task.id) ? geometry.size.width : 0)
                                .opacity(deletingTaskIds.contains(task.id) ? 0 : 1)
                                .onAppear {
                                    if isNewlyAdded {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                            if newlyAddedTaskId == task.id {
                                                withAnimation(.easeOut(duration: 0.3)) {
                                                    newlyAddedTaskId = nil
                                                }
                                            }
                                        }
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 12, trailing: 24))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteTask(task)
                                    } label: {
                                        Label("Delete", systemImage: "trash.fill")
                                    }
                                    
                                    Button {
                                        navigationPath.append(TaskDetailDestination.detail(taskId: task.id))
                                    } label: {
                                        Label("Detail", systemImage: "info.circle.fill")
                                    }
                                    .tint(Color.gray)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    navigationPath.append(TaskDetailDestination.detail(taskId: task.id))
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        // FIX #1 & #2: Better handling of new task animation
                        .onChange(of: newlyAddedTaskId) { oldId, newId in
                            // Only proceed if we have a new task (not clearing)
                            guard let taskId = newId, newId != oldId else { return }
                            
                            // FIX #2: Longer delay to ensure view hierarchy is ready
                            // This gives the navigation transition time to complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    proxy.scrollTo(taskId, anchor: .center)
                                }
                            }
                            
                            // FIX #1: Always clear the highlight after 1.5 seconds
                            // Independent of other state changes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    newlyAddedTaskId = nil
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func deleteTask(_ task: MainPageView.TaskItem) {
        triggerDeleteHaptic()
        
        // Add to deleting set for animation
        deletingTaskIds.insert(task.id)
        
        // Remove after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDeleteTask(task)
            deletingTaskIds.remove(task.id)
        }
    }
    
    private func triggerDeleteHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }
}

#Preview {
    NavigationStack {
        StatefulPreviewWrapper(Tab.todos) { selection in
            MainPageView(selectedTab: selection)
        }
    }
}
