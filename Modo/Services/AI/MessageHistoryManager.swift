import Foundation
import SwiftData
import FirebaseAuth

/// Message History Manager
///
/// Manages chat message persistence and retrieval using SwiftData.
/// Handles loading, saving, clearing, and format conversion of messages.
class MessageHistoryManager {
    
    // MARK: - State
    
    private var modelContext: ModelContext?
    private var hasLoadedHistory = false
    private var lastLoadedUserId: String?
    
    // MARK: - Dependencies
    
    private let promptBuilder: AIPromptBuilder
    
    init(promptBuilder: AIPromptBuilder = AIPromptBuilder()) {
        self.promptBuilder = promptBuilder
    }
    
    // MARK: - Load History
    
    /// Load chat history from SwiftData
    /// - Parameters:
    ///   - context: SwiftData model context
    ///   - userProfile: User profile for personalization
    /// - Returns: Tuple of (messages, shouldSendUserInfo)
    func loadHistory(
        from context: ModelContext,
        userProfile: UserProfile?
    ) -> (messages: [FirebaseChatMessage], shouldSendInitialUserInfo: Bool) {
        // Get current user ID
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("⚠️ MessageHistoryManager: No current user, cannot load chat history")
            return ([], false)
        }
        
        // Check if this is a different user - if so, reset the flag
        if lastLoadedUserId != currentUserId {
            hasLoadedHistory = false
        }
        
        // Only load once per user
        guard !hasLoadedHistory else {
            print("ℹ️ MessageHistoryManager: History already loaded for user \(currentUserId)")
            return ([], false)
        }
        
        // Store context and user ID
        self.modelContext = context
        self.lastLoadedUserId = currentUserId
        
