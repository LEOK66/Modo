import Foundation

/// Parser for AI-generated task content in AddTaskView
/// Handles parsing AI responses and converting them to form field values
class AddTaskAIParser {
    
    /// Parsed task content structure
    struct ParsedTaskContent {
        var title: String?
        var description: String?
        var category: TaskCategory?
        var timeDate: Date?
        var exercises: [FitnessEntry] = []
        var foods: [DietEntry] = []
    }
    
    // MARK: - Main Parse Method
    
    /// Parse AI response and fill form fields
    /// - Parameter content: Raw AI response content
    /// - Returns: ParsedTaskContent with all parsed fields
    func parseTaskContent(_ content: String) -> ParsedTaskContent {
        print("🤖 Parsing AI generated content...")
        
        var parsed = ParsedTaskContent()
        let lines = content.components(separatedBy: .newlines)
        var currentSection = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Parse title
            if trimmed.hasPrefix("TITLE:") {
                let title = trimmed.replacingOccurrences(of: "TITLE:", with: "").trimmingCharacters(in: .whitespaces)
                // No prefix for AI generated titles, use as is
                parsed.title = String(title.prefix(50))
            }
            
            // Parse description
            else if trimmed.hasPrefix("DESCRIPTION:") {
                parsed.description = trimmed.replacingOccurrences(of: "DESCRIPTION:", with: "").trimmingCharacters(in: .whitespaces)
            }
            
            // Parse category
            else if trimmed.hasPrefix("CATEGORY:") {
                let category = trimmed.replacingOccurrences(of: "CATEGORY:", with: "").trimmingCharacters(in: .whitespaces).lowercased()
                if category.contains("fitness") || category.contains("workout") {
                    parsed.category = .fitness
                } else if category.contains("diet") || category.contains("nutrition") || category.contains("meal") {
                    parsed.category = .diet
                }
            }
            
            // Parse time
            else if trimmed.hasPrefix("TIME:") {
                let timeString = trimmed.replacingOccurrences(of: "TIME:", with: "").trimmingCharacters(in: .whitespaces)
                parsed.timeDate = parseTimeString(timeString)
            }
            
            // Track sections
            else if trimmed == "EXERCISES:" {
                currentSection = "exercises"
            }
            else if trimmed == "FOODS:" {
                currentSection = "foods"
            }
            
            // Parse exercise line
            else if currentSection == "exercises" && trimmed.hasPrefix("-") {
                if let exercise = parseExerciseLine(trimmed) {
                    parsed.exercises.append(exercise)
                }
            }
            
            // Parse food line
            else if currentSection == "foods" && trimmed.hasPrefix("-") {
                if let food = parseFoodLine(trimmed) {
                    parsed.foods.append(food)
                }
            }
        }
        
        print("✅ Task content parsed: title=\(parsed.title ?? "nil"), category=\(parsed.category?.rawValue ?? "nil"), exercises=\(parsed.exercises.count), foods=\(parsed.foods.count)")
        
