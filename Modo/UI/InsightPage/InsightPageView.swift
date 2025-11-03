import SwiftUI
import SwiftData

struct InsightsPageView: View {
    @Binding var selectedTab: Tab
    @StateObject private var coachService = ModoCoachService()
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
                                    coachService.acceptWorkoutPlan(
                                        for: msg,
                                        onTaskCreated: { plan in
                                            createTaskFromWorkoutPlan(plan)
                                        },
                                        onTextPlanAccepted: {
                                            createTaskFromTextPlan(msg.content)
                                        }
                                    )
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
    
    // MARK: - Create Task from Workout Plan
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
            }
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
    
    // MARK: - Extract Time from Recent Messages
    private func extractTimeFromRecentMessages() -> String? {
        // Look at the last 5 user messages for time mentions
        let recentUserMessages = coachService.messages.filter { $0.isFromUser }.suffix(5)
        
        for message in recentUserMessages.reversed() {
            let content = message.content.lowercased()
            
            // Common time patterns
            let timePatterns = [
                // "6am", "6 am", "6:00am"
                #"(\d{1,2})\s*(?::?\s*(\d{2}))?\s*(am|pm)"#,
                // "at 6", "at 18:00"
                #"at\s+(\d{1,2})(?::(\d{2}))?"#,
                // "6 o'clock"
                #"(\d{1,2})\s*o['\u2019]?clock"#
            ]
            
            for pattern in timePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) {
                    
                    let nsString = content as NSString
                    if let hourRange = Range(match.range(at: 1), in: content),
                       let hour = Int(content[hourRange]) {
                        
                        var minute = 0
                        if match.numberOfRanges > 2, let minuteRange = Range(match.range(at: 2), in: content) {
                            minute = Int(content[minuteRange]) ?? 0
                        }
                        
                        var isPM = false
                        if match.numberOfRanges > 3, let ampmRange = Range(match.range(at: 3), in: content) {
                            isPM = content[ampmRange].lowercased().contains("pm")
                        }
                        
                        // Adjust hour for 12-hour format
                        var finalHour = hour
                        if isPM && hour < 12 {
                            finalHour += 12
                        } else if !isPM && hour == 12 {
                            finalHour = 0
                        }
                        
                        // Format time
                        let timeFormatter = DateFormatter()
                        timeFormatter.dateFormat = "hh:mm a"
                        if let date = Calendar.current.date(bySettingHour: finalHour, minute: minute, second: 0, of: Date()) {
                            return timeFormatter.string(from: date)
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Create Task from Text Plan
    private func createTaskFromTextPlan(_ content: String) {
        let lines = content.components(separatedBy: .newlines)
        
        // Detect plan type
        // Check for nutrition plan - must have meal keywords
        // NOTE: Don't use "calories" alone as it appears in workout plans too
        let lowercaseContent = content.lowercased()
        let isNutritionPlan = lowercaseContent.contains("meal") || 
                              lowercaseContent.contains("breakfast") ||
                              lowercaseContent.contains("lunch") ||
                              lowercaseContent.contains("dinner") ||
                              lowercaseContent.contains("snack") ||
                              lowercaseContent.contains("kcal target") ||
                              lowercaseContent.contains("daily calories")
        
        let isMultiDayPlan = content.lowercased().contains("day 1") ||
                             content.lowercased().contains("day 2") ||
                             content.lowercased().contains("monday") ||
                             content.lowercased().contains("tuesday")
        
        print("🔍 Plan Type Detection:")
        print("   isNutritionPlan: \(isNutritionPlan)")
        print("   isMultiDayPlan: \(isMultiDayPlan)")
        
        if isMultiDayPlan {
            print("   ➡️ Creating multi-day tasks")
            createMultiDayTasks(from: content, isNutrition: isNutritionPlan)
        } else if isNutritionPlan {
            print("   ➡️ Creating nutrition task")
            createNutritionTask(from: content)
        } else {
            print("   ➡️ Creating workout task")
            createWorkoutTask(from: content)
        }
    }
    
    // MARK: - Create Workout Task
    private func createWorkoutTask(from content: String) {
        // Parse workout details from content
        let lines = content.components(separatedBy: .newlines)
        var exercises: [[String: Any]] = []
        var workoutDescription = ""
        var workoutTheme = "Workout"
        var workoutTime = extractTimeFromRecentMessages() ?? "09:00 AM"
        
        // Extract workout theme/title
        for line in lines {
            let lowercaseLine = line.lowercased()
            if (lowercaseLine.contains("workout") || lowercaseLine.contains("training")) 
                && !lowercaseLine.contains("what do you think")
                && workoutDescription.isEmpty {
                workoutTheme = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: ":", with: "")
                break
            }
        }
        
        // Parse exercise lines (format: "Exercise Name: 3 sets x 10-12 reps, 60 seconds rest")
        for line in lines {
            if line.contains("x") || line.contains("×") {
                let parsedExercise = parseExerciseLine(line)
                exercises.append(parsedExercise)
            }
        }
        
        // If no exercises found, use default
        if exercises.isEmpty {
            exercises = [[
                "name": "Custom Workout",
                "sets": 3,
                "reps": "10-12",
                "restSec": 60,
                "durationMin": 15,
                "calories": 150
            ]]
        }
        
        // Build task description (list all exercises with details)
        let taskDescription = exercises.map { exercise in
            let name = exercise["name"] as? String ?? "Exercise"
            let sets = exercise["sets"] as? Int ?? 3
            let reps = exercise["reps"] as? String ?? "10"
            let rest = exercise["restSec"] as? Int ?? 60
            let duration = exercise["durationMin"] as? Int ?? 0
            let calories = exercise["calories"] as? Int ?? 0
            return "\(name): \(sets) sets x \(reps) reps, \(rest)s rest (\(duration)min, \(calories)cal)"
        }.joined(separator: "\n")
        
        print("📝 Task description:")
        print(taskDescription)
        
        // Calculate pure workout time (sets + reps + rest)
        let pureWorkoutTime = exercises.reduce(0) { sum, exercise in
            sum + (exercise["durationMin"] as? Int ?? 0)
        }
        
        // Calculate total training duration (including warm-up, transitions, cool-down)
        // Multiply by 1.9 to account for:
        // - Warm-up: ~10 min
        // - Exercise transitions: ~2 min each
        // - Cool-down/stretching: ~5 min
        let totalDuration = Int(Double(pureWorkoutTime) * 1.9)
        
        // Update each exercise's duration proportionally
        let durationMultiplier = 1.9
        let adjustedExercises = exercises.map { exercise -> [String: Any] in
            var adjusted = exercise
            if let pureDuration = exercise["durationMin"] as? Int {
                let adjustedDuration = Int(Double(pureDuration) * durationMultiplier)
                adjusted["durationMin"] = adjustedDuration
            }
            return adjusted
        }
        
        // Calculate total calories
        let totalCalories = exercises.reduce(0) { sum, exercise in
            sum + (exercise["calories"] as? Int ?? 0)
        }
        
        print("✅ Total workout summary:")
        print("   Pure workout time: \(pureWorkoutTime) min")
        print("   Total duration (with warm-up/cool-down): \(totalDuration) min")
        print("   Calories: \(totalCalories) cal")
        print("   Exercises: \(exercises.count)")
        
        // Verify adjusted durations sum correctly
        let adjustedTotal = adjustedExercises.reduce(0) { sum, exercise in
            sum + (exercise["durationMin"] as? Int ?? 0)
        }
        print("   Adjusted exercises total: \(adjustedTotal) min")
        
        // Create notification with complete workout data
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        let userInfo: [String: Any] = [
            "date": dateString,
            "time": workoutTime,
            "duration": String(totalDuration),
            "totalDuration": totalDuration,  // Total training time (with warm-up/cool-down)
            "description": taskDescription,
            "theme": workoutTheme,
            "goal": "general_fitness",
            "exercises": adjustedExercises,  // Use adjusted exercises with proportional durations
            "totalCalories": totalCalories,
            "isNutrition": false
        ]
        
        NotificationCenter.default.post(
            name: NSNotification.Name("CreateWorkoutTask"),
            object: nil,
            userInfo: userInfo
        )
        
        showTaskCreatedToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showTaskCreatedToast = false
        }
    }
    
    // MARK: - Parse Exercise Line
    private func parseExerciseLine(_ line: String) -> [String: Any] {
        var exerciseName = ""
        var sets = 3
        var reps = "10"
        var restSec = 60
        
        // Extract exercise name - try multiple strategies
        
        // Strategy 1: Split by colon (e.g., "Bench Press: 4 sets x 10 reps")
        if line.contains(":") {
            let parts = line.components(separatedBy: ":")
            if let firstPart = parts.first {
                var cleanName = firstPart
                cleanName = cleanName.replacingOccurrences(of: "•", with: "")
                cleanName = cleanName.replacingOccurrences(of: "-", with: "")
                cleanName = cleanName.replacingOccurrences(of: ".", with: "")
                cleanName = cleanName.replacingOccurrences(of: "\\d+\\.", with: "", options: .regularExpression)
                cleanName = cleanName.trimmingCharacters(in: .whitespaces)
                if !cleanName.isEmpty && cleanName.count > 2 {
                    exerciseName = cleanName
                }
            }
        }
        
        // Strategy 2: Extract text before first number or "x" pattern
        if exerciseName.isEmpty {
            // Remove bullet points and numbers at start
            var cleanLine = line
            cleanLine = cleanLine.replacingOccurrences(of: "^[•\\-\\.\\d]+\\s*", with: "", options: .regularExpression)
            
            // Find position of first "x" or "×" or digit followed by "sets"
            if let regex = try? NSRegularExpression(pattern: #"^(.+?)(?:\d+\s*(?:sets?|x|×))"#, options: .caseInsensitive) {
                let nsString = cleanLine as NSString
                if let match = regex.firstMatch(in: cleanLine, range: NSRange(location: 0, length: nsString.length)) {
                    if let nameRange = Range(match.range(at: 1), in: cleanLine) {
                        var name = String(cleanLine[nameRange]).trimmingCharacters(in: .whitespaces)
                        name = name.trimmingCharacters(in: CharacterSet(charactersIn: ":-,"))
                        if !name.isEmpty && name.count > 2 {
                            exerciseName = name
                        }
                    }
                }
            }
        }
        
        // Strategy 3: If still empty, try to get text before any numbers
        if exerciseName.isEmpty {
            let components = line.components(separatedBy: CharacterSet.decimalDigits)
            if let firstPart = components.first {
                var cleanName = firstPart
                cleanName = cleanName.replacingOccurrences(of: "•", with: "")
                cleanName = cleanName.replacingOccurrences(of: "-", with: "")
                cleanName = cleanName.replacingOccurrences(of: ".", with: "")
                cleanName = cleanName.replacingOccurrences(of: ":", with: "")
                cleanName = cleanName.trimmingCharacters(in: .whitespaces)
                if !cleanName.isEmpty && cleanName.count > 2 {
                    exerciseName = cleanName
                }
            }
        }
        
        // Fallback: use original line trimmed
        if exerciseName.isEmpty {
            exerciseName = line.trimmingCharacters(in: .whitespaces)
        }
        
        // Extract sets (pattern: "3 sets" or "3x")
        if let setsRegex = try? NSRegularExpression(pattern: #"(\d+)\s*(?:sets?|x|×)"#, options: .caseInsensitive) {
            let nsString = line as NSString
            if let match = setsRegex.firstMatch(in: line, range: NSRange(location: 0, length: nsString.length)) {
                if let setsRange = Range(match.range(at: 1), in: line) {
                    sets = Int(line[setsRange]) ?? 3
                }
            }
        }
        
        // Extract reps (pattern: "10 reps" or "x10" or "10-12")
        if let repsRegex = try? NSRegularExpression(pattern: #"x\s*(\d+(?:-\d+)?)|(\d+(?:-\d+)?)\s*reps?"#, options: .caseInsensitive) {
            let nsString = line as NSString
            if let match = repsRegex.firstMatch(in: line, range: NSRange(location: 0, length: nsString.length)) {
                for i in 1..<match.numberOfRanges {
                    if let repsRange = Range(match.range(at: i), in: line), match.range(at: i).length > 0 {
                        reps = String(line[repsRange])
                        break
                    }
                }
            }
        }
        
        // Extract rest time (pattern: "60 seconds rest" or "60s rest")
        if let restRegex = try? NSRegularExpression(pattern: #"(\d+)\s*(?:seconds?|secs?|s)\s*rest"#, options: .caseInsensitive) {
            let nsString = line as NSString
            if let match = restRegex.firstMatch(in: line, range: NSRange(location: 0, length: nsString.length)) {
                if let restRange = Range(match.range(at: 1), in: line) {
                    restSec = Int(line[restRange]) ?? 60
                }
            }
        }
        
        // Extract calories from AI response (pattern: "~50 calories" or "50 cal")
        var calories = 0
        var caloriesFromAI = false
        if let caloriesRegex = try? NSRegularExpression(pattern: #"[~]?(\d+)\s*(?:calories|cal)\b"#, options: .caseInsensitive) {
            let nsString = line as NSString
            if let match = caloriesRegex.firstMatch(in: line, range: NSRange(location: 0, length: nsString.length)) {
                if let caloriesRange = Range(match.range(at: 1), in: line) {
                    calories = Int(line[caloriesRange]) ?? 0
                    if calories > 0 {
                        caloriesFromAI = true
                    }
                }
            }
        }
        
        // Calculate duration
        let avgReps = extractAvgReps(from: reps)
        
        // Working time: ~3-4 seconds per rep (including eccentric and concentric phases)
        let workTimePerSet = avgReps * 4  // More realistic: 4 seconds per rep
        
        // Total time = (work + rest) × (sets - 1) + last set work
        // Last set doesn't need rest period
        let totalDurationSec: Int
        if sets > 1 {
            totalDurationSec = (workTimePerSet + restSec) * (sets - 1) + workTimePerSet
        } else {
            totalDurationSec = workTimePerSet
        }
        let durationMin = max(1, totalDurationSec / 60)
        
        // If AI didn't provide calories, use fallback calculation
        if !caloriesFromAI || calories == 0 {
            calories = durationMin * 7  // Fallback: ~7 cal/min for strength training
            caloriesFromAI = false
        }
        
        let caloriesSource = caloriesFromAI ? "✅ AI provided" : "⚠️ Calculated (fallback)"
        print("📊 Parsed exercise: \(exerciseName)")
        print("   Sets: \(sets), Reps: \(reps), Rest: \(restSec)s")
        print("   Duration: \(durationMin)min, Calories: \(calories)cal (\(caloriesSource))")
        
        return [
            "name": exerciseName,
            "sets": sets,
            "reps": reps,
            "restSec": restSec,
            "durationMin": durationMin,
            "calories": calories
        ]
    }
    
    // MARK: - Extract Average Reps
    private func extractAvgReps(from repsString: String) -> Int {
        // Handle ranges like "10-12" -> return average
        let numbers = repsString.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
        
        if numbers.count >= 2 {
            return (numbers[0] + numbers[1]) / 2
        } else if let first = numbers.first {
            return first
        }
        return 10 // default
    }
    
    // MARK: - Create Nutrition Task
    private func createNutritionTask(from content: String) {
        let lines = content.components(separatedBy: .newlines)
        var mealTime = extractTimeFromRecentMessages() ?? "08:00 AM"
        var totalCalories = 0
        var mealsList: [String] = []
        
        // Extract calories
        for line in lines {
            if line.lowercased().contains("kcal") || line.lowercased().contains("calories") {
                let components = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
                if let calories = components.compactMap({ Int($0) }).first, calories > 100 {
                    totalCalories = calories
                }
            }
            
            // Extract meal names
            if line.lowercased().contains("breakfast") || 
               line.lowercased().contains("lunch") ||
               line.lowercased().contains("dinner") ||
               line.lowercased().contains("snack") {
                mealsList.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        if totalCalories == 0 {
            totalCalories = 2000 // Default
        }
        
        let taskDescription: String
        if !mealsList.isEmpty {
            taskDescription = mealsList.joined(separator: "\n")
        } else {
            taskDescription = "Daily nutrition plan - \(totalCalories)kcal"
        }
        
        // Create notification
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        let userInfo: [String: Any] = [
            "date": dateString,
            "time": mealTime,
            "duration": "0", // Nutrition doesn't have duration
            "description": taskDescription,
            "goal": "nutrition",
            "exercises": [], // Empty for nutrition
            "isNutrition": true,
            "calories": totalCalories
        ]
        
        NotificationCenter.default.post(
            name: NSNotification.Name("CreateWorkoutTask"),
            object: nil,
            userInfo: userInfo
        )
        
        showTaskCreatedToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showTaskCreatedToast = false
        }
    }
    
    // MARK: - Create Multi-Day Tasks
    private func createMultiDayTasks(from content: String, isNutrition: Bool) {
        let lines = content.components(separatedBy: .newlines)
        var currentDayIndex = 0
        var dayPlans: [(day: String, content: [String])] = []
        var currentDayContent: [String] = []
        var currentDayName = ""
        
        // Parse multi-day structure
        for line in lines {
            let lowercaseLine = line.lowercased()
            
            // Detect day headers
            if lowercaseLine.contains("day 1") || lowercaseLine.contains("monday") {
                if !currentDayContent.isEmpty && !currentDayName.isEmpty {
                    dayPlans.append((currentDayName, currentDayContent))
                }
                currentDayName = line.trimmingCharacters(in: .whitespacesAndNewlines)
                currentDayContent = []
                currentDayIndex = 1
            } else if lowercaseLine.contains("day 2") || lowercaseLine.contains("tuesday") {
                if !currentDayContent.isEmpty && !currentDayName.isEmpty {
                    dayPlans.append((currentDayName, currentDayContent))
                }
                currentDayName = line.trimmingCharacters(in: .whitespacesAndNewlines)
                currentDayContent = []
                currentDayIndex = 2
            } else if lowercaseLine.contains("day 3") || lowercaseLine.contains("wednesday") ||
                      lowercaseLine.contains("day 4") || lowercaseLine.contains("thursday") ||
                      lowercaseLine.contains("day 5") || lowercaseLine.contains("friday") ||
                      lowercaseLine.contains("day 6") || lowercaseLine.contains("saturday") ||
                      lowercaseLine.contains("day 7") || lowercaseLine.contains("sunday") {
                if !currentDayContent.isEmpty && !currentDayName.isEmpty {
                    dayPlans.append((currentDayName, currentDayContent))
                }
                currentDayName = line.trimmingCharacters(in: .whitespacesAndNewlines)
                currentDayContent = []
                currentDayIndex += 1
            } else if !currentDayName.isEmpty {
                currentDayContent.append(line)
            }
        }
        
        // Add last day
        if !currentDayContent.isEmpty && !currentDayName.isEmpty {
            dayPlans.append((currentDayName, currentDayContent))
        }
        
        // Create task for each day
        let calendar = Calendar.current
        let today = Date()
        
        for (index, plan) in dayPlans.enumerated() {
            let dayDate = calendar.date(byAdding: .day, value: index, to: today) ?? today
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: dayDate)
            
            let dayContent = plan.content.joined(separator: "\n")
            
            if isNutrition {
                // Create nutrition task for this day
                let userInfo: [String: Any] = [
                    "date": dateString,
                    "time": "08:00 AM",
                    "duration": "0",
                    "description": "Day \(index + 1) Nutrition Plan\n\(dayContent)",
                    "goal": "nutrition",
                    "exercises": [],
                    "isNutrition": true,
                    "calories": 2000
                ]
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("CreateWorkoutTask"),
                    object: nil,
                    userInfo: userInfo
                )
            } else {
                // Create workout task for this day
                let userInfo: [String: Any] = [
                    "date": dateString,
                    "time": extractTimeFromRecentMessages() ?? "09:00 AM",
                    "duration": "60",
                    "description": "Day \(index + 1) Workout\n\(dayContent)",
                    "goal": "general_fitness",
                    "exercises": [["name": "Day \(index + 1) Workout", "sets": 3, "reps": "10-12", "restSec": 60, "targetRPE": 7]]
                ]
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("CreateWorkoutTask"),
                    object: nil,
                    userInfo: userInfo
                )
            }
        }
        
        showTaskCreatedToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showTaskCreatedToast = false
        }
    }
}

// MARK: - Preview
#Preview {
    StatefulPreviewWrapper(Tab.insights) { selection in
        InsightsPageView(selectedTab: selection)
    }
}
