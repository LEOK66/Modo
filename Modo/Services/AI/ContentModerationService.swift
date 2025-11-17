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
            "暴力", "色情", "毒品", "赌博",
            "violence", "porn", "drug", "gambling",
            "政治", "反动", "邪教",
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
        很抱歉，您的消息包含不适当的内容。
        
        作为健康助手，我致力于：
        • 提供健康的饮食和健身建议
        • 帮助您养成良好的生活习惯
        • 创造积极正面的对话环境
        
        请尝试使用与健康、健身或营养相关的话题。
        """
    }
}

