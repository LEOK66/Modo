import Foundation
import Combine
import FirebaseAuth
import FirebaseDatabase

/// Daily Challenge Service - Manages daily challenge state and synchronization
final class DailyChallengeService: ObservableObject {
    static let shared = DailyChallengeService()
    
    // Current challenge
    @Published var currentChallenge: DailyChallenge?
    @Published var isChallengeCompleted: Bool = false
    @Published var isChallengeAddedToTasks: Bool = false
    @Published var completedAt: Date? = nil // Track when challenge was completed
    @Published var isLocked: Bool = false // Lock challenge after completion
    
    // User data availability check
    @Published var hasMinimumUserData: Bool = false
    
    // AI generation state
    @Published var isGeneratingChallenge: Bool = false
    @Published var challengeGenerationError: String? = nil
    
    // Task ID associated with the current challenge
    private var challengeTaskId: UUID?
    
    // Firebase listener handle
    private var completionObserverHandle: DatabaseHandle?
    
    // Firebase reference - lazy to avoid early initialization
    private lazy var databaseRef = Database.database().reference()
    
    // AI Services
    private let aiService = FirebaseAIService.shared
    private let promptBuilder = AIPromptBuilder()
    private let responseParser = AIResponseParser()
    
    private init() {
        // Load today's challenge from Firebase or generate default
        loadTodayChallenge()
        // Initial check will be done when UserProfileService updates
    }
    
    /// Update user data availability status
    func updateUserDataAvailability(profile: UserProfile?) {
        hasMinimumUserData = profile?.hasMinimumDataForDailyChallenge() ?? false
        print("✅ DailyChallengeService: User data availability updated - \(hasMinimumUserData)")
    }
    
    /// Load today's challenge from Firebase or generate default
    func loadTodayChallenge() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ DailyChallengeService: No user logged in, using default challenge")
            generateDefaultChallenge()
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = Calendar.current.startOfDay(for: Date())
        let dateString = dateFormatter.string(from: today)
        
        let challengeRef = databaseRef
            .child("users")
            .child(userId)
            .child("dailyChallenges")
            .child(dateString)
        
        print("📡 DailyChallengeService: Loading today's challenge from Firebase...")
        
