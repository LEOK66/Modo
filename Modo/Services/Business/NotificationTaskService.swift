import Foundation
import FirebaseAuth

/// Service for handling task creation from notifications (Daily Challenge, Workout, etc.)
struct NotificationTaskService {
    /// Parse activity challenge and convert to calories
    /// Returns: (activityName, caloriesBurned, durationMinutes)
    static func parseActivityChallenge(title: String, targetValue: Int) -> (String, Int, Int) {
        let titleLower = title.lowercased()
        
        // Case 1: Steps challenge (e.g., "Walk 10,000 steps")
        if titleLower.contains("step") {
            let activityName = "Walking"
            // Steps to calories: ~0.04 calories per step (varies by weight, using average)
            let caloriesBurned = Int(Double(targetValue) * 0.04)
            // Steps to minutes: ~100 steps per minute
            let durationMinutes = max(15, min(180, targetValue / 100))
            return (activityName, caloriesBurned, durationMinutes)
        }
        
        // Case 2: Minutes challenge (e.g., "30 minutes of running")
        if titleLower.contains("minute") || titleLower.contains("min") {
            let activityName = extractActivityName(from: title)
            let durationMinutes = targetValue
            // Calories per minute varies by activity intensity (using 7 cal/min as average)
            let caloriesBurned = targetValue * 7
            return (activityName, caloriesBurned, durationMinutes)
        }
        
        // Case 3: Reps/sets challenge (e.g., "50 push-ups", "3 sets of squats")
        if titleLower.contains("rep") || titleLower.contains("set") ||
           titleLower.contains("push") || titleLower.contains("squat") ||
           titleLower.contains("plank") {
            let activityName = extractActivityName(from: title)
            // Estimate 1-2 calories per rep/set
            let caloriesBurned = max(50, targetValue * 2)
            let durationMinutes = max(10, min(60, targetValue / 2))
            return (activityName, caloriesBurned, durationMinutes)
        }
        
        // Case 4: Distance challenge (e.g., "Run 5km")
        if titleLower.contains("km") || titleLower.contains("mile") {
            let activityName = extractActivityName(from: title)
            // Assume ~100 calories per km (or ~60 per mile)
            let caloriesBurned = titleLower.contains("km") ? targetValue * 100 : targetValue * 160
            // Assume ~6 min per km (or 10 min per mile) for moderate pace
            let durationMinutes = titleLower.contains("km") ? targetValue * 6 : targetValue * 10
            return (activityName, caloriesBurned, durationMinutes)
        }
        
        // Default: Assume targetValue is an intensity metric, use moderate estimates
        let activityName = extractActivityName(from: title)
        let caloriesBurned = max(200, min(600, targetValue * 3))
        let durationMinutes = max(20, min(60, 45))
        return (activityName, caloriesBurned, durationMinutes)
    }
    
    /// Extract activity name from title
    private static func extractActivityName(from title: String) -> String {
        // Common activity mappings
        let titleLower = title.lowercased()
        
        if titleLower.contains("walk") || titleLower.contains("step") {
            return "Walking"
        } else if titleLower.contains("run") || titleLower.contains("jog") {
            return "Running"
        } else if titleLower.contains("swim") {
            return "Swimming"
        } else if titleLower.contains("bike") || titleLower.contains("cycl") {
            return "Cycling"
        } else if titleLower.contains("yoga") {
            return "Yoga"
        } else if titleLower.contains("push") {
            return "Push-ups"
        } else if titleLower.contains("squat") {
            return "Squats"
        } else if titleLower.contains("plank") {
            return "Plank"
        } else if titleLower.contains("strength") || titleLower.contains("weight") {
            return "Strength Training"
        } else if titleLower.contains("cardio") {
            return "Cardio"
        } else if titleLower.contains("hiit") {
            return "HIIT"
        }
        
        // If no match, try to extract main noun by removing numbers and units
        let cleaned = title
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "\\d+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "steps", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "minutes", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "reps", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "sets", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned.isEmpty ? "Exercise" : cleaned.capitalized
    }
    
    /// Estimate calories for diet challenges
    static func estimateDietCalories(from title: String, targetValue: Int) -> Int {
        let titleLower = title.lowercased()
        
        // Water has 0 calories
        if titleLower.contains("water") || titleLower.contains("glass") {
            return 0
        }
        
        // Protein (4 cal/g)
        if titleLower.contains("protein") && titleLower.contains("gram") {
            return targetValue * 4
        }
        
        // Vegetables (low calorie)
        if titleLower.contains("vegeta") || titleLower.contains("salad") {
            return targetValue * 30
        }
        
        // Fruit
        if titleLower.contains("fruit") {
            return targetValue * 60
        }
        
        // Default: moderate calorie estimate
        return targetValue * 50
    }
    
