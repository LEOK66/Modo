import XCTest
@testable import Modo

/// Tests for HealthCalculator
/// These tests verify health calculation functions
final class HealthCalculatorTests: XCTestCase {
    
    // MARK: - Unit Conversion Tests
    
    func testConvertWeightToKg() {
        // Test pound to kilogram conversion
        let weightLb = 150.0
        let weightKg = HealthCalculator.convertWeightToKg(weightLb, unit: "lb")
        let expectedKg = weightLb * 0.45359237
        XCTAssertEqual(weightKg, expectedKg, accuracy: 0.01, "Should convert pounds to kilograms")
        
        // Test kilogram to kilogram (no conversion)
        let weightKg2 = HealthCalculator.convertWeightToKg(70.0, unit: "kg")
        XCTAssertEqual(weightKg2, 70.0, "Should return same value for kilograms")
    }
    
    func testConvertHeightToCm() {
        // Test inch to centimeter conversion
        let heightIn = 70.0
        let heightCm = HealthCalculator.convertHeightToCm(heightIn, unit: "in")
        let expectedCm = heightIn * 2.54
        XCTAssertEqual(heightCm, expectedCm, accuracy: 0.01, "Should convert inches to centimeters")
        
        // Test centimeter to centimeter (no conversion)
        let heightCm2 = HealthCalculator.convertHeightToCm(175.0, unit: "cm")
        XCTAssertEqual(heightCm2, 175.0, "Should return same value for centimeters")
    }
    
    // MARK: - BMR Calculation Tests
    
    func testBMRMifflinStJeorMale() {
        let age = 30
        let gender = "male"
        let weightKg = 80.0
        let heightCm = 180.0
        
        let bmr = HealthCalculator.bmrMifflinStJeor(age: age, genderCode: gender, weightKg: weightKg, heightCm: heightCm)
        
        // Expected BMR for male: 10 * 80 + 6.25 * 180 - 5 * 30 + 5 = 800 + 1125 - 150 + 5 = 1780
        let expectedBMR = 10.0 * weightKg + 6.25 * heightCm - 5.0 * Double(age) + 5.0
        XCTAssertEqual(bmr, expectedBMR, accuracy: 0.1, "BMR for male should be calculated correctly")
    }
    
    func testBMRMifflinStJeorFemale() {
        let age = 25
        let gender = "female"
        let weightKg = 65.0
        let heightCm = 165.0
        
        let bmr = HealthCalculator.bmrMifflinStJeor(age: age, genderCode: gender, weightKg: weightKg, heightCm: heightCm)
        
        // Expected BMR for female: 10 * 65 + 6.25 * 165 - 5 * 25 - 161 = 650 + 1031.25 - 125 - 161 = 1395.25
        let expectedBMR = 10.0 * weightKg + 6.25 * heightCm - 5.0 * Double(age) - 161.0
        XCTAssertEqual(bmr, expectedBMR, accuracy: 0.1, "BMR for female should be calculated correctly")
    }
    
    func testBMRMifflinStJeorDefault() {
        let age = 30
        let gender = "other"
        let weightKg = 75.0
        let heightCm = 175.0
        
        let bmr = HealthCalculator.bmrMifflinStJeor(age: age, genderCode: gender, weightKg: weightKg, heightCm: heightCm)
        
        // Should be average of male and female
        let maleBMR = 10.0 * weightKg + 6.25 * heightCm - 5.0 * Double(age) + 5.0
        let femaleBMR = 10.0 * weightKg + 6.25 * heightCm - 5.0 * Double(age) - 161.0
        let expectedBMR = (maleBMR + femaleBMR) / 2.0
        XCTAssertEqual(bmr, expectedBMR, accuracy: 0.1, "BMR for other gender should be average")
    }
    
    // MARK: - Activity Factor Tests
    
    func testActivityFactor() {
        XCTAssertEqual(HealthCalculator.activityFactor(for: "sedentary"), 1.2, "Sedentary activity factor should be 1.2")
        XCTAssertEqual(HealthCalculator.activityFactor(for: "moderately_active"), 1.55, "Moderately active factor should be 1.55")
        XCTAssertEqual(HealthCalculator.activityFactor(for: "athletic"), 1.725, "Athletic factor should be 1.725")
        XCTAssertEqual(HealthCalculator.activityFactor(for: "unknown"), 1.2, "Unknown activity should default to 1.2")
    }
    
    func testTDEE() {
        let bmr = 1800.0
        
        let sedentaryTDEE = HealthCalculator.tdee(bmr: bmr, lifestyleCode: "sedentary")
        XCTAssertEqual(sedentaryTDEE, bmr * 1.2, accuracy: 0.1, "TDEE should multiply BMR by activity factor")
        
        let activeTDEE = HealthCalculator.tdee(bmr: bmr, lifestyleCode: "moderately_active")
        XCTAssertEqual(activeTDEE, bmr * 1.55, accuracy: 0.1, "TDEE should multiply BMR by activity factor")
    }
    
    // MARK: - Recommended Calories Tests
    
