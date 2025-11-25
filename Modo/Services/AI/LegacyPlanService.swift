import Foundation

/// Legacy Plan Generation Service
///
/// Handles old-style AI function calls for plan generation:
/// - generate_workout_plan
/// - generate_nutrition_plan
/// - generate_multi_day_plan
///
/// This service is maintained for backward compatibility.
/// New features should use the CRUD Handler architecture.
class LegacyPlanService {
    
    // MARK: - Dependencies
    
    private let firebaseAIService: FirebaseAIService
    
    init(firebaseAIService: FirebaseAIService = .shared) {
        self.firebaseAIService = firebaseAIService
    }
    
    // MARK: - Constants
    
    private struct DefaultWorkoutParams {
        static let sets = 3
        static let restSecModerate = 60
        static let restSecHigh = 90
        static let restSecLow = 45
        static let rpeModerate = 7
        static let rpeHigh = 8
        static let rpeLow = 5
    }
    
    // MARK: - Public API
    
    /// Handle workout plan function call
    /// - Parameters:
    ///   - data: JSON data from function call
    ///   - userProfile: User profile for personalization
    ///   - completion: Called with formatted message content or error
    func handleWorkoutPlan(
        data: Data,
        userProfile: UserProfile?,
        completion: @escaping (Result<PlanResult, Error>) -> Void
    ) {
        do {
            let decoder = JSONDecoder()
            let functionResponse = try decoder.decode(WorkoutPlanFunctionResponse.self, from: data)
            
            // Validate exercises
            guard let exercises = functionResponse.exercises, !exercises.isEmpty else {
                print("⚠️ LegacyPlanService: No exercises in workout plan")
                // Fallback handled by caller
                completion(.failure(LegacyPlanError.emptyPlan))
                return
            }
            
            // Convert to WorkoutPlanData
            let convertedExercises = exercises.map { exercise in
                WorkoutPlanData.Exercise(
                    name: exercise.name,
                    sets: exercise.sets,
                    reps: exercise.reps,
                    restSec: exercise.restSec,
                    durationMin: exercise.durationMin,
                    calories: exercise.calories
                )
            }
            
            // Use local calculation if AI didn't return calorie target
            let kcalTarget = functionResponse.dailyKcalTarget ?? calculateDailyCalories(userProfile: userProfile)
            
            let plan = WorkoutPlanData(
                date: functionResponse.date,
                goal: functionResponse.goal,
                dailyKcalTarget: kcalTarget,
                exercises: convertedExercises,
                notes: functionResponse.notes
            )
            
            let content = "Here's your personalized workout plan 💪:\n\(formatDate(plan.date)) – \(plan.goal)"
            
            let result = PlanResult(
                content: content,
                messageType: "workout_plan",
                workoutPlan: plan,
                nutritionPlan: nil,
                multiDayPlan: nil
            )
            
            print("✅ LegacyPlanService: Successfully generated workout plan")
            completion(.success(result))
            
        } catch {
            print("❌ LegacyPlanService: Failed to decode workout plan - \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("   Raw JSON: \(jsonString)")
            }
            completion(.failure(error))
        }
    }
    
    /// Handle nutrition plan function call
    /// - Parameters:
    ///   - data: JSON data from function call
    ///   - userProfile: User profile for personalization
    ///   - completion: Called with formatted message content or error
    func handleNutritionPlan(
        data: Data,
        userProfile: UserProfile?,
        completion: @escaping (Result<PlanResult, Error>) -> Void
    ) {
        do {
            let decoder = JSONDecoder()
            let functionResponse = try decoder.decode(NutritionPlanFunctionResponse.self, from: data)
            
            print("✅ LegacyPlanService: Successfully decoded nutrition plan with \(functionResponse.meals.count) meals")
            print("   Date: \(functionResponse.date)")
            print("   Goal: \(functionResponse.goal)")
            
            // Convert to NutritionPlanData
            let convertedMeals = functionResponse.meals.map { meal in
                let totalCalories = meal.foods.reduce(0) { $0 + $1.calories }
                let totalProtein = meal.foods.reduce(0.0) { $0 + ($1.protein ?? 0) }
                let totalCarbs = meal.foods.reduce(0.0) { $0 + ($1.carbs ?? 0) }
                let totalFat = meal.foods.reduce(0.0) { $0 + ($1.fat ?? 0) }
                
                print("   Meal: \(meal.mealType) - \(totalCalories)kcal")
                
                // Convert foods to detailed Food struct
                let convertedFoods = meal.foods.map { food in
                    NutritionPlanData.Food(
                        name: food.name,
                        portion: food.portion,
                        calories: food.calories
                    )
                }
                
                return NutritionPlanData.Meal(
                    name: meal.mealType.capitalized,
                    time: meal.time ?? getDefaultMealTime(for: meal.mealType),
                    foods: convertedFoods,
                    calories: totalCalories,
                    protein: totalProtein,
                    carbs: totalCarbs,
                    fat: totalFat
                )
            }
            
            // Calculate daily totals
            let dailyCalories = functionResponse.dailyTotals?.calories ?? convertedMeals.reduce(0) { $0 + $1.calories }
            
            let plan = NutritionPlanData(
                date: functionResponse.date,
                goal: functionResponse.goal,
                dailyKcalTarget: dailyCalories,
                meals: convertedMeals,
                notes: nil
            )
            
            print("   Created NutritionPlanData with \(plan.meals.count) meals")
            
            let content = "Here's your personalized nutrition plan 🍽️:\n\(formatDate(plan.date)) – \(plan.goal)"
            
            let result = PlanResult(
                content: content,
                messageType: "nutrition_plan",
                workoutPlan: nil,
                nutritionPlan: plan,
                multiDayPlan: nil
            )
            
            print("✅ LegacyPlanService: Successfully generated nutrition plan")
            completion(.success(result))
            
        } catch {
            print("❌ LegacyPlanService: Failed to decode nutrition plan - \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("   Raw JSON: \(jsonString)")
            }
            completion(.failure(error))
        }
    }
    
