import SwiftUI
import Combine

// MARK: - Achievement Unlock Manager

/// Manages a queue of achievements to be unlocked and displayed sequentially
class AchievementUnlockManager: ObservableObject {
    static let shared = AchievementUnlockManager()
    
    @Published var currentAchievement: (Achievement, UserAchievement)?
    @Published var isShowing: Bool = false
    
    private var queue: [(Achievement, UserAchievement)] = []
    private var isProcessing: Bool = false
    
    private init() {}
    
    /// Add an achievement to the unlock queue
    func queueUnlock(achievement: Achievement, userAchievement: UserAchievement) {
        queue.append((achievement, userAchievement))
        processQueue()
    }
    
    /// Process the next achievement in the queue
    private func processQueue() {
        guard !isProcessing, !queue.isEmpty else { return }
        
        isProcessing = true
        let next = queue.removeFirst()
        currentAchievement = next
        isShowing = true
    }
    
    /// Called when the current unlock view is dismissed
    func onDismiss() {
        isShowing = false
        currentAchievement = nil
        
        // Wait a bit before showing next achievement
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isProcessing = false
            self.processQueue()
        }
    }
    
    /// Clear all pending achievements
    func clearQueue() {
        queue.removeAll()
        isShowing = false
        currentAchievement = nil
        isProcessing = false
    }
}

// MARK: - Achievement Unlock Container View

/// Container view that observes the manager and displays unlock animations
/// Add this to your main view's ZStack
struct AchievementUnlockContainer: View {
    @StateObject private var manager = AchievementUnlockManager.shared
    
    var body: some View {
        Group {
            if let (achievement, userAchievement) = manager.currentAchievement,
               manager.isShowing {
                AchievementUnlockView(
                    achievement: achievement,
                    userAchievement: userAchievement,
                    isPresented: Binding(
                        get: { manager.isShowing },
                        set: { _ in manager.onDismiss() }
                    )
                )
                .transition(.opacity)
                .zIndex(1000)
            }
        }
    }
}

