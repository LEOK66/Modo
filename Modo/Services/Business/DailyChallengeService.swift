import Foundation
import Combine
import FirebaseAuth
import FirebaseDatabase

/// Daily Challenge Service - Manages daily challenge state and synchronization
final class DailyChallengeService: ObservableObject, ChallengeServiceProtocol {
    // Current challenge
    @Published var currentChallenge: DailyChallenge?
    @Published var isChallengeCompleted: Bool = false
    @Published var isChallengeAddedToTasks: Bool = false
    @Published var completedAt: Date? = nil // Track when challenge was completed
    @Published var isLocked: Bool = false
    
    // Track if completion toast has been shown for current challenge
    @Published var hasShownCompletionToast: Bool = false
    
    // User data availability check
    @Published var hasMinimumUserData: Bool = false
    
    // AI generation state
    @Published var isGeneratingChallenge: Bool = false
    @Published var challengeGenerationError: String? = nil
    
    // Task ID associated with the current challenge
    private var challengeTaskId: UUID?
    
    // Firebase listener handle
    private var completionObserverHandle: DatabaseHandle?
    
    // Track if challenge has been loaded to avoid redundant loads
    private var hasLoadedChallenge: Bool = false
    private var lastLoadedDate: Date? = nil
    
    // Database service for Firebase operations
    private let databaseService: DatabaseServiceProtocol
    
    // User profile service for checking data availability (optional - injected)
    private weak var userProfileService: UserProfileService?
    
    // AI Services
    private let aiService = FirebaseAIService.shared
    private let promptBuilder = AIPromptBuilder()
    private let responseParser = AIResponseParser()
    
    // Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    private var profileObserverCancellable: AnyCancellable?
    
    /// Initialize DailyChallengeService with dependencies
    /// - Parameters:
    ///   - databaseService: Database service for Firebase operations (defaults to shared instance)
    ///   - userProfileService: User profile service for data availability checks (optional)
    init(databaseService: DatabaseServiceProtocol = DatabaseService.shared, userProfileService: UserProfileService? = nil) {
        self.databaseService = databaseService
        self.userProfileService = userProfileService
        
        // ✅ Immediately check user data availability on init
        self.hasMinimumUserData = userProfileService?.currentProfile?.hasMinimumDataForDailyChallenge() ?? false
        
        // ✅ Automatically update when profile changes
        setupProfileObserver()
    }
    
    /// Setup observer for profile changes
    private func setupProfileObserver() {
        guard let userProfileService = userProfileService else {
            // No warning needed - profile service will be injected later when user logs in
            return
        }
        
        profileObserverCancellable = userProfileService.$currentProfile
            .sink { [weak self] newProfile in
                guard let self = self else { return }
                let newValue = newProfile?.hasMinimumDataForDailyChallenge() ?? false
                
                // Check if data availability changed
                if self.hasMinimumUserData != newValue {
                    let previousValue = self.hasMinimumUserData
                    self.hasMinimumUserData = newValue
                    
                    // ✅ If user just completed their profile (false → true), reload challenge
                    if !previousValue && newValue {
                        print("✅ DailyChallengeService: User profile completed, generating challenge")
                        // Reset load flags to allow generating a new challenge
                        self.hasLoadedChallenge = false
                        self.lastLoadedDate = nil
                        // Load today's challenge with the new profile data
                        self.loadTodayChallenge()
                    }
                }
            }
    }
    
    /// Set user profile service and setup observer (can be called after initialization)
    /// - Parameter profileService: User profile service to inject
    func setUserProfileService(_ profileService: UserProfileService) {
        // Remove existing profile observer if any
        profileObserverCancellable?.cancel()
        profileObserverCancellable = nil
        
        // Set new profile service
        self.userProfileService = profileService
        
        // Update current data availability
        self.hasMinimumUserData = profileService.currentProfile?.hasMinimumDataForDailyChallenge() ?? false
        
        // Setup observer for future changes
        setupProfileObserver()
    }
    
    /// Shared singleton instance (for backward compatibility)
    /// Note: This creates a new instance with default database service, not a true singleton
    static var shared: DailyChallengeService {
        return DailyChallengeService()
    }
    