    /// Handle multi-day plan function call
    /// - Parameters:
    ///   - data: JSON data from function call
    ///   - userProfile: User profile for personalization
    ///   - completion: Called with formatted message content or error
    func handleMultiDayPlan(
        data: Data,
        userProfile: UserProfile?,
        completion: @escaping (Result<PlanResult, Error>) -> Void
    ) {
        do {
            let decoder = JSONDecoder()
            let functionResponse = try decoder.decode(MultiDayPlanFunctionResponse.self, from: data)
            
            print("✅ LegacyPlanService: Successfully decoded multi-day plan with \(functionResponse.days.count) days")
            print("   Type: \(functionResponse.planType)")
            print("   Date range: \(functionResponse.startDate) to \(functionResponse.endDate)")
            
            // Convert to MultiDayPlanData
            let convertedDays = functionResponse.days.map { day in
                var workoutPlan: WorkoutPlanData? = nil
                var nutritionPlan: NutritionPlanData? = nil
                
                // Convert workout if present
                if let workout = day.workout {
                    let convertedExercises = workout.exercises.map { exercise in
                        WorkoutPlanData.Exercise(
                            name: exercise.name,
                            sets: exercise.sets,
                            reps: exercise.reps,
                            restSec: exercise.restSec,
                            durationMin: exercise.durationMin,
                            calories: exercise.calories
                        )
                    }
                    
                    workoutPlan = WorkoutPlanData(
                        date: day.date,
                        goal: workout.goal,
                        dailyKcalTarget: workout.dailyKcalTarget,
                        exercises: convertedExercises,
                        notes: workout.notes
                    )
                }
                
                // Convert nutrition if present
                if let nutrition = day.nutrition {
                    let convertedMeals = nutrition.meals.map { meal in
                        // Convert foods to detailed Food struct
                        let convertedFoods = meal.foods.map { food in
                            NutritionPlanData.Food(
                                name: food.name,
                                portion: food.portion,
                                calories: food.calories
                            )
                        }
                        
                        return NutritionPlanData.Meal(
                            name: meal.mealType.capitalized,
                            time: meal.time,
                            foods: convertedFoods,
                            calories: meal.calories,
                            protein: meal.protein,
                            carbs: meal.carbs,
                            fat: meal.fat
                        )
                    }
                    
                    let dailyCalories = nutrition.dailyTotals?.calories ?? convertedMeals.reduce(0) { $0 + $1.calories }
                    
                    nutritionPlan = NutritionPlanData(
                        date: day.date,
                        goal: nutrition.goal,
                        dailyKcalTarget: dailyCalories,
                        meals: convertedMeals,
                        notes: nil
                    )
                }
                
                return MultiDayPlanData.DayPlan(
                    date: day.date,
                    dayName: day.dayName,
                    workout: workoutPlan,
                    nutrition: nutritionPlan
                )
            }
            
            let plan = MultiDayPlanData(
                startDate: functionResponse.startDate,
                endDate: functionResponse.endDate,
                planType: functionResponse.planType,
                days: convertedDays,
                notes: functionResponse.notes
            )
            
            print("   Created MultiDayPlanData with \(plan.days.count) days")
            
            let planTypeText = functionResponse.planType == "both" ? "workout & nutrition" : functionResponse.planType
            let content = "Here's your \(plan.days.count)-day \(planTypeText) plan 📅"
            
            let result = PlanResult(
                content: content,
                messageType: "multi_day_plan",
                workoutPlan: nil,
                nutritionPlan: nil,
                multiDayPlan: plan
            )
            
            print("✅ LegacyPlanService: Successfully generated multi-day plan")
            completion(.success(result))
            
        } catch {
            print("❌ LegacyPlanService: Failed to decode multi-day plan - \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("   Raw JSON (first 500 chars): \(jsonString.prefix(500))")
                print("   Raw JSON length: \(jsonString.count) characters")
                
                // Check if JSON was truncated
                if !jsonString.hasSuffix("}") {
                    print("⚠️ JSON appears to be truncated (doesn't end with })")
                    completion(.failure(LegacyPlanError.truncatedResponse))
                    return
                }
            }
            completion(.failure(error))
        }
    }
    