    func testRecommendedCalories() {
        let age = 30
        let gender = "male"
        let weightKg = 80.0
        let heightCm = 180.0
        let lifestyle = "moderately_active"
        
        let recommendedCalories = HealthCalculator.recommendedCalories(
            age: age,
            genderCode: gender,
            weightKg: weightKg,
            heightCm: heightCm,
            lifestyleCode: lifestyle
        )
        
        let bmr = HealthCalculator.bmrMifflinStJeor(age: age, genderCode: gender, weightKg: weightKg, heightCm: heightCm)
        let expectedCalories = Int(HealthCalculator.tdee(bmr: bmr, lifestyleCode: lifestyle))
        
        XCTAssertEqual(recommendedCalories, expectedCalories, "Recommended calories should match TDEE")
        XCTAssertGreaterThan(recommendedCalories, 0, "Recommended calories should be positive")
    }
    
    // MARK: - Recommended Protein Tests
    
    func testRecommendedProtein() {
        let weightKg = 80.0
        let defaultProtein = HealthCalculator.recommendedProtein(weightKg: weightKg)
        let expectedDefault = Int(round(weightKg * 1.8))
        XCTAssertEqual(defaultProtein, expectedDefault, "Default protein should be 1.8 g/kg")
        
        let customProtein = HealthCalculator.recommendedProtein(weightKg: weightKg, gramsPerKg: 2.0)
        let expectedCustom = Int(round(weightKg * 2.0))
        XCTAssertEqual(customProtein, expectedCustom, "Custom protein should match specified ratio")
    }
    
    // MARK: - Target Calories Tests
    
    func testTargetCaloriesLoseWeight() {
        let age = 30
        let gender = "male"
        let weightKg = 80.0
        let heightCm = 180.0
        let lifestyle = "moderately_active"
        let goal = "lose_weight"
        
        let targetCalories = HealthCalculator.targetCalories(
            goal: goal,
            age: age,
            genderCode: gender,
            weightKg: weightKg,
            heightCm: heightCm,
            lifestyleCode: lifestyle,
            userInputCalories: nil
        )
        
        XCTAssertNotNil(targetCalories, "Target calories should not be nil")
        if let target = targetCalories {
            let tdee = HealthCalculator.recommendedCalories(age: age, genderCode: gender, weightKg: weightKg, heightCm: heightCm, lifestyleCode: lifestyle)
            let expectedTarget = max(800, tdee - 500) // Minimum 800 calories
            XCTAssertEqual(target, expectedTarget, "Lose weight target should be TDEE - 500 (min 800)")
        }
    }
    
    func testTargetCaloriesKeepHealthy() {
        let goal = "keep_healthy"
        let userInputCalories = 2000
        
        // Test with user input
        let targetWithInput = HealthCalculator.targetCalories(
            goal: goal,
            age: nil,
            genderCode: nil,
            weightKg: nil,
            heightCm: nil,
            lifestyleCode: nil,
            userInputCalories: userInputCalories
        )
        
        XCTAssertEqual(targetWithInput, userInputCalories, "Keep healthy should use user input when available")
        
        // Test without user input but with TDEE data
        let age = 30
        let gender = "male"
        let weightKg = 80.0
        let heightCm = 180.0
        let lifestyle = "moderately_active"
        
        let targetWithoutInput = HealthCalculator.targetCalories(
            goal: goal,
            age: age,
            genderCode: gender,
            weightKg: weightKg,
            heightCm: heightCm,
            lifestyleCode: lifestyle,
            userInputCalories: nil
        )
        
        XCTAssertNotNil(targetWithoutInput, "Target calories should not be nil")
        if let target = targetWithoutInput {
            let tdee = HealthCalculator.recommendedCalories(age: age, genderCode: gender, weightKg: weightKg, heightCm: heightCm, lifestyleCode: lifestyle)
            XCTAssertEqual(target, tdee, "Keep healthy should use TDEE when no user input")
        }
    }
    
    func testTargetCaloriesGainMuscle() {
        let age = 30
        let gender = "male"
        let weightKg = 80.0
        let heightCm = 180.0
        let lifestyle = "moderately_active"
        let goal = "gain_muscle"
        
        let targetCalories = HealthCalculator.targetCalories(
            goal: goal,
            age: age,
            genderCode: gender,
            weightKg: weightKg,
            heightCm: heightCm,
            lifestyleCode: lifestyle,
            userInputCalories: nil
        )
        
        XCTAssertNotNil(targetCalories, "Target calories should not be nil")
        if let target = targetCalories {
            let tdee = HealthCalculator.recommendedCalories(age: age, genderCode: gender, weightKg: weightKg, heightCm: heightCm, lifestyleCode: lifestyle)
            let expectedTarget = tdee + 400
            XCTAssertEqual(target, expectedTarget, "Gain muscle target should be TDEE + 400")
        }
    }
    
    func testTargetCaloriesEmptyGoal() {
        let targetCalories = HealthCalculator.targetCalories(
            goal: "",
            age: 30,
            genderCode: "male",
            weightKg: 80.0,
            heightCm: 180.0,
            lifestyleCode: "moderately_active",
            userInputCalories: nil
        )
        
        XCTAssertNil(targetCalories, "Target calories should be nil for empty goal")
    }
    