    /// Load today's challenge from Firebase or generate default
    func loadTodayChallenge() {
        guard let userId = Auth.auth().currentUser?.uid else {
            // Don't load challenge if user is not logged in
            print("ℹ️ DailyChallengeService: No user logged in, skipping challenge load")
            return
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        // ✅ Check if we've already loaded today's challenge (avoid redundant loads)
        if hasLoadedChallenge, let lastLoaded = lastLoadedDate,
           Calendar.current.isDate(lastLoaded, inSameDayAs: today) {
            print("✅ DailyChallengeService: Already loaded today's challenge, skipping")
            return
        }
        
        print("🔄 DailyChallengeService: Fetching challenge from Firebase for \(today)")
        
        databaseService.fetchDailyChallenge(userId: userId, date: today) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let data):
                if let data = data {
                    // Challenge exists in Firebase, parse it
                    if let challenge = self.parseChallengeFromFirebase(data, date: today) {
                        DispatchQueue.main.async {
                            self.currentChallenge = challenge
                            self.isChallengeCompleted = data["isCompleted"] as? Bool ?? false
                            self.isChallengeAddedToTasks = data["taskId"] != nil
                            self.isLocked = data["isLocked"] as? Bool ?? false
                            
                            // ✅ If loading an already completed challenge, mark toast as shown
                            // (don't show toast again on page reload)
                            self.hasShownCompletionToast = self.isChallengeCompleted
                            
                            // Load completedAt timestamp
                            if let completedAtTimestamp = data["completedAt"] as? Double {
                                self.completedAt = Date(timeIntervalSince1970: completedAtTimestamp)
                            } else {
                                self.completedAt = nil
                            }
                            
                            if let taskIdString = data["taskId"] as? String {
                                self.challengeTaskId = UUID(uuidString: taskIdString)
                            }
                            
                            // Set up real-time listener for completion status
                            self.observeChallengeCompletion()
                            
                            // ✅ Mark as loaded to prevent redundant loads
                            self.hasLoadedChallenge = true
                            self.lastLoadedDate = today
                            
                            print("✅ DailyChallengeService: Loaded challenge from Firebase - \(challenge.title)")
                        }
                    } else {
                        print("⚠️ DailyChallengeService: Failed to parse challenge, using default")
                        DispatchQueue.main.async {
                            self.generateDefaultChallenge()
                            // ✅ Save default challenge to Firebase to persist across page switches
                            if let challenge = self.currentChallenge {
                                self.saveChallengeToFirebase(challenge)
                            }
                        }
                    }
                } else {
                    // No challenge for today in Firebase, generate new one
                    print("ℹ️ DailyChallengeService: No challenge in Firebase for today, generating new challenge")
                    DispatchQueue.main.async {
                        // ✅ Use AI if user has enough data, otherwise use default
                        self.generateFirstChallenge()
                    }
                }
            case .failure(let error):
                print("❌ DailyChallengeService: Failed to load challenge from Firebase - \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.generateDefaultChallenge()
                    // ✅ Save default challenge to Firebase to persist across page switches
                    if let challenge = self.currentChallenge {
                        self.saveChallengeToFirebase(challenge)
                    }
                }
            }
        }
    }
    
    /// Parse challenge from Firebase data
    private func parseChallengeFromFirebase(_ data: [String: Any], date: Date) -> DailyChallenge? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let title = data["title"] as? String,
              let subtitle = data["subtitle"] as? String,
              let emoji = data["emoji"] as? String,
              let typeString = data["type"] as? String,
              let type = DailyChallenge.ChallengeType(rawValue: typeString),
              let targetValue = data["targetValue"] as? Int else {
            return nil
        }
        
        return DailyChallenge(
            id: id,
            title: title,
            subtitle: subtitle,
            emoji: emoji,
            type: type,
            targetValue: targetValue,
            date: date
        )
    }
    
    /// Generate default challenge (fallback)
    private func generateDefaultChallenge() {
        // Generate random step count for variety
        let randomSteps = generateRandomStepTarget()
        
        currentChallenge = DailyChallenge(
            id: UUID(),
            title: "\(randomSteps.formatted()) steps",
            subtitle: "Walk \(randomSteps.formatted()) steps today",
            emoji: "👟",
            type: .fitness,
            targetValue: randomSteps,
            date: Calendar.current.startOfDay(for: Date())
        )
        isChallengeCompleted = false
        isChallengeAddedToTasks = false
        isLocked = false
        completedAt = nil
        challengeTaskId = nil
        hasShownCompletionToast = false // ✅ Reset for new challenge
        
        // ✅ Mark as loaded to prevent redundant loads
        hasLoadedChallenge = true
        lastLoadedDate = Calendar.current.startOfDay(for: Date())
        
        print("✅ DailyChallengeService: Generated default challenge - \(currentChallenge?.title ?? "") (\(randomSteps) steps)")
    }
    
    /// Generate random step target with reasonable variety
    private func generateRandomStepTarget() -> Int {
        // Define step ranges for different difficulty levels
        let stepRanges = [
            5000...7000,   // Light activity
            7000...9000,   // Moderate activity
            9000...12000,  // Active
            12000...15000  // Very active
        ]
        
        // Randomly select a difficulty level
        let selectedRange = stepRanges.randomElement()!
        
        // Generate random steps in that range, rounded to nearest 500
        let randomSteps = Int.random(in: selectedRange)
        let roundedSteps = (randomSteps / 500) * 500
        
        return roundedSteps
    }
    
    /// Generate first challenge (AI or default based on user data availability)
    /// This is called when no challenge exists in Firebase for today
    private func generateFirstChallenge() {
        print("🎯 DailyChallengeService: Generating first challenge for today")
        
        // Check if we have enough user data for AI generation
        if hasMinimumUserData {
            print("   ✅ User has minimum data, generating AI challenge")
            // Use AI to generate challenge
            Task {
                await generateAIChallenge(userProfile: nil)
            }
        } else {
            print("   ⚠️ User doesn't have enough data, skipping challenge generation")
            print("   💡 Challenge will be generated when user completes their profile")
            // Don't generate challenge or mark as loaded
            // When user fills in their profile, setupProfileObserver will trigger loadTodayChallenge()
        }
    }
    
    /// Refresh challenge (generate a new challenge using AI or default)
    func refreshChallenge(userProfile: UserProfile?) {
        // If user has minimum data, generate AI challenge, otherwise use default
        if hasMinimumUserData {
            Task {
                await generateAIChallenge(userProfile: userProfile)
            }
        } else {
            generateDefaultChallenge()
            // Save default challenge to Firebase
            if let challenge = currentChallenge {
                saveChallengeToFirebase(challenge)
            }
        }
    }
    
    /// Generate AI-powered challenge based on user profile
    func generateAIChallenge(userProfile: UserProfile?) async {
        guard hasMinimumUserData else {
            print("⚠️ DailyChallengeService: User doesn't have minimum data for AI generation")
            return
        }
        
        // Capture current challenge before generating new one (to avoid repetition)
        let previousChallenge = await MainActor.run { currentChallenge }
        
        await MainActor.run {
            isGeneratingChallenge = true
            challengeGenerationError = nil
        }
        
        do {
            print("🤖 DailyChallengeService: Generating AI challenge...")
            if let prev = previousChallenge {
                print("   📋 Previous challenge: \(prev.title) (\(prev.type.rawValue))")
            }
            
            // Build prompt with previous challenge context
            let prompt = promptBuilder.buildDailyChallengePrompt(userProfile: userProfile, previousChallenge: previousChallenge)
            
            // Create message
            let message = ChatMessage(role: "user", content: prompt)
            
            // Call AI service
            let response = try await aiService.sendChatRequest(messages: [message], maxTokens: 300)
            
            // Parse response
            guard let choice = response.choices.first,
                  let content = choice.message.content else {
                print("❌ DailyChallengeService: No content in AI response")
                await useFallbackChallenge()
                return
            }
            
            // Parse challenge from response
            if let challenge = responseParser.parseDailyChallengeResponse(content) {
                await MainActor.run {
                    currentChallenge = challenge
                    isChallengeCompleted = false
                    isChallengeAddedToTasks = false
                    isLocked = false
                    completedAt = nil
                    challengeTaskId = nil
                    hasShownCompletionToast = false // ✅ Reset for new challenge
                    isGeneratingChallenge = false
                    
                    // ✅ Mark as loaded to prevent redundant loads
                    self.hasLoadedChallenge = true
                    self.lastLoadedDate = Calendar.current.startOfDay(for: Date())
                    
                    // Save AI-generated challenge to Firebase
                    self.saveChallengeToFirebase(challenge)
                }
                print("✅ DailyChallengeService: AI challenge generated - \(challenge.title)")
            } else {
                await useFallbackChallenge()
            }
            
        } catch {
            print("❌ DailyChallengeService: AI generation failed - \(error.localizedDescription)")
            await MainActor.run {
                challengeGenerationError = error.localizedDescription
            }
            await useFallbackChallenge()
        }
    }
    
    /// Use fallback challenge when AI fails
    private func useFallbackChallenge() async {
        await MainActor.run {
            currentChallenge = responseParser.getDefaultChallenge()
            isChallengeCompleted = false
            isChallengeAddedToTasks = false
            isLocked = false
            completedAt = nil
            challengeTaskId = nil
            hasShownCompletionToast = false // ✅ Reset for new challenge
            isGeneratingChallenge = false
            
            // ✅ Mark as loaded to prevent redundant loads
            self.hasLoadedChallenge = true
            self.lastLoadedDate = Calendar.current.startOfDay(for: Date())
            
            // Save fallback challenge to Firebase
            if let challenge = currentChallenge {
                self.saveChallengeToFirebase(challenge)
            }
        }
        print("⚠️ DailyChallengeService: Using fallback challenge")
    }
    
    /// Add challenge to task list
    func addChallengeToTasks(completion: @escaping (UUID?) -> Void) {
        guard let challenge = currentChallenge else {
            print("⚠️ DailyChallengeService: No challenge to add")
            completion(nil)
            return
        }
        
        // Generate task ID
        let taskId = UUID()
        challengeTaskId = taskId
        isChallengeAddedToTasks = true
        
        print("✅ DailyChallengeService: Challenge marked as added to tasks - ID: \(taskId)")
        
        // Save to Firebase (optional)
        saveChallengeToDB(challenge, taskId: taskId)
        
        completion(taskId)
    }
    
    /// Update challenge completion status (synced from task list)
    func updateChallengeCompletion(taskId: UUID, isCompleted: Bool) {
        // Only update if the task ID matches the current challenge's task ID
        if taskId == challengeTaskId {
            DispatchQueue.main.async {
                self.isChallengeCompleted = isCompleted
                
                // When completing the challenge, lock it and record completion time
                if isCompleted && !self.isLocked {
                    self.isLocked = true
                    self.completedAt = Date()
                    print("🔒 DailyChallengeService: Challenge locked after completion")
                }
                
                print("✅ DailyChallengeService: Challenge completion updated - \(isCompleted)")
                
                // Sync completion status to Firebase
                self.updateCompletionInDB(isCompleted: isCompleted)
            }
        }
    }
    
    /// Update completion status in Firebase
    private func updateCompletionInDB(isCompleted: Bool) {
        guard let userId = Auth.auth().currentUser?.uid,
              let challenge = currentChallenge else {
            return
        }
        
        databaseService.updateDailyChallengeCompletion(
            userId: userId,
            date: challenge.date,
            isCompleted: isCompleted,
            isLocked: isLocked,
            completedAt: completedAt
        ) { result in
            switch result {
            case .success:
                print("✅ DailyChallengeService: Completion status synced to Firebase")
            case .failure(let error):
                print("❌ DailyChallengeService: Failed to update completion - \(error.localizedDescription)")
            }
        }
    }
    
    /// Check if a task is the current challenge
    func isTaskCurrentChallenge(taskId: UUID) -> Bool {
        return taskId == challengeTaskId
    }
    
    /// Handle deletion of the task associated with today's challenge
    /// - If the deleted task matches the current challenge task, clear the linkage so user can re-add (when not completed)
    /// - Preserve locked/completed state so completed challenges cannot be exploited/reset
    func handleChallengeTaskDeleted(taskId: UUID) {
        guard taskId == challengeTaskId else { return }
        DispatchQueue.main.async {
            // Clear local linkage to allow re-adding if not completed
            self.isChallengeAddedToTasks = false
            self.challengeTaskId = nil
            
            // Remove taskId in Firebase for today's challenge
            guard let userId = Auth.auth().currentUser?.uid,
                  let challenge = self.currentChallenge else { return }
            
            self.databaseService.updateDailyChallengeTaskId(
                userId: userId,
                date: challenge.date,
                taskId: nil
            ) { result in
                switch result {
                case .success:
                    print("✅ DailyChallengeService: Cleared taskId after task deletion")
                case .failure(let error):
                    print("❌ DailyChallengeService: Failed to remove taskId - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Reset all state (call when user logs out)
    func resetState() {
        print("🔄 DailyChallengeService: Resetting all state for user logout")
        
        // Remove Firebase observer
        removeCompletionObserver()
        
        // Clear all state
        currentChallenge = nil
        isChallengeCompleted = false
        isChallengeAddedToTasks = false
        completedAt = nil
        isLocked = false
        hasShownCompletionToast = false
        hasMinimumUserData = false
        isGeneratingChallenge = false
        challengeGenerationError = nil
        challengeTaskId = nil
        
        print("✅ DailyChallengeService: State reset complete")
    }
    
    /// Check if it's a new day and reset challenge if needed
    func checkAndResetForNewDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // If no challenge exists, check if we should load one
        guard let challenge = currentChallenge else {
            // If user doesn't have minimum data, don't even try to load
            // (setupProfileObserver will trigger loading when they complete their profile)
            guard hasMinimumUserData else {
                print("ℹ️ DailyChallengeService: No challenge and no user data, waiting for profile completion")
                return
            }
            
            // Only load if we haven't already tried today
            if let lastLoaded = lastLoadedDate, calendar.isDate(lastLoaded, inSameDayAs: today) {
                print("ℹ️ DailyChallengeService: Already attempted to load challenge today")
                return
            }
            print("ℹ️ DailyChallengeService: No challenge exists, loading today's challenge")
            loadTodayChallenge()
            return
        }
        
        let challengeDate = calendar.startOfDay(for: challenge.date)
        
        // If it's a new day, reset and load new challenge
        if challengeDate < today {
            print("📅 DailyChallengeService: New day detected, resetting challenge")
            // Remove old observer
            removeCompletionObserver()
            // ✅ Reset load flags so new challenge will be loaded
            hasLoadedChallenge = false
            lastLoadedDate = nil
            // Load or generate new challenge for today
            loadTodayChallenge()
        } else {
            print("ℹ️ DailyChallengeService: Challenge is already for today, no action needed")
        }
    }
    
    /// Observe challenge completion status in real-time (for multi-device sync)
    private func observeChallengeCompletion() {
        guard let userId = Auth.auth().currentUser?.uid,
              let challenge = currentChallenge else {
            return
        }
        
        // Remove existing observer if any
        if let handle = completionObserverHandle {
            databaseService.stopListening(handle: handle)
        }
        
        // Observe changes in completion status
        completionObserverHandle = databaseService.listenToDailyChallenge(
            userId: userId,
            date: challenge.date
        ) { [weak self] data in
            guard let self = self else { return }
            
            guard let data = data else {
                return
            }
            
            DispatchQueue.main.async {
                // Update completion status from other devices
                if let isCompleted = data["isCompleted"] as? Bool {
                    self.isChallengeCompleted = isCompleted
                }
                
                // Update lock status
                if let isLocked = data["isLocked"] as? Bool {
                    self.isLocked = isLocked
                }
                
                // Update completion time
                if let completedAtTimestamp = data["completedAt"] as? Double {
                    self.completedAt = Date(timeIntervalSince1970: completedAtTimestamp)
                } else {
                    self.completedAt = nil
                }
                
                print("🔄 DailyChallengeService: Synced completion status from Firebase")
            }
        }
    }
    
    /// Remove completion observer
    func removeCompletionObserver() {
        guard let handle = completionObserverHandle else {
            return
        }
        
        databaseService.stopListening(handle: handle)
        completionObserverHandle = nil
        
        print("🔇 DailyChallengeService: Removed completion observer")
    }
    
    // MARK: - Firebase Sync
    
    /// Save challenge to Firebase (without taskId)
    private func saveChallengeToFirebase(_ challenge: DailyChallenge) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ DailyChallengeService: No user logged in")
            return
        }
        
        databaseService.saveDailyChallenge(
            userId: userId,
            challenge: challenge,
            date: challenge.date,
            isCompleted: isChallengeCompleted,
            isLocked: isLocked,
            completedAt: completedAt,
            taskId: nil
        ) { result in
            switch result {
            case .success:
                print("✅ DailyChallengeService: Challenge saved to Firebase")
            case .failure(let error):
                print("❌ DailyChallengeService: Failed to save challenge - \(error.localizedDescription)")
            }
        }
    }
    
    /// Save challenge with taskId to Firebase (when adding to tasks)
    private func saveChallengeToDB(_ challenge: DailyChallenge, taskId: UUID) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ DailyChallengeService: No user logged in")
            return
        }
        
        databaseService.saveDailyChallenge(
            userId: userId,
            challenge: challenge,
            date: challenge.date,
            isCompleted: isChallengeCompleted,
            isLocked: isLocked,
            completedAt: completedAt,
            taskId: taskId
        ) { result in
            switch result {
            case .success:
                print("✅ DailyChallengeService: Challenge saved to Firebase")
            case .failure(let error):
                print("❌ DailyChallengeService: Failed to save challenge - \(error.localizedDescription)")
            }
        }
    }
}