        return parsed
    }
    
    // MARK: - Time Parsing
    
    /// Parse time string like "09:00 AM" to Date
    /// - Parameter timeString: Time string in format "hh:mm a"
    /// - Returns: Date object or nil if parsing fails
    func parseTimeString(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.date(from: timeString)
    }
    
    // MARK: - Exercise Parsing
    
    /// Parse exercise line like "- Push-ups: 3 sets x 15 reps, 60s rest, 5min, 40cal"
    /// - Parameter line: Exercise line text
    /// - Returns: FitnessEntry or nil if parsing fails
    func parseExerciseLine(_ line: String) -> FitnessEntry? {
        // Remove leading dash and whitespace
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("-") {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        
        // Split by colon to get name and details
        let parts = text.components(separatedBy: ":")
        guard parts.count >= 2 else { return nil }
        
        let name = parts[0].trimmingCharacters(in: .whitespaces)
        let details = parts[1].trimmingCharacters(in: .whitespaces)
        
        // Extract duration (e.g., "5min")
        var duration = 5 // default
        if let durationRegex = try? NSRegularExpression(pattern: #"(\d+)\s*min"#, options: .caseInsensitive) {
            let nsDetails = details as NSString
            if let match = durationRegex.firstMatch(in: details, range: NSRange(location: 0, length: nsDetails.length)) {
                if let durationRange = Range(match.range(at: 1), in: details) {
                    duration = Int(details[durationRange]) ?? 5
                }
            }
        }
        
        // Extract calories (e.g., "40cal")
        var calories = duration * 7 // default fallback
        if let caloriesRegex = try? NSRegularExpression(pattern: #"(\d+)\s*cal"#, options: .caseInsensitive) {
            let nsDetails = details as NSString
            if let match = caloriesRegex.firstMatch(in: details, range: NSRange(location: 0, length: nsDetails.length)) {
                if let caloriesRange = Range(match.range(at: 1), in: details) {
                    calories = Int(details[caloriesRange]) ?? calories
                }
            }
        }
        
        return FitnessEntry(
            exercise: nil,
            customName: name,
            minutesInt: duration,
            caloriesText: String(calories)
        )
    }
    
    // MARK: - Food Parsing
    
    /// Parse food line like "- Grilled Chicken: 6oz, 280cal" or "- Oatmeal: 1 serving, 150cal"
    /// - Parameter line: Food line text
    /// - Returns: DietEntry or nil if parsing fails
    func parseFoodLine(_ line: String) -> DietEntry? {
        print("🍽️ Parsing food line: \(line)")
        
        // Remove leading dash and whitespace
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("-") {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        
        // Split by colon to get name and details
        let parts = text.components(separatedBy: ":")
        guard parts.count >= 2 else {
            print("❌ Failed to parse: no colon found")
            return nil
        }
        
        let name = parts[0].trimmingCharacters(in: .whitespaces)
        let details = parts[1].trimmingCharacters(in: .whitespaces)
        
        print("   Name: \(name)")
        print("   Details: \(details)")
        
        // Extract portion and unit (e.g., "6oz" -> quantity: "6", unit: "oz")
        var quantity = "1"
        var unit = "serving"
        
        let portionComponents = details.components(separatedBy: ",")
        if !portionComponents.isEmpty {
            let portionText = portionComponents[0].trimmingCharacters(in: .whitespaces)
            print("   Portion text: '\(portionText)'")
            
            // Try multiple regex patterns to match different formats
            var matched = false
            
            // Pattern 1: Number + unit with optional space (e.g., "6oz", "6 oz", "150g", "150 g")
            if let regex = try? NSRegularExpression(pattern: #"^(\d+\.?\d*)\s*([a-zA-Z]+)$"#, options: []) {
                let nsPortionText = portionText as NSString
                if let match = regex.firstMatch(in: portionText, range: NSRange(location: 0, length: nsPortionText.length)) {
                    if let qtyRange = Range(match.range(at: 1), in: portionText) {
                        quantity = String(portionText[qtyRange])
                    }
                    if let unitRange = Range(match.range(at: 2), in: portionText) {
                        unit = String(portionText[unitRange])
                    }
                    matched = true
                    print("   ✅ Matched pattern 1: qty=\(quantity), unit=\(unit)")
                }
            }
            
            // Pattern 2: Number + space + word unit (e.g., "1 serving", "2 cups")
            if !matched, let regex = try? NSRegularExpression(pattern: #"^(\d+\.?\d*)\s+([a-zA-Z\s]+)$"#, options: []) {
                let nsPortionText = portionText as NSString
                if let match = regex.firstMatch(in: portionText, range: NSRange(location: 0, length: nsPortionText.length)) {
                    if let qtyRange = Range(match.range(at: 1), in: portionText) {
                        quantity = String(portionText[qtyRange])
                    }
                    if let unitRange = Range(match.range(at: 2), in: portionText) {
                        unit = String(portionText[unitRange]).trimmingCharacters(in: .whitespaces)
                    }
                    matched = true
                    print("   ✅ Matched pattern 2: qty=\(quantity), unit=\(unit)")
                }
            }
            
            // Pattern 3: Just a unit word (e.g., "serving")
            if !matched && portionText.range(of: #"^[a-zA-Z\s]+$"#, options: .regularExpression) != nil {
                unit = portionText
                quantity = "1"
                matched = true
                print("   ✅ Matched pattern 3 (unit only): qty=\(quantity), unit=\(unit)")
            }
            
            if !matched {
                print("   ⚠️ No pattern matched, using defaults")
            }
        }
        
        // Extract calories (e.g., "280cal")
        var calories = 100 // default fallback
        if let caloriesRegex = try? NSRegularExpression(pattern: #"(\d+)\s*cal"#, options: .caseInsensitive) {
            let nsDetails = details as NSString
            if let match = caloriesRegex.firstMatch(in: details, range: NSRange(location: 0, length: nsDetails.length)) {
                if let caloriesRange = Range(match.range(at: 1), in: details) {
                    calories = Int(details[caloriesRange]) ?? calories
                }
            }
        }
        
        print("   📊 Final parsed: qty=\(quantity), unit=\(unit), cal=\(calories)")
        
        return DietEntry(
            food: nil,
            customName: name,
            quantityText: quantity,
            unit: unit,
            caloriesText: String(calories)
        )
    }
}

