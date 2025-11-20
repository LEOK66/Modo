import Foundation

/// Content Moderation Service
///
/// Handles inappropriate content detection and filtering
class ContentModerationService {
    
    // MARK: - Inappropriate Content Detection
    
    /// Check if text contains inappropriate content
    /// - Parameter text: Text to check
    /// - Returns: True if content is inappropriate
    func isInappropriate(_ text: String) -> Bool {
        let lowerText = text.lowercased()
        
        // List of inappropriate keywords (Chinese and English)
        let inappropriateKeywords = [
            "violence", "porn", "gambling",
            "political", "cult"
        ]
        
        return inappropriateKeywords.contains { keyword in
            lowerText.contains(keyword)
        }
    }
    
    /// Generate refusal message for inappropriate content
    /// - Returns: Friendly refusal message
    func generateRefusalMessage() -> String {
        return """
        very sorry, your message contains inappropriate content.
        as a health assistant, i am dedicated to:
        • providing healthy diet and fitness advice
        • helping you build good habits
        • creating a positive and encouraging conversation environment
        
        please try to use topics related to health, fitness, or nutrition.
        """
    }
}

