import SwiftUI
import SwiftData

struct InsightsPageView: View {
    @Binding var selectedTab: Tab
    @StateObject private var coachService = ModoCoachService()
    @StateObject private var aiTaskGenerator = AITaskGenerator()  // ✅ Unified AI task generation service
    @State private var inputText: String = ""
    @State private var showClearConfirmation = false
    @State private var showAttachmentMenu = false
    @State private var showPhotoPicker = false
    @State private var selectedImage: UIImage?
    @State private var showTaskCreatedToast = false
    @Query private var userProfiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    
    private var currentUserProfile: UserProfile? {
        userProfiles.first
    }
    
    // Callback to notify MainPageView about task creation
    var onWorkoutPlanAccepted: ((Date, String, [WorkoutPlanData.Exercise]) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            ZStack {
                // Center content
                VStack(spacing: 2) {
                    Text("Moder")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hexString: "101828"))
                    Text("Your wellness assistant")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hexString: "6B7280"))
                }
                
                // Clear History Button (positioned on right)
                HStack {
                    Spacer()
                    Button(action: {
                        showClearConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hexString: "6B7280"))
                            .frame(width: 36, height: 36)
                    }
                    .padding(.trailing, 16)
                }
            }
            .frame(height: 60)
            .padding(.top, 12)
            .background(Color.white)
            
            Divider()
                .background(Color(hexString: "E5E7EB"))
            
            // MARK: - Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(coachService.messages, id: \.id) { message in
                            ChatBubble(
                                message: message,
                                onAccept: { msg in
                                    // ✅ Use unified AITaskGenerator (generates detailed tasks with individual exercises/foods)
                                    handleAcceptWithAIGenerator(for: msg)
                                    
                                    // Add confirmation message to chat (without creating tasks again)
                                    let confirmMessage = ChatMessage(
                                        content: "Great! I've created your personalized plan with detailed exercises and meals. You'll find it in your Main Page! 💪",
                                        isFromUser: false
                                    )
                                    coachService.messages.append(confirmMessage)
                                    coachService.saveMessage(confirmMessage)
                                },
                                onReject: { msg in
                                    coachService.rejectWorkoutPlan(for: msg)
                                }
                            )
                            .id(message.id)
                        }
                        
                        // Loading indicator
                        if coachService.isProcessing {
                            HStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hexString: "8B5CF6"), Color(hexString: "6366F1")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "figure.strengthtraining.traditional")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                    )
                                
                                HStack(spacing: 8) {
                                    ForEach(0..<3) { index in
                                        Circle()
                                            .fill(Color(hexString: "9CA3AF"))
                                            .frame(width: 8, height: 8)
                                            .scaleEffect(coachService.isProcessing ? 1 : 0.5)
                                            .animation(
                                                Animation.easeInOut(duration: 0.6)
                                                    .repeatForever()
                                                    .delay(Double(index) * 0.2),
                                                value: coachService.isProcessing
                                            )
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(hexString: "F3F4F6"))
                                .cornerRadius(20)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .id("loading")
                        }
                    }
                    .padding(.vertical, 16)
                }
                .onChange(of: coachService.messages.count) { _, _ in
                    if let lastMessage = coachService.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: coachService.isProcessing) { _, isProcessing in
                    if isProcessing {
                        withAnimation {
                            proxy.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color.white)

            // MARK: - Input Field + Buttons
            ZStack(alignment: .bottomLeading) {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color(hexString: "E5E7EB"))
                    
                    HStack(spacing: 12) {
                        // Placeholder for plus button space
                        Color.clear
                            .frame(width: 40, height: 40)

                        CustomInputField(
                            placeholder: "Ask questions or add photos...",
                            text: $inputText
                        )

                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(
                                    inputText.isEmpty ? Color.gray.opacity(0.5) : Color.purple.opacity(0.7)
                                )
                                .clipShape(Circle())
                        }
                        .disabled(inputText.isEmpty || coachService.isProcessing)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.white)
                }
                
                // Floating Plus Button with Expandable Menu
                ZStack {
                    VStack(spacing: 0) {
                        if showAttachmentMenu {
                            Color.clear
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(hexString: "8B5CF6"))
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        showAttachmentMenu = false
                                    }
                                    showPhotoPicker = true
                                }
                            
                            Divider()
                                .frame(width: 30)
                            
                            Color.clear
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "doc")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(hexString: "8B5CF6"))
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        showAttachmentMenu = false
                                    }
                                    // TODO: Handle file selection
                                    print("File selected")
                                }
                            
                            Divider()
                                .frame(width: 30)
                        }
                        
                        Color.clear
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 18))
                                    .foregroundColor(.black)
                                    .rotationEffect(.degrees(showAttachmentMenu ? 45 : 0))
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    showAttachmentMenu.toggle()
                                }
                            }
                    }
                }
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color(hexString: "E5E7EB"), lineWidth: 1))
                .padding(.leading, 24)
                .padding(.bottom, 16)
            }

            // MARK: - Bottom Navigation Bar
            BottomBar(selectedTab: $selectedTab)
        }
        .background(Color(hexString: "F9FAFB").ignoresSafeArea())
        .onTapGesture {
            if showAttachmentMenu {
                withAnimation {
                    showAttachmentMenu = false
                }
            }
        }
        .onAppear {
            coachService.loadHistory(from: modelContext, userProfile: currentUserProfile)
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                handleImageSelection(image)
                selectedImage = nil
            }
        }
        .alert("Clear Chat History", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                coachService.clearHistory()
            }
        } message: {
            Text("Are you sure you want to clear all chat history? This action cannot be undone.")
        }
    }
    
    // MARK: - Handle Image Selection
    private func handleImageSelection(_ image: UIImage) {
        // Show user message
        let userMessage = "📷 [Food photo uploaded]"
        coachService.sendUserMessage(userMessage)
        
        // Convert image to base64 for API
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { return }
        let base64String = imageData.base64EncodedString()
        
        // Send to OpenAI Vision API for food analysis
        Task {
            await coachService.analyzeFoodImage(base64Image: base64String, userProfile: currentUserProfile)
        }
    }
    
    // MARK: - Send Message
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        coachService.sendMessage(inputText, userProfile: currentUserProfile)
        inputText = ""
    }
    
    // MARK: - Handle Accept with Unified AI Generator (NEW)
    private func handleAcceptWithAIGenerator(for message: ChatMessage) {
        print("🎯 Accept button pressed - Using unified AITaskGenerator")
        
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
    
    // MARK: - Handle Workout Generation
    private func handleWorkoutGeneration(for date: Date) {
        print("🏋️ Generating workout task for \(date)")
        
        aiTaskGenerator.generateWorkoutTask(
            for: date,
            userProfile: currentUserProfile
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let aiTask):
                    print("   ✅ Workout task generated successfully")
                    self.addAIGeneratedTask(aiTask)
                case .failure(let error):
                    print("   ❌ Failed to generate workout: \(error.localizedDescription)")
                    // Fallback to old method if needed
                }
            }
        }
    }
    
    // MARK: - Handle Nutrition Generation
    private func handleNutritionGeneration(for date: Date) {
        print("🍽️ Generating nutrition tasks for \(date)")
        
        // Generate all 3 meals
        aiTaskGenerator.generateSpecificNutritionTasks(
            ["breakfast", "lunch", "dinner"],
            for: date,
            userProfile: currentUserProfile
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let aiTasks):
                    print("   ✅ Generated \(aiTasks.count) nutrition tasks")
                    for task in aiTasks {
                        self.addAIGeneratedTask(task)
                    }
                case .failure(let error):
                    print("   ❌ Failed to generate nutrition: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Handle Both Tasks Generation
    private func handleBothTasksGeneration(for date: Date) {
        print("🏋️🍽️ Generating both workout and nutrition for \(date)")
        
        // Generate workout
        handleWorkoutGeneration(for: date)
        
        // Generate nutrition
        handleNutritionGeneration(for: date)
    }
    
    // MARK: - Handle Multi-Day Generation
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
    
    // MARK: - Add AI Generated Task (Unified Method)
    private func addAIGeneratedTask(_ aiTask: AIGeneratedTask) {
        print("➕ Adding AI generated task: \(aiTask.title) for \(aiTask.date)")
        
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
            // Each AIGeneratedTask.nutrition should contain one meal
            guard let meal = aiTask.meals.first else { return }
            
            // Convert food items to detailed array (similar to exercises)
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
                "foodItems": foodItemsData,  // ✅ Add detailed food items array
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showTaskCreatedToast = false
        }
    }
    
    // MARK: - Create Task from Workout Plan (OLD - Keep for compatibility)
    private func createTaskFromWorkoutPlan(_ plan: WorkoutPlanData) {
        // Post notification to MainPageView to create the task
        let userInfo: [String: Any] = [
            "date": plan.date,
            "goal": plan.goal,
            "exercises": plan.exercises.map { exercise in
                [
                    "name": exercise.name,
                    "sets": exercise.sets,
                    "reps": exercise.reps,
                    "restSec": exercise.restSec ?? 60,
                    "targetRPE": exercise.targetRPE ?? 7
                ]
            },
            "isAIGenerated": true  // Mark as AI-generated from InsightPageView
        ]
        
        NotificationCenter.default.post(
            name: NSNotification.Name("CreateWorkoutTask"),
            object: nil,
            userInfo: userInfo
        )
        
        showTaskCreatedToast = true
        
        // Auto dismiss toast after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showTaskCreatedToast = false
        }
    }
    
    // MARK: - Extract Date from Recent Messages (Used by new unified AI generator)
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
        return today // Changed from nil to today
    }
    
    // MARK: - OLD TEXT PARSING METHODS REMOVED
    // All old text parsing methods (createTaskFromTextPlan, createWorkoutTask, createNutritionTask, etc.)
    // have been removed and replaced with unified AITaskGenerator calls.
    // See handleAcceptWithAIGenerator() for the new implementation.
}

// MARK: - Preview
#Preview {
    StatefulPreviewWrapper(Tab.insights) { selection in
        InsightsPageView(selectedTab: selection)
    }
}
