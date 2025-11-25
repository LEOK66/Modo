import XCTest
@testable import Modo

/// AIServiceUtils utility class tests
///
/// Tests correctness of all utility methods
final class AIServiceUtilsTests: XCTestCase {
    
    // MARK: - Date Formatting Tests
    
    func testFormatDate() {
        // Given
        let components = DateComponents(year: 2024, month: 11, day: 17)
        let date = Calendar.current.date(from: components)!
        
        // When
        let formatted = AIServiceUtils.formatDate(date)
        
        // Then
        XCTAssertEqual(formatted, "2024-11-17")
    }
    
    func testParseDate() {
        // Given
        let dateString = "2024-11-17"
        
        // When
        let date = AIServiceUtils.parseDate(dateString)
        
        // Then
        XCTAssertNotNil(date)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 11)
        XCTAssertEqual(components.day, 17)
    }
    
    func testParseDateInvalid() {
        // Given
        let invalidDateString = "invalid-date"
        
        // When
        let date = AIServiceUtils.parseDate(invalidDateString)
        
        // Then
        XCTAssertNil(date)
    }
    
    func testFormatAndParseRoundtrip() {
        // Given
        let originalDate = Date()
        
        // When
        let formatted = AIServiceUtils.formatDate(originalDate)
        let parsed = AIServiceUtils.parseDate(formatted)
        
        // Then
        XCTAssertNotNil(parsed)
        
        // Compare only date components (ignore time)
        let calendar = Calendar.current
        let originalComponents = calendar.dateComponents([.year, .month, .day], from: originalDate)
        let parsedComponents = calendar.dateComponents([.year, .month, .day], from: parsed!)
        
        XCTAssertEqual(originalComponents.year, parsedComponents.year)
        XCTAssertEqual(originalComponents.month, parsedComponents.month)
        XCTAssertEqual(originalComponents.day, parsedComponents.day)
    }
    
    // MARK: - Time Formatting Tests
    
    func testFormatTime() {
        // Given
        let components = DateComponents(year: 2024, month: 11, day: 17, hour: 14, minute: 30)
        let date = Calendar.current.date(from: components)!
        
        // When
        let formatted = AIServiceUtils.formatTime(date)
        
        // Then
        XCTAssertEqual(formatted, "2:30 PM")
    }
    
    func testParseTime() {
        // Given
        let timeString = "2:30 PM"
        
        // When
        let date = AIServiceUtils.parseTime(timeString)
        
        // Then
        XCTAssertNotNil(date)
        let components = Calendar.current.dateComponents([.hour, .minute], from: date!)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 30)
    }
    
    // MARK: - Meal Time Tests
    
    func testGetDefaultMealTimeBreakfast() {
        // When
        let time = AIServiceUtils.getDefaultMealTime(for: "breakfast")
        
        // Then
        XCTAssertEqual(time, "8:00 AM")
    }
    
    func testGetDefaultMealTimeLunch() {
        // When
        let time = AIServiceUtils.getDefaultMealTime(for: "lunch")
        
        // Then
        XCTAssertEqual(time, "12:00 PM")
    }
    
    func testGetDefaultMealTimeDinner() {
        // When
        let time = AIServiceUtils.getDefaultMealTime(for: "dinner")
        
        // Then
        XCTAssertEqual(time, "6:00 PM")
    }
    
    func testGetDefaultMealTimeSnack() {
        // When
        let time = AIServiceUtils.getDefaultMealTime(for: "snack")
        
        // Then
        XCTAssertEqual(time, "3:00 PM")
    }
    
    func testGetDefaultMealTimeUnknown() {
        // When
        let time = AIServiceUtils.getDefaultMealTime(for: "unknown")
        
        // Then
        XCTAssertEqual(time, "12:00 PM")
    }
    
    func testGetDefaultMealTimeCaseInsensitive() {
        // Test case insensitivity
        XCTAssertEqual(AIServiceUtils.getDefaultMealTime(for: "BREAKFAST"), "8:00 AM")
        XCTAssertEqual(AIServiceUtils.getDefaultMealTime(for: "Lunch"), "12:00 PM")
        XCTAssertEqual(AIServiceUtils.getDefaultMealTime(for: "DiNnEr"), "6:00 PM")
    }
    
    // MARK: - Meal Type Detection Tests
    
    func testDetectMealTypeBreakfast() {
        // When
        let mealType = AIServiceUtils.detectMealType(from: "I want breakfast")
        
        // Then
        XCTAssertEqual(mealType, "breakfast")
    }
    
    func testDetectMealTypeLunch() {
        // When
        let mealType = AIServiceUtils.detectMealType(from: "lunch plan")
        
        // Then
        XCTAssertEqual(mealType, "lunch")
    }
    
    func testDetectMealTypeDinner() {
        // When
        let mealType = AIServiceUtils.detectMealType(from: "dinner ideas")
        
        // Then
        XCTAssertEqual(mealType, "dinner")
    }
    
    func testDetectMealTypeSnack() {
        // When
        let mealType = AIServiceUtils.detectMealType(from: "quick snack")
        
        // Then
        XCTAssertEqual(mealType, "snack")
    }
    
    func testDetectMealTypeNone() {
        // When
        let mealType = AIServiceUtils.detectMealType(from: "something else")
        
        // Then
        XCTAssertNil(mealType)
    }
    
    func testDetectMealTypeCaseInsensitive() {
        // Test case insensitivity
        XCTAssertEqual(AIServiceUtils.detectMealType(from: "BREAKFAST time"), "breakfast")
        XCTAssertEqual(AIServiceUtils.detectMealType(from: "Lunch Break"), "lunch")
    }
    
    // MARK: - Category Icon Tests
    
    func testGetCategoryIconFitness() {
        // When
        let icon = AIServiceUtils.getCategoryIcon(for: "fitness")
        
        // Then
        XCTAssertEqual(icon, "💪")
    }
    
    func testGetCategoryIconDiet() {
        // When
        let icon = AIServiceUtils.getCategoryIcon(for: "diet")
        
        // Then
        XCTAssertEqual(icon, "🍽️")
    }
    
    func testGetCategoryIconOthers() {
        // When
        let icon = AIServiceUtils.getCategoryIcon(for: "others")
        
        // Then
        XCTAssertEqual(icon, "📌")
    }
    
    func testGetCategoryIconUnknown() {
        // When
        let icon = AIServiceUtils.getCategoryIcon(for: "unknown")
        
        // Then
        XCTAssertEqual(icon, "📝")
    }
    
    func testGetCategoryIconCaseInsensitive() {
        // Test case insensitivity
        XCTAssertEqual(AIServiceUtils.getCategoryIcon(for: "FITNESS"), "💪")
        XCTAssertEqual(AIServiceUtils.getCategoryIcon(for: "Diet"), "🍽️")
    }
    
    // MARK: - Category Color Tests
    
    func testGetCategoryColorFitness() {
        // When
        let color = AIServiceUtils.getCategoryColor(for: "fitness")
        
        // Then
        XCTAssertEqual(color, "#6366F1")
    }
    
    func testGetCategoryColorDiet() {
        // When
        let color = AIServiceUtils.getCategoryColor(for: "diet")
        
        // Then
        XCTAssertEqual(color, "#F59E0B")
    }
    
    func testGetCategoryColorOthers() {
        // When
        let color = AIServiceUtils.getCategoryColor(for: "others")
        
        // Then
        XCTAssertEqual(color, "#8B5CF6")
    }
    
    func testGetCategoryColorUnknown() {
        // When
        let color = AIServiceUtils.getCategoryColor(for: "unknown")
        
        // Then
        XCTAssertEqual(color, "#9CA3AF")
    }
    
    func testGetCategoryColorCaseInsensitive() {
        // Test case insensitivity
        XCTAssertEqual(AIServiceUtils.getCategoryColor(for: "FITNESS"), "#6366F1")
        XCTAssertEqual(AIServiceUtils.getCategoryColor(for: "Diet"), "#F59E0B")
    }
}

