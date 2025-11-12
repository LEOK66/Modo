import Foundation
import SwiftUI
import Combine
import FirebaseAuth

/// ViewModel for managing daily challenge state and business logic
///
/// This ViewModel handles:
/// - Loading today's challenge
/// - Challenge completion status
/// - Adding challenge to tasks
/// - Showing challenge details
final class DailyChallengeViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Current daily challenge
    @Published private(set) var challenge: DailyChallenge?
    
    /// Whether the challenge is completed
    @Published private(set) var isCompleted: Bool = false
    
    /// Whether the challenge has been added to tasks
    @Published private(set) var isAddedToTasks: Bool = false
    
    /// Whether the challenge is locked (after completion)
    @Published private(set) var isLocked: Bool = false
    
    /// When the challenge was completed
    @Published private(set) var completedAt: Date? = nil
    
    /// Whether a challenge is currently being generated
    @Published private(set) var isGenerating: Bool = false
    
    /// Challenge generation error message
    @Published private(set) var challengeGenerationError: String? = nil
    
    /// Whether the user has minimum data for challenge generation
    @Published private(set) var hasMinimumUserData: Bool = false
    
    /// Whether challenge detail view should be shown
    @Published var isShowingDetail: Bool = false
    
    /// Loading state
    @Published private(set) var isLoading: Bool = false
    
    // MARK: - Private Properties
    
    /// Challenge service for business operations
    private let challengeService: ChallengeServiceProtocol
    
    /// Task repository for associating challenge with tasks
    private let taskRepository: TaskRepository?
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Current user ID
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Initialization
    
    /// Initialize DailyChallengeViewModel
    /// - Parameters:
    ///   - challengeService: Challenge service for business operations
    ///   - taskRepository: Task repository (optional, for associating challenge with tasks)
    init(
        challengeService: ChallengeServiceProtocol,
        taskRepository: TaskRepository? = nil
    ) {
        self.challengeService = challengeService
        self.taskRepository = taskRepository
        
        // Observe challenge service properties
        setupObservers()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Setup view when it appears
    func onAppear() {
        loadTodayChallenge()
    }
    
    /// Cleanup when view disappears
    func onDisappear() {
        // Cleanup if needed
    }
    
    /// Load today's challenge
    func loadTodayChallenge() {
        guard userId != nil else {
            print("⚠️ DailyChallengeViewModel: No user logged in")
            return
        }
        
        isLoading = true
        challengeService.loadTodayChallenge()
        
        // Loading will complete when challenge service updates its properties
        // We observe those changes in setupObservers()
    }
    
    /// Update challenge completion status
    /// - Parameter completed: Whether the challenge is completed
    func updateCompletion(_ completed: Bool) {
        guard let taskId = getChallengeTaskId() else {
            print("⚠️ DailyChallengeViewModel: No task ID associated with challenge")
            return
        }
        
        challengeService.updateChallengeCompletion(taskId: taskId, isCompleted: completed)
    }
    
    /// Add challenge to tasks
    /// - Parameter completion: Completion handler called when challenge is added
    func addToTasks(completion: @escaping (UUID?) -> Void) {
        challengeService.addChallengeToTasks { [weak self] taskId in
            guard let self = self else {
                completion(nil)
                return
            }
            
            if let taskId = taskId {
                print("✅ DailyChallengeViewModel: Challenge added to tasks - TaskId: \(taskId)")
            } else {
                print("⚠️ DailyChallengeViewModel: Failed to add challenge to tasks")
            }
            
            completion(taskId)
        }
    }
    
    /// Show challenge detail
    func showDetail() {
        isShowingDetail = true
    }
    
    /// Hide challenge detail
    func hideDetail() {
        isShowingDetail = false
    }
    
    /// Refresh challenge
    /// - Parameter userProfile: User profile for challenge generation
    func refreshChallenge(userProfile: UserProfile?) {
        challengeService.refreshChallenge(userProfile: userProfile)
    }
    
    /// Update user data availability
    /// - Parameter profile: User profile to check
    func updateUserDataAvailability(profile: UserProfile?) {
        challengeService.updateUserDataAvailability(profile: profile)
    }
    
    // MARK: - Private Methods
    
    /// Setup observers for challenge service properties
    private func setupObservers() {
        // Observe challenge service if it's ObservableObject
        if let observableService = challengeService as? DailyChallengeService {
            // Observe current challenge
            observableService.$currentChallenge
                .receive(on: DispatchQueue.main)
                .assign(to: \.challenge, on: self)
                .store(in: &cancellables)
            
            // Observe completion status
            observableService.$isChallengeCompleted
                .receive(on: DispatchQueue.main)
                .assign(to: \.isCompleted, on: self)
                .store(in: &cancellables)
            
            // Observe added to tasks status
            observableService.$isChallengeAddedToTasks
                .receive(on: DispatchQueue.main)
                .assign(to: \.isAddedToTasks, on: self)
                .store(in: &cancellables)
            
            // Observe locked status
            observableService.$isLocked
                .receive(on: DispatchQueue.main)
                .assign(to: \.isLocked, on: self)
                .store(in: &cancellables)
            
            // Observe completed at
            observableService.$completedAt
                .receive(on: DispatchQueue.main)
                .assign(to: \.completedAt, on: self)
                .store(in: &cancellables)
            
            // Observe generating status
            observableService.$isGeneratingChallenge
                .receive(on: DispatchQueue.main)
                .assign(to: \.isGenerating, on: self)
                .store(in: &cancellables)
            
            // Observe generation error
            observableService.$challengeGenerationError
                .receive(on: DispatchQueue.main)
                .assign(to: \.challengeGenerationError, on: self)
                .store(in: &cancellables)
            
            // Observe user data availability
            observableService.$hasMinimumUserData
                .receive(on: DispatchQueue.main)
                .assign(to: \.hasMinimumUserData, on: self)
                .store(in: &cancellables)
            
            // Observe loading state (derive from generating state)
            observableService.$isGeneratingChallenge
                .map { $0 }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isGenerating in
                    self?.isLoading = isGenerating
                }
                .store(in: &cancellables)
        }
    }
    
    /// Get challenge task ID (if challenge is added to tasks)
    private func getChallengeTaskId() -> UUID? {
        // Challenge service should provide a way to get the task ID
        // For now, we'll need to check if challenge is added to tasks
        // and get the task ID from the challenge service
        guard isAddedToTasks else {
            return nil
        }
        
        // TODO: Challenge service should expose task ID
        // For now, return nil and let the service handle it internally
        return nil
    }
}