    /// Create nutrition tasks from function response
    /// - Parameter nutritionPlan: Nutrition plan function response
    func createNutritionTasks(_ nutritionPlan: NutritionPlanFunctionResponse) {
        for meal in nutritionPlan.meals {
            let mealTime = meal.time ?? getDefaultMealTime(for: meal.mealType)
            
            // Convert foods to dictionary
            let foodsData = meal.foods.map { food -> [String: Any] in
                var foodDict: [String: Any] = [
                    "name": food.name,
                    "portion": food.portion,
                    "calories": food.calories
                ]
                if let protein = food.protein {
                    foodDict["protein"] = protein
                }
                if let carbs = food.carbs {
                    foodDict["carbs"] = carbs
                }
                if let fat = food.fat {
                    foodDict["fat"] = fat
                }
                return foodDict
            }
            
            // Calculate total calories for the meal
            let totalCalories = meal.foods.reduce(0) { $0 + $1.calories }
            
            let userInfo: [String: Any] = [
                "date": nutritionPlan.date,
                "time": mealTime,
                "theme": "Nutrition",
                "mealType": meal.mealType.capitalized,
                "foods": foodsData,
                "totalCalories": totalCalories,
                "isNutrition": true,
                "isAIGenerated": true
            ]
            
            NotificationCenter.default.post(
                name: NSNotification.Name("CreateNutritionTask"),
                object: nil,
                userInfo: userInfo
            )
        }
        
        print("✅ LegacyPlanService: Posted notifications for \(nutritionPlan.meals.count) nutrition tasks")
    }
    
    // MARK: - Private Helpers
    
    private func getDefaultMealTime(for mealType: String) -> String {
        switch mealType.lowercased() {
        case "breakfast":
            return "08:00 AM"
        case "lunch":
            return "12:00 PM"
        case "dinner":
            return "06:00 PM"
        case "snack":
            return "03:00 PM"
        default:
            return "12:00 PM"
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
        
        return dateString
    }
    
    private func calculateDailyCalories(userProfile: UserProfile?) -> Int {
        guard let profile = userProfile,
              let weight = profile.weightValue,
              let age = profile.age else {
            return 2000 // Default value
        }
        
        // Calculate BMR (Basal Metabolic Rate) using Mifflin-St Jeor Equation
        var bmr: Double
        if profile.gender?.lowercased() == "male" || profile.gender?.lowercased() == "m" {
            // Male: BMR = 10 * weight(kg) + 6.25 * height(cm) - 5 * age + 5
            let heightInCm = convertHeightToCm(profile)
            bmr = 10 * weight + 6.25 * heightInCm - 5 * Double(age) + 5
        } else {
            // Female: BMR = 10 * weight(kg) + 6.25 * height(cm) - 5 * age - 161
            let heightInCm = convertHeightToCm(profile)
            bmr = 10 * weight + 6.25 * heightInCm - 5 * Double(age) - 161
        }
        
        // Activity multiplier (assume moderate activity for workout users)
        let tdee = bmr * 1.55
        
        // Adjust for goal
        if profile.goal?.lowercased().contains("loss") == true {
            return Int(tdee * 0.85) // 15% deficit
        } else if profile.goal?.lowercased().contains("gain") == true {
            return Int(tdee * 1.15) // 15% surplus
        }
        
        return Int(tdee)
    }
    
    private func convertHeightToCm(_ profile: UserProfile) -> Double {
        guard let heightValue = profile.heightValue,
              let heightUnit = profile.heightUnit else {
            return 170.0 // Default height in cm
        }
        
        if heightUnit.lowercased() == "cm" {
            return heightValue
        } else {
            // Assume inches, convert to cm
            return heightValue * 2.54
        }
    }
}

// MARK: - Supporting Types

/// Result from plan generation
struct PlanResult {
    let content: String
    let messageType: String
    let workoutPlan: WorkoutPlanData?
    let nutritionPlan: NutritionPlanData?
    let multiDayPlan: MultiDayPlanData?
}

/// Errors specific to legacy plan generation
enum LegacyPlanError: Error, LocalizedError {
    case emptyPlan
    case truncatedResponse
    case decodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyPlan:
            return "AI returned incomplete workout plan."
        case .truncatedResponse:
            return "The plan was too large and got cut off. Please try asking for fewer days."
        case .decodingFailed(let detail):
            return "Failed to parse plan: \(detail)"
        }
    }
}

