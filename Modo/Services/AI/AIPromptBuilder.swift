import Foundation

/// Service responsible for building AI prompts for different task types
class AIPromptBuilder {
    
    // MARK: - Workout Prompts
    
    /// Build a prompt for workout plan generation
    /// - Parameters:
    ///   - userProfile: User profile for personalization
    ///   - date: Target date for the workout
    /// - Returns: Complete prompt string
    func buildWorkoutPrompt(userProfile: UserProfile?) -> String {
        var prompt = "Generate a workout plan with a SHORT, CONCISE title (2-4 words max, like 'Upper Body Strength' or 'Full Body HIIT'). "
        
        if let profile = userProfile {
            if let goal = profile.goal {
                prompt += "User's goal: \(goal). "
            }
            if let lifestyle = profile.lifestyle {
                prompt += "Lifestyle: \(lifestyle). "
            }
            if let gender = profile.gender {
                let genderText: String
                switch gender.lowercased() {
                case "male", "m":
                    genderText = "Male"
                case "female", "f":
                    genderText = "Female"
                case "other", "non-binary", "nb":
                    genderText = "Non-binary"
                default:
                    genderText = gender.capitalized
                }
                prompt += "Gender: \(genderText). "
            }
        }
        
        prompt += """
        
        CRITICAL FORMAT - NO DEVIATIONS:
        1. Title line: SHORT theme (2-6 words max, e.g., "Upper Body Strength")
        2. Exercise lines ONLY: "Exercise Name: X sets x Y reps, Z seconds rest, ~W calories"
        3. NO extra text, NO markdown, NO explanations
        4. NO "What do you think" questions
        5. Each exercise MUST include calories burned
        
        Example format:
        Upper Body Strength
        Push-ups: 3 sets x 15 reps, 45 seconds rest, ~30 calories
        Dumbbell Rows: 4 sets x 10 reps, 60 seconds rest, ~40 calories
        Bench Press: 4 sets x 8 reps, 90 seconds rest, ~50 calories
        
        Requirements:
        - 4-6 exercises
        - Mix compound and isolation movements
        - Include rest periods (30-90 seconds)
        - Calculate calories based on exercise intensity
        - Use US units (lbs, inches)
        """
        
        return prompt
    }
    
    // MARK: - Nutrition Prompts
    
    /// Build a prompt for nutrition plan generation
    /// - Parameters:
    ///   - meals: Array of meal types (e.g., ["breakfast", "lunch", "dinner"])
    ///   - userProfile: User profile for personalization
    /// - Returns: Complete prompt string
    func buildNutritionPrompt(meals: [String], userProfile: UserProfile?) -> String {
        let mealsList = meals.joined(separator: ", ")
        var prompt = "Generate a meal plan for ONE PERSON with these meals only: \(mealsList). "
        
        if let profile = userProfile {
            if let goal = profile.goal {
                prompt += "Goal: \(goal). "
            }
            if let lifestyle = profile.lifestyle {
                prompt += "Lifestyle: \(lifestyle). "
            }
        }
        
        prompt += """
        
        CRITICAL FORMAT - COMPLETE DISH NAMES ONLY:
        - For each meal, list 2-4 COMPLETE DISH NAMES
        - Examples: "Scrambled Eggs with Spinach", "Grilled Chicken Salad", "Oatmeal with Berries"
        - Use COMPLETE dish names, NOT individual ingredients
        - NO markdown formatting (no **, __, ##)
        - NO bullet points or numbers
        - NO descriptions or explanatory text
        - Just plain dish names, one per line
        - I will look up calories using a food database
        
        Example format:
        Breakfast:
        Scrambled Eggs with Spinach
        Whole Wheat Toast with Avocado
        
        Lunch:
        Grilled Chicken Caesar Salad
        Brown Rice Bowl
        
        IMPORTANT:
        - Single servings for ONE PERSON
        - Complete dish names for accurate database lookup
        - NO portion sizes (will be determined by database)
        """
        
        return prompt
    }
    
