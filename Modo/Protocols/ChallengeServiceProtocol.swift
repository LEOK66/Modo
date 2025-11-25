import Foundation
import Combine

/// Protocol defining the daily challenge service interface
/// This protocol allows for dependency injection and testing
protocol ChallengeServiceProtocol: ObservableObject {
    // MARK: - Published Properties
    
    /// Current daily challenge
    var currentChallenge: DailyChallenge? { get }
    
    /// Whether the challenge is completed
    var isChallengeCompleted: Bool { get }
    
    /// Whether the challenge has been added to tasks
    var isChallengeAddedToTasks: Bool { get }
    
    /// When the challenge was completed
    var completedAt: Date? { get }
    
    /// Whether the challenge is locked (after completion)
    var isLocked: Bool { get }
    
    /// Whether the user has minimum data for challenge generation
    var hasMinimumUserData: Bool { get }
    
    /// Whether completion toast has been shown for current challenge
    var hasShownCompletionToast: Bool { get }
    
    /// Whether a challenge is currently being generated
    var isGeneratingChallenge: Bool { get }
    
    /// Challenge generation error message
    var challengeGenerationError: String? { get }
    
    // MARK: - Methods
    
    /// Load today's challenge from Firebase or generate default
    func loadTodayChallenge()
    
    /// Refresh the current challenge (regenerate if needed)
    /// - Parameter userProfile: User profile for challenge generation
    func refreshChallenge(userProfile: UserProfile?)
    
    /// Generate AI challenge asynchronously
    /// - Parameter userProfile: User profile for challenge generation
    func generateAIChallenge(userProfile: UserProfile?) async
    
    /// Add challenge to tasks
    /// - Parameter completion: Completion handler with task ID
    func addChallengeToTasks(completion: @escaping (UUID?) -> Void)
    
    /// Update challenge completion status
    /// - Parameters:
    ///   - taskId: Task ID associated with challenge
    ///   - isCompleted: Whether the challenge is completed
    func updateChallengeCompletion(taskId: UUID, isCompleted: Bool)
    
    /// Check if a task is the current challenge
    /// - Parameter taskId: Task ID to check
    /// - Returns: Whether the task is the current challenge
    func isTaskCurrentChallenge(taskId: UUID) -> Bool
    
    /// Handle challenge task deletion
    /// - Parameter taskId: Task ID that was deleted
    func handleChallengeTaskDeleted(taskId: UUID)
    
    /// Reset challenge state (e.g., on logout)
    func resetState()
    
    /// Check and reset challenge for new day
    func checkAndResetForNewDay()
    
    /// Remove completion observer
    func removeCompletionObserver()
}