        challengeRef.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            if snapshot.exists(), let data = snapshot.value as? [String: Any] {
                // Challenge exists in Firebase, parse it
                if let challenge = self.parseChallengeFromFirebase(data, date: today) {
                    DispatchQueue.main.async {
                        self.currentChallenge = challenge
                        self.isChallengeCompleted = data["isCompleted"] as? Bool ?? false
                        self.isChallengeAddedToTasks = data["taskId"] != nil
                        self.isLocked = data["isLocked"] as? Bool ?? false
                        
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
                        
                        print("✅ DailyChallengeService: Loaded challenge from Firebase - \(challenge.title)")
                    }
                } else {
                    print("⚠️ DailyChallengeService: Failed to parse challenge, using default")
                    self.generateDefaultChallenge()
                }
            } else {
                // No challenge for today in Firebase, use default
                print("ℹ️ DailyChallengeService: No challenge in Firebase for today, using default")
                self.generateDefaultChallenge()
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
        currentChallenge = DailyChallenge(
            id: UUID(),
            title: "10,000 steps",
            subtitle: "Walk 10,000 steps today",
            emoji: "👟",
            type: .fitness,
            targetValue: 10000,
            date: Calendar.current.startOfDay(for: Date())
        )
        isChallengeCompleted = false
        isChallengeAddedToTasks = false
        isLocked = false
        completedAt = nil
        challengeTaskId = nil
        
        print("✅ DailyChallengeService: Generated default challenge - \(currentChallenge?.title ?? "")")
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
        
        await MainActor.run {
            isGeneratingChallenge = true
            challengeGenerationError = nil
        }
        
        do {
            print("🤖 DailyChallengeService: Generating AI challenge...")
            
            // Build prompt
            let prompt = promptBuilder.buildDailyChallengePrompt(userProfile: userProfile)
            
            // Create message
            let message = FirebaseFirebaseChatMessage(role: "user", content: prompt)
            
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
                    isGeneratingChallenge = false
                    
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
            isGeneratingChallenge = false
            
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
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: challenge.date)
        
        let challengeRef = databaseRef
            .child("users")
            .child(userId)
            .child("dailyChallenges")
            .child(dateString)
        
        // Update completion status, lock status, and completion time
        var updates: [String: Any] = ["isCompleted": isCompleted]
        
        if isCompleted {
            updates["isLocked"] = self.isLocked
            if let completedAt = self.completedAt {
                updates["completedAt"] = completedAt.timeIntervalSince1970
            }
        }
        
        challengeRef.updateChildValues(updates) { error, _ in
            if let error = error {
                print("❌ DailyChallengeService: Failed to update completion - \(error.localizedDescription)")
            } else {
                print("✅ DailyChallengeService: Completion status synced to Firebase")
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
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: challenge.date)
            
            let challengeRef = self.databaseRef
                .child("users")
                .child(userId)
                .child("dailyChallenges")
                .child(dateString)
            
            // Remove only the taskId field
            challengeRef.updateChildValues(["taskId": NSNull()]) { error, _ in
                if let error = error {
                    print("❌ DailyChallengeService: Failed to remove taskId - \(error.localizedDescription)")
                } else {
                    print("✅ DailyChallengeService: Cleared taskId after task deletion")
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
        hasMinimumUserData = false
        isGeneratingChallenge = false
        challengeGenerationError = nil
        challengeTaskId = nil
        
        print("✅ DailyChallengeService: State reset complete")
    }
    
    /// Check if it's a new day and reset challenge if needed
    func checkAndResetForNewDay() {
        guard let challenge = currentChallenge else {
            print("ℹ️ DailyChallengeService: No challenge to check for date change")
            return
        }
        
        let calendar = Calendar.current
        let challengeDate = calendar.startOfDay(for: challenge.date)
        let today = calendar.startOfDay(for: Date())
        
        if challengeDate < today {
            print("📅 DailyChallengeService: New day detected, resetting challenge")
            // Remove old observer
            removeCompletionObserver()
            // Load or generate new challenge for today
            loadTodayChallenge()
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
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: challenge.date)
            let ref = databaseRef
                .child("users")
                .child(userId)
                .child("dailyChallenges")
                .child(dateString)
            ref.removeObserver(withHandle: handle)
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: challenge.date)
        
        let ref = databaseRef
            .child("users")
            .child(userId)
            .child("dailyChallenges")
            .child(dateString)
        
        // Observe changes in completion status
        completionObserverHandle = ref.observe(.value) { [weak self] snapshot in
            guard let self = self,
                  let data = snapshot.value as? [String: Any] else {
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
        guard let userId = Auth.auth().currentUser?.uid,
              let challenge = currentChallenge,
              let handle = completionObserverHandle else {
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: challenge.date)
        
        let ref = databaseRef
            .child("users")
            .child(userId)
            .child("dailyChallenges")
            .child(dateString)
        
        ref.removeObserver(withHandle: handle)
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
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: challenge.date)
        
        let challengeRef = databaseRef
            .child("users")
            .child(userId)
            .child("dailyChallenges")
            .child(dateString)
        
        var data: [String: Any] = [
            "id": challenge.id.uuidString,
            "title": challenge.title,
            "subtitle": challenge.subtitle,
            "emoji": challenge.emoji,
            "type": challenge.type.rawValue,
            "targetValue": challenge.targetValue,
            "isCompleted": isChallengeCompleted,
            "isLocked": isLocked,
            "createdAt": Date().timeIntervalSince1970
        ]
        
        // Add completedAt if available
        if let completedAt = completedAt {
            data["completedAt"] = completedAt.timeIntervalSince1970
        }
        
        challengeRef.setValue(data) { error, _ in
            if let error = error {
                print("❌ DailyChallengeService: Failed to save challenge - \(error.localizedDescription)")
            } else {
                print("✅ DailyChallengeService: Challenge saved to Firebase")
            }
        }
    }
    
    /// Save challenge with taskId to Firebase (when adding to tasks)
    private func saveChallengeToDB(_ challenge: DailyChallenge, taskId: UUID) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ DailyChallengeService: No user logged in")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: challenge.date)
        
        let challengeRef = databaseRef
            .child("users")
            .child(userId)
            .child("dailyChallenges")
            .child(dateString)
        
        var data: [String: Any] = [
            "id": challenge.id.uuidString,
            "title": challenge.title,
            "subtitle": challenge.subtitle,
            "emoji": challenge.emoji,
            "type": challenge.type.rawValue,
            "targetValue": challenge.targetValue,
            "taskId": taskId.uuidString,
            "isCompleted": isChallengeCompleted,
            "isLocked": isLocked,
            "createdAt": Date().timeIntervalSince1970
        ]
        
        // Add completedAt if available
        if let completedAt = completedAt {
            data["completedAt"] = completedAt.timeIntervalSince1970
        }
        
        challengeRef.setValue(data) { error, _ in
            if let error = error {
                print("❌ DailyChallengeService: Failed to save challenge - \(error.localizedDescription)")
            } else {
                print("✅ DailyChallengeService: Challenge saved to Firebase")
            }
        }
    }
}

// MARK: - Daily Challenge Model

struct DailyChallenge: Identifiable, Codable {
    let id: UUID
    let title: String
    let subtitle: String
    let emoji: String
    let type: ChallengeType
    let targetValue: Int
    let date: Date
    
    enum ChallengeType: String, Codable {
        case fitness = "fitness"
        case diet = "diet"
        case mindfulness = "mindfulness"
        case other = "other"
    }
}

