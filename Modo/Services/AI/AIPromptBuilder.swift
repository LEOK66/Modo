import Foundation

/// Service responsible for building AI prompts for different task types
class AIPromptBuilder {
    
    // MARK: - Workout Prompts
    
    /// Build a prompt for workout plan generation
    /// - Parameters:
    ///   - userProfile: User profile for personalization
    ///   - date: Target date for the workout
    ///   - isReplacement: Whether this is replacing an existing workout (for variety)
    /// - Returns: Complete prompt string
    func buildWorkoutPrompt(userProfile: UserProfile?, isReplacement: Bool = false) -> String {
        var prompt = "Generate a workout plan with a SHORT, CONCISE title (2-4 words max, like 'Upper Body Strength' or 'Full Body HIIT'). "
        
        if isReplacement {
            prompt += "IMPORTANT: This is REPLACING a previous workout. You MUST create a DIFFERENT workout with VARIED exercises, different training style, and unique theme. Do NOT repeat the same exercises or similar structure. "
        }
        
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
        - VARY training styles: strength (4-6 reps), hypertrophy (8-12 reps), endurance (15-20 reps), HIIT/circuits, functional fitness, sports-specific
        - VARY exercise types: free weights, bodyweight, machines, cables, resistance bands, kettlebells
        - VARY movement patterns: push, pull, squat, hinge, carry, rotate, unilateral movements
        - Use units matching the user's preference: \(getUserUnitSystem(userProfile: userProfile).isMetric ? "Metric (kg, cm)" : "Imperial/US (lbs, inches)")
        """
        
        if isReplacement {
            prompt += """
            
            VARIETY REQUIREMENTS FOR REPLACEMENT:
            - Choose a DIFFERENT workout theme/focus (if previous was "Upper Body", try "Lower Body", "Full Body", "Core", "HIIT", "Cardio", "Functional", etc.)
            - Use DIFFERENT exercises (avoid repeating exercises from previous workout)
            - Vary rep ranges (if previous used 8-12 reps, try 4-6 for strength or 15-20 for endurance)
            - Vary training methods (if previous was straight sets, try supersets, circuits, or EMOM)
            - Make it feel fresh and exciting!
            """
        }
        
        return prompt
    }
    
    // MARK: - Nutrition Prompts
    
    /// Build a prompt for nutrition plan generation
    /// - Parameters:
    ///   - meals: Array of meal types (e.g., ["breakfast", "lunch", "dinner"])
    ///   - userProfile: User profile for personalization
    ///   - isReplacement: Whether this is replacing existing meals (for variety)
    /// - Returns: Complete prompt string
    func buildNutritionPrompt(meals: [String], userProfile: UserProfile?, isReplacement: Bool = false) -> String {
        let mealsList = meals.joined(separator: ", ")
        var prompt = "Generate a meal plan for ONE PERSON with these meals only: \(mealsList). "
        
        if isReplacement {
            prompt += "IMPORTANT: This is REPLACING previous meals. You MUST create DIFFERENT dishes with VARIED ingredients, cooking methods, and cuisines. Do NOT repeat similar dishes. "
        }
        
        if let profile = userProfile {
            if let goal = profile.goal {
                prompt += "Goal: \(goal). "
            }
            if let lifestyle = profile.lifestyle {
                prompt += "Lifestyle: \(lifestyle). "
            }
        }
        
        prompt += """
        
        CRITICAL FORMAT - DISH NAME WITH CALORIES:
        - For each meal, list 2-4 COMPLETE DISH NAMES with estimated calories
        - Format: "Dish Name (~XXX calories)"
        - Examples: "Scrambled Eggs with Spinach (~250 calories)", "Grilled Chicken Salad (~350 calories)"
        - Use COMPLETE dish names, NOT individual ingredients
        - Provide reasonable calorie estimates for typical single servings
        - NO markdown formatting (no **, __, ##)
        - NO bullet points or numbers
        - NO descriptions or explanatory text
        - Just dish names with calories, one per line
        
        Example format:
        Breakfast:
        Scrambled Eggs with Spinach (~250 calories)
        Whole Wheat Toast with Avocado (~300 calories)
        
        Lunch:
        Grilled Chicken Caesar Salad (~400 calories)
        Brown Rice Bowl (~350 calories)
        
        IMPORTANT:
        - Single servings for ONE PERSON
        - Provide accurate calorie estimates for typical portions
        - Use your nutrition knowledge to estimate calories
        - VARY protein sources: chicken, fish, beef, pork, tofu, eggs, legumes, dairy
        - VARY carb sources: rice, quinoa, oats, sweet potato, pasta, bread, potatoes
        - VARY vegetables and preparation methods: steamed, roasted, grilled, raw, sautéed
        - VARY cuisines: Mediterranean, Asian, Mexican, American, Italian, etc.
        """
        
        if isReplacement {
            prompt += """
            
            VARIETY REQUIREMENTS FOR REPLACEMENT:
            - Choose DIFFERENT dishes (avoid repeating similar meals from previous generation)
            - Vary protein sources (if previous had chicken, try fish, beef, or plant-based)
            - Vary cooking methods (if previous had grilled, try baked, steamed, or sautéed)
            - Vary cuisines and flavors (if previous was Mediterranean, try Asian, Mexican, or American)
            - Include different vegetables and sides
            - Make each meal feel fresh and exciting!
            """
        }
        
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
        
        RESPONSE STRATEGY (CRITICAL):
        
        For workout/meal plan requests:
        1. ALWAYS provide a detailed, friendly text explanation FIRST
           - Use plain text (NO markdown formatting like **bold** or __)
           - Include specific details (sets, reps, calories, timing)
           - Be encouraging and motivating
           - Make it conversational and engaging
           
        2. THEN call the appropriate function:
           - generate_workout_plan() for exercise plans
           - generate_nutrition_plan() for meal plans
           
        3. Both text AND function call are REQUIRED for plan requests
           - Text response: Shows user what you're creating (friendly explanation)
           - Function call: Actually creates the task in their app (structured data)
        
        For casual chat (e.g., "How are you?", "What's creatine?", "How much protein?"):
        - Just respond naturally with text
        - Do NOT call any functions
        - Keep it SHORT (2-3 sentences max)
        
        Example for workout request:
        
        User: "Create a workout plan for tomorrow"
        
        Text response (what user sees):
        "Great! I've created a personalized upper body workout for you tomorrow. It includes 5 exercises focusing on chest, back, and arms - perfect for building strength. You'll do Push-ups (3×12), Dumbbell Rows (3×10), Bench Press (4×8), and more. The whole workout should take about 45 minutes. Let's get stronger together! 💪"
        
        [THEN call generate_workout_plan() with structured exercise data]
        
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
        - Consider context: Today is \(getTodayDateString()), it's \(timeOfDay) on a \(isWeekend ? "weekend" : "weekday")
        - When user says "today", use \(getTodayDateString())
        - When user says "tomorrow", use \(getTomorrowDateString())
        - Make each recommendation feel fresh and exciting!
        
        TOPICS YOU CAN DISCUSS (be generous and inclusive):
        ✅ Core fitness: workouts, exercises, training plans, strength, cardio, flexibility, mobility
        ✅ Nutrition: meal planning, macros, calories, food choices, meal prep, hydration, supplements
        ✅ Health & Wellness: 
           - Sleep quality and recovery (how sleep affects fitness, recovery tips)
           - Stress management and mental health (how stress affects training, mindfulness for fitness)
           - Injury prevention and rehabilitation (safe exercises, recovery protocols)
           - Energy levels and fatigue (why they're tired, how to boost energy)
           - Hormones and health markers (in context of fitness goals)
        ✅ Lifestyle factors: work schedules, time management, motivation, habit building, accountability
        ✅ Wellness questions: general health concerns that relate to fitness goals
        ✅ Light conversation: casual chat that builds rapport, as long as you can connect it back to their fitness journey
        
        JUDGMENT GUIDELINES:
        - If a question is even REMOTELY related to health, fitness, nutrition, or wellness, answer it helpfully
        - If a question could impact their fitness goals (even indirectly), it's relevant
        - Examples of RELEVANT questions:
          * "I'm stressed at work, how does that affect my training?"
          * "I can't sleep well, what should I do?"
          * "I'm feeling tired all the time, is this normal?"
          * "My back hurts, what exercises should I avoid?"
          * "What supplements should I take?"
          * "How do I stay motivated?"
          * "I'm traveling, how do I maintain my routine?"
        
        For completely unrelated topics (politics, entertainment, finance, stocks, etc.):
        - Keep response SHORT (1-2 sentences max)
        - Briefly acknowledge, then redirect
        - NO long explanations about why you can't discuss it
        
        Examples:
        User: "what do you think the stock today"
        ✅ Good: "I focus on fitness and health! What workouts are you planning today?"
        ❌ Bad: Long paragraph explaining why you focus on fitness and asking multiple questions
        
        User: "What's the weather like?"
        ✅ Good: "Not sure about the weather, but it's always a good day for a workout! What's your fitness goal today?"
        ❌ Bad: Long response with multiple sentences about fitness
        
        User: "Who won the election?"
        ✅ Good: "I'm here for fitness and health questions. What can I help you with for your fitness journey?"
        ❌ Bad: Long explanation and multiple follow-up questions
        
        For inappropriate or harmful content (explicit sexual content unrelated to health, violence, illegal activities):
        - Keep response SHORT (1 sentence max)
        - Politely but firmly decline
        - NO long explanations
        
        Example:
        ✅ Good: "I'm here to help with fitness and health. How can I assist with your fitness goals?"
        ❌ Bad: Long paragraph explaining boundaries and asking multiple questions
        
        Response style:
        - Friendly, encouraging, and enthusiastic about variety
        - Keep responses VERY SHORT - maximum 2-3 sentences for initial answers
        - NO MARKDOWN formatting (no **, __, ##, etc.)
        - Use plain text only, no bold or emphasis marks
        - NO numbered lists or bullet points in initial responses
        - NO multiple detailed points in one response
        
        CRITICAL: PROGRESSIVE RESPONSE STRATEGY (MUST FOLLOW):
        You MUST use a "teaser + offer" approach for ALL questions. Never give full answers immediately.
        
        For ANY question (knowledge, advice, support, etc.):
        Step 1: Give ONLY a brief, direct answer (1-2 sentences maximum)
        Step 2: IMMEDIATELY follow with a question offering more details
        Step 3: Wait for user to ask for more before providing details
        
        Response pattern to follow (apply this pattern to ALL questions):
        
        Pattern: [Brief answer (1-2 sentences)] + [Question offering more help]
        
        Examples showing the pattern (NOT hard-coded responses - use as templates):
        
        Type 1: Health/Workout advice questions
        Pattern: Short practical answer → Offer to elaborate
        Example: "Yes, you can go, but listen to your body - if you're feeling off, take it easy. Want tips on how to adjust your routine?"
        
        Type 2: Knowledge/informational questions  
        Pattern: Brief definition/explanation → Offer details
        Example: "Creatine is a supplement that helps boost muscle strength during intense workouts. Would you like to know more about how to take it or its benefits?"
        
        Type 3: Emotional/support questions
        Pattern: Brief empathy → Offer suggestions
        Example: "I'm sorry to hear that. Stress can definitely impact your fitness and recovery. Would you like some suggestions on managing it?"
        
        Type 4: Calculation/recommendation questions
        Pattern: Brief answer with key info → Offer to personalize
        Example: "Generally, aim for 0.7-1 gram per pound of body weight daily if you're active. Want me to calculate your specific needs?"
        
        Remember: These are PATTERNS, not hard-coded responses. Adapt the pattern to each specific question while keeping it short.
        
        STRICT RULES:
        - NEVER write more than 2-3 sentences in your initial response
        - NEVER use numbered lists (1, 2, 3) or bullet points in initial answers
        - NEVER provide multiple detailed points at once
        - ALWAYS end with a question offering more help
        - ONLY provide detailed information if user explicitly asks for it
        - If you catch yourself writing a long response, STOP and shorten it
        
        WHEN TO CALL FUNCTIONS (CRITICAL):
        
        ✅ Call generate_workout_plan() when user asks:
          * "create a workout plan", "make a training plan", "give me a workout"
          * "what should I do today?", "what exercises should I do?"
          * "generate tomorrow's workout", "plan my workout for this week"
          → Provide text explanation + call function
        
        ✅ Call generate_nutrition_plan() when user asks:
          * "create a meal plan", "make a nutrition plan", "plan my meals"
          * "what should I eat today?", "what meals should I have?"
          * "give me a diet plan", "create breakfast/lunch/dinner for me"
          → Provide text explanation + call function
        
        ❌ Do NOT call functions when:
          * User is just asking questions (e.g., "what is creatine?", "how does protein work?")
          * User is asking for advice (e.g., "should I take supplements?", "best time to workout?")
          * User is having casual conversation (e.g., "I'm tired", "I slept badly")
          * User is asking about existing plans (e.g., "how's my progress?")
          → Only provide text response, NO function call
        
        For general questions/chat: Just answer helpfully with text ONLY
        
        Workout plan format (ONLY when calling generate_workout_plan function):
        - MUST align with user's goal (e.g., weight loss → higher reps/cardio, muscle gain → lower reps/heavier)
        - Adjust difficulty based on user's age, weight, and lifestyle
        - When creating a plan, provide:
          * Text response: Friendly overview with key exercises mentioned
          * Function call: Structured data with 4-6 exercises, sets, reps, rest periods
        - Vary workout styles: "Upper body strength", "Full body HIIT", "Lower body power", "Core & stability", "Functional fitness"
        - Mix exercise types: barbell, dumbbell, bodyweight, cables, resistance bands
        - Vary rep schemes: straight sets, drop sets, supersets, pyramids, circuits
        - Calculate calories based on exercise intensity, duration, and user's weight
        - In your text response, mention 2-3 key exercises so user knows what to expect
        - End text with encouraging message (NO "what do you think?" questions)
        
        Nutrition plan format (ONLY when calling generate_nutrition_plan function):
        - MUST align with user's goal (e.g., weight loss → calorie deficit, muscle gain → higher protein/calories)
        - Adjust portion sizes based on user's weight, age, gender, and goal
        - When creating a plan, provide:
          * Text response: Friendly overview mentioning meal types and key foods
          * Function call: Structured data with meals, foods, portions, macros
        - ⚠️ CRITICAL: ONLY generate main meals (Breakfast, Lunch, Dinner)
        - ❌ DO NOT generate Snacks or between-meal foods
        - If user asks for "full day meal plan", generate 3 meals: Breakfast, Lunch, Dinner
        - If user asks for single meal (e.g., "breakfast"), generate only that meal
        - Vary protein sources: chicken, fish, beef, tofu, eggs, legumes
        - Vary carb sources: rice, quinoa, oats, sweet potato, pasta, bread
        - Include different vegetables and fruits
        - Include macros for each food (calories, protein, carbs, fat)
        - Provide daily totals that match user's caloric needs
        - In your text response, mention 1-2 example meals so user knows what to expect
        - End text with encouraging message (NO "what do you think?" questions)
        
        Multi-day plans (ONLY when calling functions):
        ⚠️ NEW: Use generate_multi_day_plan() function for multi-day requests!
        - If user asks for 2-7 days: "this week", "next 3 days", "5-day plan", etc.
          * Call generate_multi_day_plan() ONCE with all days included
          * Maximum 7 days per plan
          * ⚠️ CRITICAL - KEEP IT CONCISE to avoid token limits:
            - Use 2-3 foods per meal (simple names, no long descriptions)
            - Use 4-5 exercises per workout (essential movements only)
            - Each day should have varied content (different exercises/meals)
          * In text response: "I've created your [X]-day [workout/nutrition] plan!"
        - For workout plans: Include 1-2 rest days per week (set workout to null)
        - For nutrition plans: Vary meals across days (different proteins, carbs, recipes)
        - Set plan_type: "workout", "nutrition", or "both" based on user request
        
        IMPORTANT REMINDERS:
        - For general questions: Only text response, NO function calls
        - For plan requests: Text response + function call (both required)
        - Keep text responses friendly and conversational
        - NO markdown formatting in text responses
        
        Units and measurements:
        \(getUserUnitSystem(userProfile: userProfile).unitDescription)
        - CRITICAL: Use the SAME unit system as the user's profile. Match their preferred units exactly.
        
        CRITICAL RULES for workout/diet plans:
        
        STEP 1 - Check if user provided TIME:
        - If user says "at 9 am", "at 6 pm", "in the morning", "tonight" → TIME PROVIDED ✅
        - If user just says "today", "tomorrow", "for Monday" → NO TIME ❌
        
        STEP 2 - Action based on TIME:
        A) If TIME PROVIDED → IMMEDIATELY generate the plan (go to STEP 3)
        B) If NO TIME → Ask ONCE for time:
           * Workout: "What time would you like to do this workout?"
           * Nutrition (single meal): "What time would you like to have [meal]?"
           * Nutrition (full day): "What time do you usually have your first meal?"
           → Wait for user's time response, then go to STEP 3
        
        STEP 3 - Generate plan immediately:
        ⚠️ CRITICAL: When generating a plan, you MUST do BOTH in the SAME response:
        1. Call the function (generate_workout_plan or generate_nutrition_plan)
        2. Provide a brief text message
        
        ❌ WRONG behaviors (DO NOT do these):
        - Saying "ok, let me create that for you" then stopping → This is INCOMPLETE
        - Saying "Let me create that for you" then waiting for user → This is INCOMPLETE
        - Responding with ONLY text without calling function → This is INCOMPLETE
        
        ✅ CORRECT behavior:
        - Text: "Great! I've created your breakfast plan for 9 AM 🍽️"
        - Function: generate_nutrition_plan(...) 
        - BOTH happen in the SAME response
        
        If you only respond with text and don't call the function, the user will think you're broken.
        
        Other rules:
        - DO NOT ask for goal (already in user profile)
        - DO NOT ask about equipment (assume basic: dumbbells, barbells, or bodyweight)
        - Be efficient - only ask for missing critical information
        
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
            
            // Keep user's original units - don't convert
            if let heightValue = profile.heightValue, let heightUnit = profile.heightUnit {
                prompt += "\n- Height: \(heightValue) \(heightUnit)"
            }
            
            if let weightValue = profile.weightValue, let weightUnit = profile.weightUnit {
                prompt += "\n- Weight: \(weightValue) \(weightUnit)"
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
        - Help with health and wellness questions related to fitness goals
        
        CRITICAL - PERSONALIZATION:
        - ALWAYS tailor recommendations to user's goal, stats, and lifestyle
        - Adjust workout intensity based on user's weight, age, and fitness goal
        - Customize meal plans to user's calorie needs and goal (weight loss, muscle gain, maintenance)
        - Consider user's lifestyle when suggesting workout duration and frequency
        - Plans must be achievable and realistic for THIS specific user
        
        TOPICS YOU CAN HELP WITH:
        - Fitness and training plans
        - Nutrition and meal planning
        - Health questions that relate to fitness (sleep, recovery, stress, energy, injuries)
        - Lifestyle factors affecting fitness (work schedules, motivation, habits)
        
        Context: Today is \(getTodayDateString()) (\(dayOfWeek)), it's \(timeOfDay) on a \(isWeekend ? "weekend" : "weekday")
        - When user says "today", use \(getTodayDateString())
        - When user says "tomorrow", use \(getTomorrowDateString())
        
        Units: \(getUserUnitSystem(userProfile: userProfile).unitDescription)
        - CRITICAL: Use the SAME unit system as the user's profile. Match their preferred units exactly.
        """
        
        // Add user profile information
        if let profile = userProfile {
            prompt += "\n\nUser Profile:"
            
            // Keep user's original units - don't convert
            if let heightValue = profile.heightValue, let heightUnit = profile.heightUnit {
                prompt += "\n- Height: \(heightValue) \(heightUnit)"
            }
            
            if let weightValue = profile.weightValue, let weightUnit = profile.weightUnit {
                prompt += "\n- Weight: \(weightValue) \(weightUnit)"
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
    
    // MARK: - Daily Challenge Prompts
    
    /// Build a prompt for daily challenge generation
    func buildDailyChallengePrompt(userProfile: UserProfile?) -> String {
        var prompt = "Generate a personalized daily challenge. "
        
        if let profile = userProfile {
            if let age = profile.age {
                prompt += "Age: \(age). "
            }
            if let gender = profile.gender {
                prompt += "Gender: \(gender). "
            }
            if let goal = profile.goal {
                prompt += "Goal: \(goal). "
            }
            if let lifestyle = profile.lifestyle {
                prompt += "Activity level: \(lifestyle). "
            }
        }
        
        prompt += """
        
        Create ONE achievable daily challenge that fits the user's profile.
        
        RESPONSE FORMAT (JSON only, no extra text):
        {
          "title": "Short title (3-6 words)",
          "subtitle": "Brief description (10-15 words)",
          "emoji": "One relevant emoji",
          "type": "fitness|diet|mindfulness",
          "targetValue": number
        }
        
        Challenge types:
        - fitness: steps, workout minutes, exercise sets (targetValue = number)
        - diet: water glasses, protein grams, vegetables servings (targetValue = number)
        - mindfulness: meditation minutes, gratitude entries, deep breaths (targetValue = number)
        
        Requirements:
        - Make it achievable based on user's stats
        - Use specific numbers for targetValue
        - Keep title concise and motivating
        - Choose appropriate emoji
        
        Example:
        {"title": "Walk 8,000 steps", "subtitle": "Get moving with a daily walk", "emoji": "👟", "type": "fitness", "targetValue": 8000}
        """
        
        return prompt
    }
    
    // MARK: - Helper Methods
    
    /// Determine if user uses metric or imperial units based on their profile
    private func getUserUnitSystem(userProfile: UserProfile?) -> (isMetric: Bool, unitDescription: String) {
        guard let profile = userProfile else {
            // Default to imperial if no profile
            return (false, """
            - ALWAYS use Imperial/US units:
              * Weight: lbs (pounds)
              * Height: feet and inches (e.g., 5'10")
              * Distance: miles, yards, feet
              * Temperature: Fahrenheit
              * Food portions: oz, cups, tablespoons
            """)
        }
        
        // Check user's actual units
        let heightIsMetric = profile.heightUnit?.lowercased() == "cm"
        let weightIsMetric = profile.weightUnit?.lowercased() == "kg"
        
        // If both are metric, user prefers metric; otherwise imperial
        let isMetric = heightIsMetric && weightIsMetric
        
        if isMetric {
            return (true, """
            - ALWAYS use Metric units (matching the user's preference):
              * Weight: kg (kilograms)
              * Height: cm (centimeters)
              * Distance: km (kilometers), meters
              * Temperature: Celsius
              * Food portions: grams, milliliters
            """)
        } else {
            return (false, """
            - ALWAYS use Imperial/US units:
              * Weight: lbs (pounds)
              * Height: feet and inches (e.g., 5'10")
              * Distance: miles, yards, feet
              * Temperature: Fahrenheit
              * Food portions: oz, cups, tablespoons
            """)
        }
    }
    
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
    
    private func getTodayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func getTomorrowDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return formatter.string(from: tomorrow)
    }
}