        // Filter messages by current user ID
        let predicate = #Predicate<FirebaseChatMessage> { message in
            message.userId == currentUserId
        }
        let descriptor = FetchDescriptor<FirebaseChatMessage>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        do {
            let savedMessages = try context.fetch(descriptor)
            hasLoadedHistory = true
            
            if savedMessages.isEmpty {
                // First time - check if we should send user info
                let shouldSendInfo = shouldSendUserInfo(userProfile: userProfile)
                print("✅ MessageHistoryManager: Loaded 0 messages for new user \(currentUserId)")
                return ([], shouldSendInfo)
            } else {
                // Load existing messages
                print("✅ MessageHistoryManager: Loaded \(savedMessages.count) messages for user \(currentUserId)")
                return (savedMessages, false)
            }
            
        } catch {
            print("❌ MessageHistoryManager: Failed to load chat history - \(error)")
            hasLoadedHistory = true
            return ([], false)
        }
    }
    
    /// Reset history loading state (useful when user changes)
    func resetForNewUser() {
        hasLoadedHistory = false
        lastLoadedUserId = nil
        modelContext = nil
    }
    
    // MARK: - Save Message
    
    /// Save a message to SwiftData
    /// - Parameters:
    ///   - message: Message to save
    ///   - context: Optional context (if not provided, uses stored context)
    func saveMessage(_ message: FirebaseChatMessage, context: ModelContext? = nil) {
        let contextToUse = context ?? modelContext
        guard let contextToUse = contextToUse else {
            print("⚠️ MessageHistoryManager: No context available to save message")
            return
        }
        
        contextToUse.insert(message)
        
        do {
            try contextToUse.save()
        } catch {
            print("❌ MessageHistoryManager: Failed to save message - \(error)")
        }
    }
    
    // MARK: - Clear History
    
    /// Clear all chat history for current user
    /// - Parameter context: SwiftData model context
    /// - Returns: Success or failure with error
    func clearHistory(context: ModelContext) -> Result<Void, Error> {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("⚠️ MessageHistoryManager: No current user, cannot clear chat history")
            return .failure(MessageHistoryError.noCurrentUser)
        }
        
        do {
            // Only delete messages belonging to current user
            let predicate = #Predicate<FirebaseChatMessage> { message in
                message.userId == currentUserId
            }
            let descriptor = FetchDescriptor<FirebaseChatMessage>(predicate: predicate)
            
            let userMessages = try context.fetch(descriptor)
            
            for message in userMessages {
                context.delete(message)
            }
            
            try context.save()
            
            // Reset loading state
            hasLoadedHistory = false
            
            print("✅ MessageHistoryManager: Chat history cleared successfully")
            return .success(())
            
        } catch {
            print("❌ MessageHistoryManager: Failed to clear chat history - \(error)")
            print("🔄 This is likely due to schema migration issues")
            print("💡 Recommendation: Delete and reinstall the app to clear old database")
            
            // Post notification for UI to handle
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("DatabaseMigrationError"),
                    object: nil,
                    userInfo: ["error": error.localizedDescription]
                )
            }
            
            return .failure(error)
        }
    }
    
    // MARK: - Convert Messages
    
    /// Convert FirebaseChatMessage array to ChatMessage array for AI
    /// - Parameters:
    ///   - messages: Array of FirebaseChatMessage
    ///   - includeSystemPrompt: Whether to include system prompt
    ///   - userProfile: User profile for system prompt personalization
    /// - Returns: Array of ChatMessage
    func convertToChatMessages(
        messages: [FirebaseChatMessage],
        includeSystemPrompt: Bool = false,
        userProfile: UserProfile? = nil
    ) -> [ChatMessage] {
        var chatMessages: [ChatMessage] = []
        
        // Add system prompt if requested
        if includeSystemPrompt {
            let systemPrompt = promptBuilder.buildSystemPrompt(userProfile: userProfile)
            chatMessages.append(ChatMessage(role: "system", content: systemPrompt))
        }
        
        // Convert history messages
        let historyMessages = messages.map { message in
            ChatMessage(
                role: message.isFromUser ? "user" : "assistant",
                content: message.content
            )
        }
        
        chatMessages.append(contentsOf: historyMessages)
        return chatMessages
    }
    
    // MARK: - Create Welcome Message
    
    /// Create a welcome message for new users
    /// - Returns: Welcome message
    func createWelcomeMessage() -> FirebaseChatMessage {
        return FirebaseChatMessage(
            content: "Hi! I'm your MODO wellness assistant. I can help you with diet planning, fitness routines, and healthy lifestyle tips.\nWhat would you like to know?",
            isFromUser: false
        )
    }
    
    // MARK: - Create Initial User Info Message
    
    /// Create initial user info message for first-time users
    /// - Parameter userProfile: User profile
    /// - Returns: User info message text
    func createInitialUserInfoMessage(userProfile: UserProfile?) -> String? {
        guard let profile = userProfile,
              shouldSendUserInfo(userProfile: profile) else {
            return nil
        }
        
        var userInfoText = "Hi! I just signed up. Here's my confirmed profile information:\n\n"
        
        if let age = profile.age {
            userInfoText += "Age: \(age) years old\n"
        }
        
        if let gender = profile.gender {
            // Convert gender code to readable format
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
            userInfoText += "Gender: \(genderText)\n"
        }
        
        // Keep user's original units - don't convert
        if let weightValue = profile.weightValue, let weightUnit = profile.weightUnit {
            userInfoText += "Weight: \(weightValue) \(weightUnit)\n"
        }
        
        if let heightValue = profile.heightValue, let heightUnit = profile.heightUnit {
            userInfoText += "Height: \(heightValue) \(heightUnit)\n"
        }
        
        if let goal = profile.goal {
            userInfoText += "Goal: \(goal)\n"
        }
        
        if let lifestyle = profile.lifestyle {
            userInfoText += "Lifestyle: \(lifestyle)\n"
        }
        
        userInfoText += "\nI have basic gym equipment available (dumbbells, barbells, and machines). Please create personalized workout and nutrition plans based on this information. No need to ask me for these details again!"
        
        return userInfoText
    }
    
    // MARK: - Private Helpers
    
    /// Check if should send user info to AI
    /// - Parameter userProfile: User profile
    /// - Returns: True if should send info
    private func shouldSendUserInfo(userProfile: UserProfile?) -> Bool {
        // Check if user has completed profile setup
        guard let profile = userProfile else { return false }
        
        // Check if user has basic info
        let hasBasicInfo = profile.age != nil &&
                          profile.weightValue != nil &&
                          profile.heightValue != nil &&
                          profile.goal != nil
        
        return hasBasicInfo
    }
}

// MARK: - Supporting Types

/// Errors specific to message history management
enum MessageHistoryError: Error, LocalizedError {
    case noCurrentUser
    case noContext
    case fetchFailed(Error)
    case saveFailed(Error)
    case deleteFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noCurrentUser:
            return "No current user authenticated"
        case .noContext:
            return "No SwiftData context available"
        case .fetchFailed(let error):
            return "Failed to fetch messages: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save message: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete messages: \(error.localizedDescription)"
        }
    }
}