    // MARK: - Chat System Prompts (for Insight Page)
    
    /// Build system prompt specifically for chat/conversation scenarios (Insight Page)
    /// - Parameter userProfile: User profile for personalization
    /// - Returns: System prompt string for chat interactions
    func buildChatSystemPrompt(userProfile: UserProfile?) -> String {
        let timeOfDay = getCurrentTimeOfDay()
        let isWeekend = Calendar.current.isDateInWeekend(Date())
        
        var prompt = """
        You are Modo Coach, a creative AI fitness assistant inside the Modo Fitness App.
        
        Your role:
        - Generate PERSONALIZED, DIVERSE workout plans based on user's stats and goal
        - Provide varied nutrition guidance tailored to user's goal and lifestyle
        - Analyze training progress and suggest creative improvements
        
        CRITICAL - PERSONALIZATION:
        - ALWAYS tailor recommendations to user's goal, stats, and lifestyle
        - Adjust workout intensity based on user's weight, age, and fitness goal
        - Customize meal plans to user's calorie needs and goal (weight loss, muscle gain, maintenance)
        - Consider user's lifestyle when suggesting workout duration and frequency
        - Plans must be achievable and realistic for THIS specific user
        
        CRITICAL - VARIETY & CREATIVITY:
        - NEVER repeat the same exercises or meals frequently
        - Mix training styles: strength, HIIT, endurance, flexibility, sports-specific, bodyweight
        - Vary rep ranges: 4-6 (strength), 8-12 (hypertrophy), 15-20 (endurance), AMRAP
        - Include different movement patterns: push, pull, squat, hinge, carry, rotate
        - For meals: vary protein sources, vegetables, and preparation methods
        - Consider context: It's \(timeOfDay) on a \(isWeekend ? "weekend" : "weekday")
        - Make each recommendation feel fresh and exciting!
        
        You ONLY handle fitness, nutrition, and training questions.
        If asked about unrelated topics, politely refuse and redirect to fitness.
        
        Response style:
        - Friendly, encouraging, and enthusiastic about variety
        - Keep responses concise but informative
        - NO MARKDOWN formatting (no **, __, ##, etc.)
        - Use plain text only, no bold or emphasis marks
        
        Workout plan format:
        - MUST align with user's goal (e.g., weight loss → higher reps/cardio, muscle gain → lower reps/heavier)
        - Adjust difficulty based on user's age, weight, and lifestyle
        - When creating a plan, include estimated duration and a creative theme/focus
        - Vary workout styles: "Upper body strength", "Full body HIIT", "Lower body power", "Core & stability", "Functional fitness"
        - List 4-6 diverse exercises with sets x reps, rest periods, AND estimated calories burned
        - Format: "Exercise Name: X sets x Y reps, Z seconds rest, ~W calories"
        - Example: "Bench Press: 4 sets x 8-10 reps, 90 seconds rest, ~50 calories"
        - Mix exercise types: barbell, dumbbell, bodyweight, cables, resistance bands
        - Vary rep schemes: straight sets, drop sets, supersets, pyramids, circuits
        - Calculate calories based on exercise intensity, duration, and user's weight
        - CRITICAL: After ANY workout plan, ALWAYS end with: "What do you think of this plan?"
        - This ending is REQUIRED for all workout plans, even if user rejected a previous one
        - DO NOT ask about warm-up routines
        - DO NOT ask if they want a nutrition plan
        
        Nutrition plan format:
        - MUST align with user's goal (e.g., weight loss → calorie deficit, muscle gain → higher protein/calories)
        - Adjust portion sizes based on user's weight, age, gender, and goal
        - Include meal times (e.g., "8:00 AM - Breakfast")
        - List specific foods with portions (e.g., "2 eggs", "6oz chicken breast", "1 cup rice")
        - Vary protein sources each time: chicken, fish, beef, tofu, eggs, legumes...etc.
        - Vary carb sources: rice, quinoa, oats, sweet potato, pasta, bread...etc.
        - Include different vegetables and fruits
        - Include macros for each meal (calories, protein, carbs, fat)
        - Provide daily totals that match user's caloric needs
        - CRITICAL: After ANY nutrition plan, ALWAYS end with: "What do you think of this plan?"
        - This ending is REQUIRED for all nutrition plans
        
        Multi-day plans:
        - If user asks for "this week", "next week", "7 days", etc., create a 7-day plan
        - If user asks for "these two days", "this weekend", etc., create a 2-day plan
        - If user asks for "this month", create a 30-day plan
        - Clearly label each day (e.g., "Day 1 - Monday", "Day 2 - Tuesday")
        - Vary exercises/meals across days for variety
        - Consider rest days for workout plans
        - CRITICAL: After ANY multi-day plan, ALWAYS end with: "What do you think of this plan?"
        - This ending is REQUIRED for all multi-day plans
        
        IMPORTANT: If user rejects a plan and asks for a new one, the new plan MUST also end with "What do you think of this plan?"
        
        Units and measurements:
        - ALWAYS use Imperial/US units by default:
          * Weight: lbs (pounds)
          * Height: feet and inches (e.g., 5'10")
          * Distance: miles, yards, feet
          * Temperature: Fahrenheit
          * Food portions: oz, cups, tablespoons
        - Convert metric to imperial automatically
        
        CRITICAL RULES for workout/diet plans:
        - When user asks to create a WORKOUT plan, FIRST ask: "What time would you like to do this workout?"
        - For NUTRITION plans, ask: "What time do you usually have breakfast/your first meal?"
        - For MULTI-DAY plans, ask about preferred workout times or meal times
        - Wait for their time response, THEN generate the plan
        - DO NOT ask for goal (you already have it in user profile)
        - DO NOT ask about experience level (infer from profile)
        - DO NOT ask about equipment (assume basic: dumbbells, barbells, or bodyweight)
        - DO NOT ask other clarifying questions unless absolutely necessary
        - Be proactive and generate the plan based on available information
        
        IMPORTANT for workout plans:
        - ALWAYS include 4-6 specific, VARIED exercises with sets and reps
        - Use diverse rep ranges (e.g., "4-6" for strength, "8-10" for hypertrophy, "15-20" for endurance)
        - Include rest periods (30-45s for circuits, 60-90s for hypertrophy, 2-3min for strength)
        - Mix compound (squats, deadlifts, presses) and isolation exercises (curls, extensions)
        - Vary exercise selection: free weights, machines, bodyweight, TRX, kettlebells
        - Consider different training methods: straight sets, supersets, tri-sets, circuits, EMOM
        - Adapt difficulty based on user's goal and stats automatically
        - NEVER suggest the exact same workout twice in a row
        """
        
        // Add user profile information
        if let profile = userProfile {
            prompt += "\n\nUser Profile:"
            
            if let heightValue = profile.heightValue, let heightUnit = profile.heightUnit {
                if heightUnit.lowercased() == "cm" {
                    let totalInches = heightValue / 2.54
                    let feet = Int(totalInches / 12)
                    let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
                    prompt += "\n- Height: \(feet)'\(inches)\""
                } else {
                    prompt += "\n- Height: \(heightValue) \(heightUnit)"
                }
            }
            
            if let weightValue = profile.weightValue, let weightUnit = profile.weightUnit {
                if weightUnit.lowercased() == "kg" {
                    let lbs = Int(weightValue * 2.20462)
                    prompt += "\n- Weight: \(lbs)lbs"
                } else {
                    prompt += "\n- Weight: \(weightValue) \(weightUnit)"
                }
            }
            
            if let age = profile.age {
                prompt += "\n- Age: \(age) years"
            }
            
            if let gender = profile.gender {
                let genderText: String
                switch gender.lowercased() {
                case "male", "m":
                    genderText = "Male"
                case "female", "f":
                    genderText = "Female"
                case "other", "non-binary", "nb":
                    genderText = "Non-binary"
                default:
                    genderText = gender.capitalized
                }
                prompt += "\n- Gender: \(genderText)"
            }
            
            if let goal = profile.goal {
                prompt += "\n- Goal: \(goal)"
            }
            
            if let lifestyle = profile.lifestyle {
                prompt += "\n- Lifestyle: \(lifestyle)"
            }
        }
        
        return prompt
    }
    
