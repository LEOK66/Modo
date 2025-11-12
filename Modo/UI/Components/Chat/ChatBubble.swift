import SwiftUI

struct ChatBubble: View {
    let message: FirebaseChatMessage
    var onAccept: ((FirebaseChatMessage) -> Void)?
    var onReject: ((FirebaseChatMessage) -> Void)?
    @EnvironmentObject var userProfileService: UserProfileService
    
    // Allow override for testing or specific cases
    var avatarName: String? {
        userProfileService.avatarName
    }
    var profileImageURL: String? {
        userProfileService.profileImageURL
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isFromUser {
                Spacer()
                userMessageView
            } else {
                aiAvatarView
                aiMessageView
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    // MARK: - AI Avatar
    private var aiAvatarView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hexString: "8B5CF6"), Color(hexString: "6366F1")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
            
            Image(systemName: "cpu")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - User Avatar
    private var userAvatarView: some View {
        ZStack {
            Circle()
                .fill(Color(hexString: "8B5CF6").opacity(0.3))
                .frame(width: 36, height: 36)
            
            Group {
                if let urlString = profileImageURL, !urlString.isEmpty {
                    if urlString.hasPrefix("http") || urlString.hasPrefix("https") {
                        if let url = URL(string: urlString) {
                            // Use cached image with placeholder
                            CachedAsyncImage(url: url) {
                                // Placeholder: show default avatar or fallback
                                if let name = avatarName, !name.isEmpty, UIImage(named: name) != nil {
                                    Image(name)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 36, height: 36)
                                        .clipShape(Circle())
                                } else {
                                    fallbackAvatar
                                }
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                        } else {
                            fallbackAvatar
                        }
                    } else {
                        fallbackAvatar
                    }
                } else if let name = avatarName, !name.isEmpty, UIImage(named: name) != nil {
                    Image(name)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    fallbackAvatar
                }
            }
        }
    }
    
    private var fallbackAvatar: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 18))
            .foregroundColor(Color(hexString: "8B5CF6"))
    }
    
    // MARK: - User Message
    private var userMessageView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                Text(message.content)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hexString: "1F2937"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hexString: "DDD6FE"))
                    .cornerRadius(20)
                    .frame(maxWidth: 260, alignment: .trailing)
                
                // User avatar
                userAvatarView
            }
            
            // Timestamp
            Text(message.timestamp, style: .time)
                .font(.system(size: 12))
                .foregroundColor(Color(hexString: "9CA3AF"))
                .padding(.trailing, 44)
        }
    }
    
    // MARK: - AI Message
    private var aiMessageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Check message type and display appropriate view
            if message.messageType == "workout_plan", let plan = message.workoutPlan {
                workoutPlanView(plan)
            } else if message.messageType == "nutrition_plan", let nutritionPlan = message.nutritionPlan {
                nutritionPlanView(nutritionPlan)
            } else if message.messageType == "multi_day_plan", let multiDayPlan = message.multiDayPlan {
                multiDayPlanView(multiDayPlan)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    highlightedTextView(message.content)
                        .font(.system(size: 16))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hexString: "F3F4F6"))
                        .cornerRadius(20)
                        .frame(maxWidth: 260, alignment: .leading)
                    
                    // Show action buttons if this looks like a plan suggestion and not already acted upon
                    if shouldShowActionButtons(for: message.content) && !message.actionTaken {
                        HStack(spacing: 16) {
                            Button(action: {
                                onReject?(message)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Reject")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(hexString: "EF4444"))
                                .cornerRadius(20)
                            }
                            .disabled(message.actionTaken)
                            
                            Button(action: {
                                onAccept?(message)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Add")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(hexString: "10B981"))
                                .cornerRadius(20)
                            }
                        }
                        .padding(.leading, 4)
                    }
                }
            }
            
            // Timestamp
            Text(message.timestamp, style: .time)
                .font(.system(size: 12))
                .foregroundColor(Color(hexString: "9CA3AF"))
                .padding(.leading, 4)
        }
    }
    
    // MARK: - Check if should show action buttons
    private func shouldShowActionButtons(for content: String) -> Bool {
        let lowercaseContent = content.lowercased()
        
        // First check: Message must have a structured plan format (multiple exercises/meals listed)
        // This is the strongest indicator of an actual plan
        
        // Check for structured workout plan (multiple exercises with sets x reps format)
        // Look for patterns like "3 sets x 10 reps" or "4 sets x 8-10 reps"
        let hasSetsXReps = lowercaseContent.contains("sets x") || lowercaseContent.contains("sets ×")
        let setsXRepsCount = lowercaseContent.components(separatedBy: "sets x").count + 
                             lowercaseContent.components(separatedBy: "sets ×").count
        // Also check for number patterns that indicate multiple exercises
        let hasMultipleSets = setsXRepsCount > 2
        // Check for exercise names followed by sets/reps (strong indicator of structured plan)
        let hasExerciseStructure = lowercaseContent.contains("sets") && 
                                   (lowercaseContent.contains("reps") || lowercaseContent.contains("rest"))
        let hasMultipleExercises = (hasSetsXReps && hasMultipleSets) || 
                                   (hasExerciseStructure && setsXRepsCount >= 2)
        
        // Check for structured meal plan (multiple meals with specific foods)
        let hasMultipleMeals = (lowercaseContent.contains("breakfast") && lowercaseContent.contains("lunch")) ||
                               (lowercaseContent.contains("lunch") && lowercaseContent.contains("dinner")) ||
                               (lowercaseContent.contains("breakfast") && lowercaseContent.contains("dinner"))
        
        // Check for multi-day plan structure
        let hasMultiDayStructure = lowercaseContent.contains("day 1") || 
                                   lowercaseContent.contains("day 2") ||
                                   lowercaseContent.contains("monday") && lowercaseContent.contains("tuesday")
        
        // Second check: Must end with plan confirmation question
        // Use flexible pattern matching instead of hardcoded phrases to support any language
        // Check if message ends with a question mark and contains confirmation-related keywords
        let hasQuestionMark = content.hasSuffix("?") || content.hasSuffix("？")
        let confirmationKeywords = [
            // English
            "think", "plan", "work", "look", "ready", "start", "go",
            // Chinese
            "觉得", "如何", "怎么样", "可以", "开始", "计划"
        ]
        let hasConfirmationKeyword = confirmationKeywords.contains { keyword in
            lowercaseContent.contains(keyword)
        }
        let endsWithQuestion = hasQuestionMark && hasConfirmationKeyword
        
        // Only show buttons if:
        // 1. Has clear structured plan (multiple exercises OR multiple meals OR multi-day structure) AND
        // 2. Ends with confirmation question
        // This prevents showing buttons for general questions that just mention keywords
        return (hasMultipleExercises || hasMultipleMeals || hasMultiDayStructure) && endsWithQuestion
    }
    
    // MARK: - Highlighted Text View (with purple numbers and red times)
    private func highlightedTextView(_ content: String) -> some View {
        // Remove markdown formatting (**, __, etc.)
        var cleanedContent = content
        cleanedContent = cleanedContent.replacingOccurrences(of: "**", with: "")
        cleanedContent = cleanedContent.replacingOccurrences(of: "__", with: "")
        cleanedContent = cleanedContent.replacingOccurrences(of: "##", with: "")
        
        // Build AttributedString
        var attributedString = AttributedString(cleanedContent)
        
        // Apply base color to all text first
        attributedString.foregroundColor = Color(hexString: "1F2937")
        
        // Pattern 1: Time patterns (e.g., "6am", "6:00 PM", "at 6pm", "6 o'clock")
        let timePattern = #"\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM|o['\u2019]?clock)\b"#
        if let timeRegex = try? NSRegularExpression(pattern: timePattern, options: []) {
            let timeMatches = timeRegex.matches(in: cleanedContent, range: NSRange(location: 0, length: cleanedContent.count))
            
            for match in timeMatches {
                if let range = Range(match.range, in: cleanedContent) {
                    if let attributedStart = AttributedString.Index(range.lowerBound, within: attributedString),
                       let attributedEnd = AttributedString.Index(range.upperBound, within: attributedString) {
                        let attributedRange = attributedStart..<attributedEnd
                        
                        attributedString[attributedRange].foregroundColor = Color(hexString: "EF4444") // Red
                        attributedString[attributedRange].font = .system(size: 16, weight: .semibold)
                    }
                }
            }
        }
        
        // Pattern 2: Numbers with optional units (e.g., "3", "10-12", "5.5", "150lbs", "3x12")
        let numberPattern = #"\b\d+(?:[-–]\d+)?(?:\.\d+)?(?:\s*(?:lbs?|kg|reps?|sets?|x|×|cal|g|miles?|km|ft|in|min|sec|%))?\b"#
        if let numberRegex = try? NSRegularExpression(pattern: numberPattern, options: [.caseInsensitive]) {
            let numberMatches = numberRegex.matches(in: cleanedContent, range: NSRange(location: 0, length: cleanedContent.count))
            
            // Highlight numbers (but skip if already highlighted as time)
            for match in numberMatches {
                if let range = Range(match.range, in: cleanedContent) {
                    if let attributedStart = AttributedString.Index(range.lowerBound, within: attributedString),
                       let attributedEnd = AttributedString.Index(range.upperBound, within: attributedString) {
                        let attributedRange = attributedStart..<attributedEnd
                        
                        // Only apply purple if not already red (time)
                        if attributedString[attributedRange].foregroundColor != Color(hexString: "EF4444") {
                            attributedString[attributedRange].foregroundColor = Color(hexString: "8B5CF6")
                            attributedString[attributedRange].font = .system(size: 16, weight: .semibold)
                        }
                    }
                }
            }
        }
        
        return Text(attributedString)
    }
    
    // MARK: - Workout Plan View
    private func workoutPlanView(_ plan: WorkoutPlanData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            highlightedTextView(message.content)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.exercises) { exercise in
                    HStack(spacing: 4) {
                        Text("•")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hexString: "374151"))
                        highlightedTextView("\(exercise.sets)×\(exercise.reps) \(exercise.name)")
                            .font(.system(size: 15))
                    }
                }
            }
            
            if let notes = plan.notes {
                highlightedTextView(notes)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hexString: "6B7280"))
                    .italic()
            }
            
            // Action buttons (only show if not already acted upon)
            if !message.actionTaken {
                HStack(spacing: 16) {
                    Button(action: {
                        onReject?(message)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Reject")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(hexString: "EF4444"))
                        .cornerRadius(20)
                    }
                    
                    Button(action: {
                        onAccept?(message)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Add")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(hexString: "10B981"))
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(hexString: "F3F4F6"))
        .cornerRadius(20)
        .frame(maxWidth: 280, alignment: .leading)
    }
    
    // MARK: - Nutrition Plan View
    private func nutritionPlanView(_ plan: NutritionPlanData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            highlightedTextView(message.content)
                .font(.system(size: 16))
            
            // Display meals
            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.meals) { meal in
                    VStack(alignment: .leading, spacing: 4) {
                        // Meal time and name
                        HStack {
                            highlightedTextView("\(meal.time) - \(meal.name)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hexString: "374151"))
                        }
                        
                        // Food items
                        ForEach(meal.foods, id: \.self) { food in
                            HStack(spacing: 4) {
                                Text("•")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hexString: "6B7280"))
                                Text(food)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hexString: "6B7280"))
                            }
                        }
                        
                        // Macros
                        highlightedTextView("\(meal.calories)kcal | P: \(Int(meal.protein))g | C: \(Int(meal.carbs))g | F: \(Int(meal.fat))g")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hexString: "8B5CF6"))
                    }
                    .padding(.bottom, 4)
                }
            }
            
            // Daily total
            if plan.dailyKcalTarget > 0 {
                highlightedTextView("Daily Total: \(plan.dailyKcalTarget)kcal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hexString: "10B981"))
                    .padding(.top, 4)
            }
            
            if let notes = plan.notes {
                highlightedTextView(notes)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hexString: "6B7280"))
                    .italic()
            }
            
            // Action buttons (only show if not already acted upon)
            if !message.actionTaken {
                HStack(spacing: 16) {
                    Button(action: {
                        onReject?(message)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Reject")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(hexString: "EF4444"))
                        .cornerRadius(20)
                    }
                    
                    Button(action: {
                        onAccept?(message)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Add")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(hexString: "10B981"))
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(hexString: "F3F4F6"))
        .cornerRadius(20)
        .frame(maxWidth: 300, alignment: .leading)
    }
    
    // MARK: - Multi-Day Plan View
    private func multiDayPlanView(_ plan: MultiDayPlanData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            highlightedTextView(message.content)
                .font(.system(size: 16))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(plan.days) { day in
                        VStack(alignment: .leading, spacing: 8) {
                            // Day header
                            Text(day.dayName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(hexString: "8B5CF6"))
                            
                            Text(day.date)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hexString: "6B7280"))
                            
                            Divider()
                            
                            // Show workout or nutrition summary
                            if let workout = day.workout {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("💪 Workout")
                                        .font(.system(size: 13, weight: .semibold))
                                    ForEach(workout.exercises.prefix(3)) { exercise in
                                        Text("• \(exercise.name)")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hexString: "374151"))
                                    }
                                    if workout.exercises.count > 3 {
                                        Text("+ \(workout.exercises.count - 3) more")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(hexString: "6B7280"))
                                    }
                                }
                            }
                            
                            if let nutrition = day.nutrition {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("🥗 Nutrition")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("\(nutrition.dailyKcalTarget)kcal")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hexString: "10B981"))
                                    Text("\(nutrition.meals.count) meals")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hexString: "6B7280"))
                                }
                            }
                        }
                        .padding(12)
                        .frame(width: 160)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            
            if let notes = plan.notes {
                highlightedTextView(notes)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hexString: "6B7280"))
                    .italic()
                    .padding(.top, 4)
            }
            
            // Action buttons (only show if not already acted upon)
            if !message.actionTaken {
                HStack(spacing: 16) {
                    Button(action: {
                        onReject?(message)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Reject")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(hexString: "EF4444"))
                        .cornerRadius(20)
                    }
                    
                    Button(action: {
                        onAccept?(message)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Add All to Tasks")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(hexString: "10B981"))
                        .cornerRadius(20)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(hexString: "F3F4F6"))
        .cornerRadius(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        ChatBubble(message: FirebaseChatMessage(
            content: "Hi! I'm your MODO wellness assistant. I can help you with diet planning, fitness routines, and healthy lifestyle tips. What would you like to know?",
            isFromUser: false
        ))
        
        ChatBubble(message: FirebaseChatMessage(
            content: "add a work out plan for tomorrow.",
            isFromUser: true
        ))
        
        ChatBubble(message: FirebaseChatMessage(
            content: "Here's your workout plan for tomorrow 💪:",
            isFromUser: false,
            messageType: "workout_plan",
            workoutPlan: WorkoutPlanData(
                date: "2025-10-31",
                goal: "muscle_gain",
                dailyKcalTarget: 2700,
                exercises: [
                    WorkoutPlanData.Exercise(name: "Squats", sets: 3, reps: "10", restSec: 90),
                    WorkoutPlanData.Exercise(name: "Push-ups", sets: 3, reps: "8", restSec: 60),
                    WorkoutPlanData.Exercise(name: "Dumbbell Rows", sets: 3, reps: "12", restSec: 90),
                    WorkoutPlanData.Exercise(name: "Brisk walk or light jog", sets: 1, reps: "15 min", restSec: nil)
                ],
                notes: "Sounds good?"
            )
        ))
    }
    .background(Color.white)
}