    func testTargetCaloriesInsufficientData() {
        // Test with missing data
        let targetCalories = HealthCalculator.targetCalories(
            goal: "lose_weight",
            age: nil,
            genderCode: nil,
            weightKg: nil,
            heightCm: nil,
            lifestyleCode: nil,
            userInputCalories: nil
        )
        
        XCTAssertNil(targetCalories, "Target calories should be nil with insufficient data")
    }
    
    // MARK: - Macronutrients Tests
    
    func testRecommendedMacrosLoseWeight() {
        let totalCalories = 2000
        let goal = "lose_weight"
        
        let macros = HealthCalculator.recommendedMacros(goal: goal, totalCalories: totalCalories)
        
        XCTAssertNotNil(macros, "Macros should not be nil")
        if let macros = macros {
            // Lose weight: 30% protein, 45% carb, 25% fat
            let expectedProteinCalories = Double(totalCalories) * 0.30
            let expectedCarbCalories = Double(totalCalories) * 0.45
            let expectedFatCalories = Double(totalCalories) * 0.25
            
            let expectedProtein = Int(round(expectedProteinCalories / 4.0))
            let expectedCarb = Int(round(expectedCarbCalories / 4.0))
            let expectedFat = Int(round(expectedFatCalories / 9.0))
            
            XCTAssertEqual(macros.protein, expectedProtein, "Protein should match lose weight ratio")
            XCTAssertEqual(macros.carbohydrates, expectedCarb, "Carbs should match lose weight ratio")
            XCTAssertEqual(macros.fat, expectedFat, "Fat should match lose weight ratio")
        }
    }
    
    func testRecommendedMacrosKeepHealthy() {
        let totalCalories = 2000
        let goal = "keep_healthy"
        
        let macros = HealthCalculator.recommendedMacros(goal: goal, totalCalories: totalCalories)
        
        XCTAssertNotNil(macros, "Macros should not be nil")
        if let macros = macros {
            // Keep healthy: 20% protein, 55% carb, 25% fat
            let expectedProteinCalories = Double(totalCalories) * 0.20
            let expectedCarbCalories = Double(totalCalories) * 0.55
            let expectedFatCalories = Double(totalCalories) * 0.25
            
            let expectedProtein = Int(round(expectedProteinCalories / 4.0))
            let expectedCarb = Int(round(expectedCarbCalories / 4.0))
            let expectedFat = Int(round(expectedFatCalories / 9.0))
            
            XCTAssertEqual(macros.protein, expectedProtein, "Protein should match keep healthy ratio")
            XCTAssertEqual(macros.carbohydrates, expectedCarb, "Carbs should match keep healthy ratio")
            XCTAssertEqual(macros.fat, expectedFat, "Fat should match keep healthy ratio")
        }
    }
    
    func testRecommendedMacrosGainMuscle() {
        let totalCalories = 2500
        let goal = "gain_muscle"
        
        let macros = HealthCalculator.recommendedMacros(goal: goal, totalCalories: totalCalories)
        
        XCTAssertNotNil(macros, "Macros should not be nil")
        if let macros = macros {
            // Gain muscle: 35% protein, 45% carb, 20% fat
            let expectedProteinCalories = Double(totalCalories) * 0.35
            let expectedCarbCalories = Double(totalCalories) * 0.45
            let expectedFatCalories = Double(totalCalories) * 0.20
            
            let expectedProtein = Int(round(expectedProteinCalories / 4.0))
            let expectedCarb = Int(round(expectedCarbCalories / 4.0))
            let expectedFat = Int(round(expectedFatCalories / 9.0))
            
            XCTAssertEqual(macros.protein, expectedProtein, "Protein should match gain muscle ratio")
            XCTAssertEqual(macros.carbohydrates, expectedCarb, "Carbs should match gain muscle ratio")
            XCTAssertEqual(macros.fat, expectedFat, "Fat should match gain muscle ratio")
        }
    }
    
    func testRecommendedMacrosInvalidCalories() {
        let macrosZero = HealthCalculator.recommendedMacros(goal: "lose_weight", totalCalories: 0)
        XCTAssertNil(macrosZero, "Macros should be nil for zero calories")
        
        let macrosNegative = HealthCalculator.recommendedMacros(goal: "lose_weight", totalCalories: -100)
        XCTAssertNil(macrosNegative, "Macros should be nil for negative calories")
    }
    
    func testRecommendedMacrosDefaultGoal() {
        let totalCalories = 2000
        let macros = HealthCalculator.recommendedMacros(goal: "unknown_goal", totalCalories: totalCalories)
        
        XCTAssertNotNil(macros, "Macros should not be nil for unknown goal")
        if let macros = macros {
            // Should default to keep_healthy ratios
            let expectedProteinCalories = Double(totalCalories) * 0.20
            let expectedProtein = Int(round(expectedProteinCalories / 4.0))
            XCTAssertEqual(macros.protein, expectedProtein, "Unknown goal should default to keep_healthy ratios")
        }
    }
}