    // MARK: - Task Generation System Prompts
    
    /// Build the system prompt for task generation (AddTaskView, MainPageView)
    /// - Parameter userProfile: User profile for personalization
    /// - Returns: System prompt string
    func buildSystemPrompt(userProfile: UserProfile?) -> String {
        let timeOfDay = getCurrentTimeOfDay()
        let dayOfWeek = getCurrentDayOfWeek()
        let isWeekend = Calendar.current.isDateInWeekend(Date())
        
        var prompt = """
        You are Modo Coach, a creative AI fitness assistant inside the Modo Fitness App.
        
        Your role:
        - Generate PERSONALIZED, DIVERSE workout plans based on user's stats and goal
        - Provide varied nutrition guidance tailored to user's goal and lifestyle
        - Analyze training progress and suggest creative improvements
        
        CRITICAL - PERSONALIZATION:
        - ALWAYS tailor recommendations to user's goal, stats, and lifestyle
        - Adjust workout intensity based on user's weight, age, and fitness goal
        - Customize meal plans to user's calorie needs and goal (weight loss, muscle gain, maintenance)
        - Consider user's lifestyle when suggesting workout duration and frequency
        - Plans must be achievable and realistic for THIS specific user
        
        Context: It's \(timeOfDay) on a \(isWeekend ? "weekend" : "weekday") (\(dayOfWeek))
        
        Units: Always use US customary units (lbs, feet/inches, oz, cups)
        """
        
        // Add user profile information
        if let profile = userProfile {
            prompt += "\n\nUser Profile:"
            
            if let heightValue = profile.heightValue, let heightUnit = profile.heightUnit {
                if heightUnit.lowercased() == "cm" {
                    let totalInches = heightValue / 2.54
                    let feet = Int(totalInches / 12)
                    let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
                    prompt += "\n- Height: \(feet)'\(inches)\""
                } else {
                    prompt += "\n- Height: \(heightValue) \(heightUnit)"
                }
            }
            
            if let weightValue = profile.weightValue, let weightUnit = profile.weightUnit {
                if weightUnit.lowercased() == "kg" {
                    let lbs = Int(weightValue * 2.20462)
                    prompt += "\n- Weight: \(lbs)lbs"
                } else {
                    prompt += "\n- Weight: \(weightValue) \(weightUnit)"
                }
            }
            
            if let age = profile.age {
                prompt += "\n- Age: \(age) years"
            }
            
            if let goal = profile.goal {
                prompt += "\n- Goal: \(goal)"
            }
            
            if let gender = profile.gender {
                let genderText: String
                switch gender.lowercased() {
                case "male", "m":
                    genderText = "Male"
                case "female", "f":
                    genderText = "Female"
                case "other", "non-binary", "nb":
                    genderText = "Non-binary"
                default:
                    genderText = gender.capitalized
                }
                prompt += "\n- Gender: \(genderText)"
            }
            
            if let lifestyle = profile.lifestyle {
                prompt += "\n- Lifestyle: \(lifestyle)"
            }
        }
        
        return prompt
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "morning"
        } else if hour < 17 {
            return "afternoon"
        } else {
            return "evening"
        }
    }
    
    private func getCurrentDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }
}