    /// Extract food name from diet challenge title
    static func extractFoodName(from title: String) -> String {
        let titleLower = title.lowercased()
        
        if titleLower.contains("water") {
            return "Water"
        } else if titleLower.contains("protein") {
            return "Protein"
        } else if titleLower.contains("vegeta") {
            return "Vegetables"
        } else if titleLower.contains("fruit") {
            return "Fruits"
        } else if titleLower.contains("fiber") {
            return "Fiber"
        }
        
        // Clean up title
        let cleaned = title
            .replacingOccurrences(of: "\\d+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "glass", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "serving", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "gram", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned.isEmpty ? "Healthy Food" : cleaned.capitalized
    }
    
    /// Extract serving unit from diet challenge title
    static func extractServingUnit(from title: String) -> String {
        let titleLower = title.lowercased()
        
        if titleLower.contains("glass") {
            return "glasses"
        } else if titleLower.contains("gram") {
            return "grams"
        } else if titleLower.contains("serving") {
            return "servings"
        } else if titleLower.contains("cup") {
            return "cups"
        }
        
        return "servings"
    }
    
    /// Create TaskItem from daily challenge notification
    static func createTaskFromDailyChallengeNotification(
        userInfo: [AnyHashable: Any],
        taskId: UUID
    ) -> TaskItem? {
        guard let title = userInfo["title"] as? String,
              let subtitle = userInfo["subtitle"] as? String,
              let targetValue = userInfo["targetValue"] as? Int else {
            print("⚠️ Invalid daily challenge notification data")
            return nil
        }
        
        // Get challenge type (default to fitness)
        let typeString = userInfo["type"] as? String ?? "fitness"
        let emoji = userInfo["emoji"] as? String ?? "💪"
        
        // Create daily challenge task
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        let endDate = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now) ?? now
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "hh:mm a"
        let displayTime = timeFormatter.string(from: startDate)
        let displayEndTime = timeFormatter.string(from: endDate)
        
        // Determine category and create appropriate entries based on challenge type
        let category: TaskCategory
        var dietEntries: [DietEntry] = []
        var fitnessEntries: [FitnessEntry] = []
        var meta: String
        
        if typeString == "diet" {
            // Diet challenge - estimate calories if not provided
            category = .diet
            
            // For diet challenges, targetValue might be servings, glasses, grams, etc.
            // Estimate calories based on what the challenge is about
            let estimatedCalories = estimateDietCalories(from: title, targetValue: targetValue)
            let foodName = extractFoodName(from: title)
            
            let dietEntry = DietEntry(
                customName: foodName,
                quantityText: "\(targetValue)",
                unit: extractServingUnit(from: title),
                caloriesText: "\(estimatedCalories)"
            )
            dietEntries = [dietEntry]
            meta = "+\(estimatedCalories)cal"
            
        } else {
            // Fitness challenge - need to convert targetValue to calories
            category = .fitness
            
            // Determine what targetValue represents and calculate calories
            let (activityName, caloriesBurned, durationMinutes) = parseActivityChallenge(
                title: title,
                targetValue: targetValue
            )
            
            let fitnessEntry = FitnessEntry(
                customName: activityName,
                minutesInt: durationMinutes,
                caloriesText: "\(caloriesBurned)"
            )
            fitnessEntries = [fitnessEntry]
            meta = "-\(caloriesBurned)cal"
        }
        
        let task = TaskItem(
            id: taskId,
            title: title,
            subtitle: subtitle,
            time: displayTime,
            timeDate: startDate,
            endTime: displayEndTime,
            meta: meta,
            isDone: false,
            emphasisHex: "8B5CF6", // Purple
            category: category,
            dietEntries: dietEntries,
            fitnessEntries: fitnessEntries,
            isAIGenerated: false,
            isDailyChallenge: true
        )
        
        return task
    }
    
    /// Create TaskItem from workout/nutrition notification
    static func createTaskFromWorkoutNotification(
        userInfo: [AnyHashable: Any],
        dateString: String
    ) -> TaskItem? {
        guard let goal = userInfo["goal"] as? String else {
            print("⚠️ Missing required userInfo data")
            return nil
        }
        
        // Check if this is a nutrition plan
        let isNutrition = userInfo["isNutrition"] as? Bool ?? false
        print("   Task type: \(isNutrition ? "Nutrition" : "Workout")")
        
        // Parse date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: dateString) else { return nil }
        
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
        let category: TaskCategory
        
        // Create entries arrays for both task types
        var fitnessEntries: [FitnessEntry] = []
        var dietEntries: [DietEntry] = []
        var totalCalories = 0
        var durationMinutes = 0 // Will be calculated based on type
        
        if isNutrition {
            // Nutrition task - create DietEntries for each food item
            let calories = userInfo["calories"] as? Int ?? 2000
            
            // Use mealName if provided, otherwise use generic title
            if let mealName = userInfo["mealName"] as? String {
                taskTitle = mealName // "Breakfast", "Lunch", "Dinner", "Snack"
            } else {
                taskTitle = "🥗 AI Generated Nutrition Plan"
            }
            
            // Create DietEntry for each food item
            let foodItemsData = userInfo["foodItems"] as? [[String: Any]] ?? []
            
            for foodData in foodItemsData {
                guard let name = foodData["name"] as? String else { continue }
                let foodCalories = foodData["calories"] as? Int ?? 0
                
                // Create as custom food item (not from standard library)
                let entry = DietEntry(
                    food: nil, // Not from standard library
                    customName: name,
                    caloriesText: String(foodCalories)
                )
                dietEntries.append(entry)
            }
            
            // Extract food names for subtitle
            let foodNames = foodItemsData.compactMap { $0["name"] as? String }
            subtitle = foodNames.prefix(3).joined(separator: ", ") + (foodNames.count > 3 ? "..." : "")
            
            meta = "\(calories)kcal"
            emphasisColor = "10B981" // Green for nutrition
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
                let entry = FitnessEntry(
                    exercise: nil, // Not from standard library
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
            
            taskTitle = cleanTheme // No "AI-" prefix, use isAIGenerated flag instead
            
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
            emphasisColor = "8B5CF6" // Purple for workout
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
            dietEntries: dietEntries,
            fitnessEntries: fitnessEntries,
            isAIGenerated: isAIGenerated
        )
        
        return task
    }
}

