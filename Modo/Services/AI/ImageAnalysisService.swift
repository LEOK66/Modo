import Foundation

/// Image Analysis Service
///
/// Handles food image analysis using Vision API
class ImageAnalysisService {
    
    private let firebaseAIService: FirebaseAIService
    
    init(firebaseAIService: FirebaseAIService = .shared) {
        self.firebaseAIService = firebaseAIService
    }
    
    // MARK: - Food Image Analysis
    
    /// Analyze food image and return nutritional information
    /// - Parameter base64Image: Base64 encoded image
    /// - Returns: Analysis result text
    /// - Throws: Error if analysis fails
    func analyzeFoodImage(_ base64Image: String) async throws -> String {
        let systemPrompt = """
        You are a creative nutrition expert with diverse culinary knowledge. Analyze the food in the image and provide:
        1. Food identification (be specific: type of cuisine, preparation style)
        2. Estimated serving size (use oz, cups, or pieces)
        3. Nutritional information: Protein (g), Fat (g), Carbs (g), Calories (kcal)
        
        Format your response EXACTLY as (plain text, no markdown):
        Food: [name and style, e.g., "Grilled Chicken Breast (Mediterranean style)"]
        Serving: [size in oz, cups, or pieces]
        Protein: [X]g
        Fat: [X]g
        Carbs: [X]g
        Calories: [X]kcal
        
        Be creative and specific about the food preparation style!
        """
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", multimodalContent: [
                [
                    "type": "text",
                    "text": "Please analyze this food image."
                ],
                [
                    "type": "image_url",
                    "image_url": [
                        "url": "data:image/jpeg;base64,\(base64Image)"
                    ]
                ]
            ])
        ]
        
        let response = try await firebaseAIService.sendChatRequest(
            messages: messages,
            functions: nil,
            functionCall: nil,
            maxTokens: 500
        )
        
        guard let content = response.choices.first?.message.content else {
            throw ImageAnalysisError.noResponse
        }
        
        return content
    }
    
    /// Parse food analysis result into structured data
    /// - Parameter analysisText: Raw analysis text from AI
    /// - Returns: Parsed food data
    func parseFoodAnalysis(_ analysisText: String) -> FoodAnalysisResult? {
        var foodName: String?
        var serving: String?
        var protein: String?
        var fat: String?
        var carbs: String?
        var calories: String?
        
        let lines = analysisText.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.starts(with: "Food:") {
                foodName = trimmed.replacingOccurrences(of: "Food:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.starts(with: "Serving:") {
                serving = trimmed.replacingOccurrences(of: "Serving:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.starts(with: "Protein:") {
                protein = trimmed.replacingOccurrences(of: "Protein:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.starts(with: "Fat:") {
                fat = trimmed.replacingOccurrences(of: "Fat:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.starts(with: "Carbs:") {
                carbs = trimmed.replacingOccurrences(of: "Carbs:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.starts(with: "Calories:") {
                calories = trimmed.replacingOccurrences(of: "Calories:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        
        guard let food = foodName,
              let servingSize = serving,
              let proteinValue = protein,
              let fatValue = fat,
              let carbsValue = carbs,
              let caloriesValue = calories else {
            return nil
        }
        
        return FoodAnalysisResult(
            foodName: food,
            serving: servingSize,
            protein: proteinValue,
            fat: fatValue,
            carbs: carbsValue,
            calories: caloriesValue
        )
    }
}

// MARK: - Supporting Types

struct FoodAnalysisResult {
    let foodName: String
    let serving: String
    let protein: String
    let fat: String
    let carbs: String
    let calories: String
}

enum ImageAnalysisError: Error, LocalizedError {
    case noResponse
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .noResponse:
            return "No response from image analysis"
        case .invalidFormat:
            return "Invalid response format"
        }
    }
}

