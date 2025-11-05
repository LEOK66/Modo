import Foundation

/// Service responsible for parsing AI responses into structured data
class AIResponseParser {
    
    // MARK: - Workout Response Parsing
    
    /// Parse workout plan from AI response
    /// - Parameter content: Raw AI response text
    /// - Returns: Array of exercises with details
    func parseWorkoutResponse(_ content: String) -> (title: String, exercises: [ParsedExercise]) {
        print("🔍 AIResponseParser: Parsing workout response...")
        
        let lines = content.components(separatedBy: .newlines)
        var title = "Workout"
        var exercises: [ParsedExercise] = []
        
        // Extract title from first line
        if let firstLine = lines.first, !firstLine.isEmpty {
            title = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ":", with: "")
            print("   Title: \(title)")
        }
        
        // Parse exercise lines
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            // Skip lines that don't look like exercises
            if trimmed.lowercased().contains("what do you think") ||
               trimmed.lowercased().contains("let me know") {
                continue
            }
            
            // Parse exercise line (format: "Name: X sets x Y reps, Z seconds rest, ~W calories")
            if let exercise = parseExerciseLine(trimmed) {
                exercises.append(exercise)
                print("   ✅ Parsed: \(exercise.name)")
            }
        }
        
        print("   Total exercises parsed: \(exercises.count)")
        return (title, exercises)
    }
    
    /// Parse a single exercise line
    private func parseExerciseLine(_ line: String) -> ParsedExercise? {
        var name = ""
        var sets = 3
        var reps = "10"
        var restSec = 60
        var calories = 0
        
        // Extract exercise name (before the colon)
        if let colonIndex = line.firstIndex(of: ":") {
            name = String(line[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Extract sets (pattern: "3 sets" or "3x")
        if let setsRegex = try? NSRegularExpression(pattern: #"(\d+)\s*(?:sets?|x|×)"#, options: .caseInsensitive) {
            if let match = setsRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line) {
                sets = Int(line[range]) ?? 3
            }
        }
        
        // Extract reps (pattern: "10 reps" or "x 10" or "10-12")
        if let repsRegex = try? NSRegularExpression(pattern: #"[x×]\s*(\d+(?:-\d+)?)\s*(?:reps?)?"#, options: .caseInsensitive) {
            if let match = repsRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line) {
                reps = String(line[range])
            }
        }
        
        // Extract rest seconds (pattern: "60 seconds" or "60s")
        if let restRegex = try? NSRegularExpression(pattern: #"(\d+)\s*(?:seconds?|secs?|s)\s*rest"#, options: .caseInsensitive) {
            if let match = restRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line) {
                restSec = Int(line[range]) ?? 60
            }
        }
        
        // Extract calories (pattern: "~30 calories" or "30 cal")
        if let caloriesRegex = try? NSRegularExpression(pattern: #"[~]?(\d+)\s*(?:calories?|cal|kcal)"#, options: .caseInsensitive) {
            if let match = caloriesRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line) {
                calories = Int(line[range]) ?? 0
            }
        }
        
        guard !name.isEmpty else { return nil }
        
        return ParsedExercise(
            name: name,
            sets: sets,
            reps: reps,
            restSec: restSec,
            calories: calories
        )
    }
    
    // MARK: - Nutrition Response Parsing
    
    /// Parse nutrition plan from AI response
    /// - Parameter content: Raw AI response text
    /// - Returns: Dictionary of meals with food items and their calories
    func parseNutritionResponse(_ content: String) -> [String: [(name: String, calories: Int)]] {
        print("🔍 AIResponseParser: Parsing nutrition response...")
        
        let lines = content.components(separatedBy: .newlines)
        var mealsDict: [String: [(name: String, calories: Int)]] = [:]
        var currentMeal: String?
        var currentFoods: [(name: String, calories: Int)] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let lowercased = trimmed.lowercased()
            
            // Check if it's a meal header
            let detectedMeal = detectMealType(from: lowercased)
            
            if let meal = detectedMeal, mealsDict[meal] == nil {
                // Save previous meal
                if let prevMeal = currentMeal, !currentFoods.isEmpty, mealsDict[prevMeal] == nil {
                    mealsDict[prevMeal] = currentFoods
                    print("   📍 Saved \(prevMeal): \(currentFoods.count) items")
                }
                
                // Start new meal
                currentMeal = meal
                currentFoods = []
                print("   📍 Found \(meal)")
            } else if currentMeal != nil {
                // It's a food item - parse name and calories
                let (foodName, calories) = parseFoodItemWithCalories(trimmed)
                
                if !foodName.isEmpty && isValidFoodItem(foodName) {
                    // Use AI-provided calories, or 0 if not provided (will use fallback)
                    currentFoods.append((name: foodName, calories: calories))
                    print("    🥘 Added: \(foodName)\(calories > 0 ? " (~\(calories) cal)" : " (calories to be looked up)")")
                }
            }
        }
        
        // Save last meal
        if let prevMeal = currentMeal, !currentFoods.isEmpty, mealsDict[prevMeal] == nil {
            mealsDict[prevMeal] = currentFoods
            print("   📍 Saved last meal: \(prevMeal)")
        }
        
        print("   Total meals parsed: \(mealsDict.count)")
        return mealsDict
    }
    
    /// Detect meal type from text
    private func detectMealType(from text: String) -> String? {
        if text.hasPrefix("breakfast") || text.contains("breakfast:") {
            return "Breakfast"
        } else if text.hasPrefix("lunch") || text.contains("lunch:") {
            return "Lunch"
        } else if text.hasPrefix("dinner") || text.contains("dinner:") {
            return "Dinner"
        } else if text.hasPrefix("snack") || text.contains("snack:") {
            return "Snack"
        }
        return nil
    }
    
    /// Parse food item with calories from text
    /// Format: "Dish Name (~XXX calories)" or "Dish Name"
    /// Returns: (foodName, calories)
    private func parseFoodItemWithCalories(_ text: String) -> (String, Int) {
        var cleaned = text
        
        // Remove markdown formatting
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.replacingOccurrences(of: "__", with: "")
        cleaned = cleaned.replacingOccurrences(of: "##", with: "")
        
        // Remove bullet points, numbers, dashes
        cleaned = cleaned.replacingOccurrences(of: "^[•\\-\\*\\d\\.\\)\\]]+\\s*", with: "", options: .regularExpression)
        
        // Extract calories if present (format: "~XXX calories" or "~XXX cal")
        var calories = 0
        if let caloriesRegex = try? NSRegularExpression(pattern: #"~?\s*(\d+)\s*(?:calories?|cal|kcal)"#, options: .caseInsensitive) {
            if let match = caloriesRegex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
               let range = Range(match.range(at: 1), in: cleaned) {
                calories = Int(cleaned[range]) ?? 0
                // Remove calories part from food name
                cleaned = caloriesRegex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
            }
        }
        
        // Clean up parentheses and extra spaces
        cleaned = cleaned.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (cleaned, calories)
    }
    
    /// Validate if text is a valid food item
    private func isValidFoodItem(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // Filter out descriptive text
        let isDescriptive = lowercased.contains("this ") ||
                           lowercased.contains("enjoy") ||
                           lowercased.contains("balance") ||
                           lowercased.contains("will ") ||
                           lowercased.contains("can ")
        
        // Filter out meta info
        let isMetaInfo = lowercased.contains("total") ||
                        lowercased.contains("calories:") ||
                        lowercased.contains("protein:") ||
                        lowercased.contains("carbs:") ||
                        lowercased.contains("fat:")
        
        // Valid food item criteria
        return !text.isEmpty &&
               text.count > 2 &&
               text.count < 100 &&
               !isDescriptive &&
               !isMetaInfo &&
               !text.hasSuffix(":") &&
               text.components(separatedBy: " ").count < 15
    }
    
    // MARK: - Daily Challenge Response Parsing
    
    /// Parse daily challenge from AI response
    /// - Parameter content: Raw AI response text
    /// - Returns: DailyChallenge object or nil if parsing fails
    func parseDailyChallengeResponse(_ content: String) -> DailyChallenge? {
        print("🔍 AIResponseParser: Parsing daily challenge response...")
        
        // Extract JSON from response
        guard let jsonString = extractJSON(from: content),
              let jsonData = jsonString.data(using: .utf8) else {
            print("❌ Failed to extract JSON from response")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(DailyChallengeResponse.self, from: jsonData)
            
            // Convert to DailyChallenge
            let challenge = DailyChallenge(
                id: UUID(),
                title: response.title,
                subtitle: response.subtitle,
                emoji: response.emoji,
                type: DailyChallenge.ChallengeType(rawValue: response.type) ?? .fitness,
                targetValue: response.targetValue,
                date: Calendar.current.startOfDay(for: Date())
            )
            
            print("✅ Successfully parsed challenge: \(challenge.title)")
            return challenge
            
        } catch {
            print("❌ Failed to decode JSON: \(error)")
            return nil
        }
    }
    
    /// Extract JSON string from text
    private func extractJSON(from text: String) -> String? {
        // Try to find JSON within curly braces
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        return nil
    }
    
    /// Get default challenge as fallback
    func getDefaultChallenge() -> DailyChallenge {
        return DailyChallenge(
            id: UUID(),
            title: "Walk 10,000 steps",
            subtitle: "Get moving with a daily walk",
            emoji: "👟",
            type: .fitness,
            targetValue: 10000,
            date: Calendar.current.startOfDay(for: Date())
        )
    }
}

// MARK: - Data Models

struct ParsedExercise {
    let name: String
    let sets: Int
    let reps: String
    let restSec: Int
    let calories: Int
}

// Daily Challenge Response Model
private struct DailyChallengeResponse: Codable {
    let title: String
    let subtitle: String
    let emoji: String
    let type: String
    let targetValue: Int
}

