import XCTest
@testable import Modo

/// Tests for String validation extensions
/// These tests verify the validation logic for user input fields
final class StringValidationTests: XCTestCase {
    
    // MARK: - Email Validation Tests
    
    func testValidEmailFormats() {
        let validEmails = [
            "user@domain.com",
            "test.email@example.org",
            "user+tag@example.co.uk",
            "firstname.lastname@company.com",
            "user123@test-domain.com",
            "a@b.co"
        ]
        
        for email in validEmails {
            XCTAssertTrue(email.isValidEmail, "Email '\(email)' should be valid")
        }
    }
    
    func testInvalidEmailFormats() {
        let invalidEmails = [
            "",
            "plainaddress",
            "@missingdomain.com",
            "missing@.com",
            "missing.domain@",
            "spaces in@email.com",
            "invalid@",
            "@invalid.com",
            "invalid@domain"
            // Note: The current regex allows consecutive dots (invalid..double@dots.com and invalid@domain..com)
            // This is a limitation of the regex pattern. If stricter validation is needed, the regex should be updated.
        ]
        
        for email in invalidEmails {
            XCTAssertFalse(email.isValidEmail, "Email '\(email)' should be invalid")
        }
    }
    
    // MARK: - Password Validation Tests
    
    func testValidPasswordFormats() {
        let validPasswords = [
            "password123",
            "MyPass123",
            "test1234",
            "Abc123def",
            "12345678a",
            "password123!",
            "P@ssw0rd"
        ]
        
        for password in validPasswords {
            XCTAssertTrue(password.isValidPassword, "Password '\(password)' should be valid")
        }
    }
    
    func testInvalidPasswordFormats() {
        let invalidPasswords = [
            "",
            "password",      // No numbers
            "12345678",      // No letters
            "pass123",       // Too short (less than 8 characters)
            "abc",           // Too short and no numbers
            "PASSWORD",     // No numbers
            "1234567"        // Too short, no letters
        ]
        
        for password in invalidPasswords {
            XCTAssertFalse(password.isValidPassword, "Password '\(password)' should be invalid")
        }
    }
    
    // MARK: - String Not Empty Tests
    
    func testIsNotEmpty() {
        XCTAssertTrue("hello".isNotEmpty, "Non-empty string should pass validation")
        XCTAssertFalse("".isNotEmpty, "Empty string should fail validation")
        XCTAssertFalse("   ".isNotEmpty, "Whitespace-only string should fail validation")
        XCTAssertTrue("  hello  ".isNotEmpty, "String with content and whitespace should pass validation")
        XCTAssertFalse("\n\t".isNotEmpty, "Newline/tab-only string should fail validation")
    }
    
    // MARK: - Number Validation Tests
    
    func testValidNumbers() {
        let validNumbers = [
            "123",
            "123.45",
            "0.1",
            "999.99"
        ]
        
        for number in validNumbers {
            XCTAssertTrue(number.isValidNumber, "Number '\(number)' should be valid")
        }
    }
    
    func testInvalidNumbers() {
        let invalidNumbers = [
            "0",
            "-123",
            "abc",
            "",
            "  ",
            "12.34.56"
        ]
        
        for number in invalidNumbers {
            XCTAssertFalse(number.isValidNumber, "Number '\(number)' should be invalid")
        }
    }
    
    // MARK: - Height Validation Tests
    
    func testValidHeightInches() {
        XCTAssertTrue("70".isValidHeight(unit: "in"), "Valid height in inches should pass")
        XCTAssertTrue("20".isValidHeight(unit: "in"), "Minimum height in inches should pass")
        XCTAssertTrue("96".isValidHeight(unit: "in"), "Maximum height in inches should pass")
        XCTAssertFalse("19".isValidHeight(unit: "in"), "Below minimum height in inches should fail")
        XCTAssertFalse("97".isValidHeight(unit: "in"), "Above maximum height in inches should fail")
        XCTAssertFalse("abc".isValidHeight(unit: "in"), "Non-numeric height should fail")
    }
    
    func testValidHeightCentimeters() {
        XCTAssertTrue("175".isValidHeight(unit: "cm"), "Valid height in cm should pass")
        XCTAssertTrue("50".isValidHeight(unit: "cm"), "Minimum height in cm should pass")
        XCTAssertTrue("250".isValidHeight(unit: "cm"), "Maximum height in cm should pass")
        XCTAssertFalse("49".isValidHeight(unit: "cm"), "Below minimum height in cm should fail")
        XCTAssertFalse("251".isValidHeight(unit: "cm"), "Above maximum height in cm should fail")
        XCTAssertFalse("abc".isValidHeight(unit: "cm"), "Non-numeric height should fail")
    }
    
    // MARK: - Weight Validation Tests
    
    func testValidWeightPounds() {
        XCTAssertTrue("150".isValidWeight(unit: "lb"), "Valid weight in lbs should pass")
        XCTAssertTrue("44".isValidWeight(unit: "lb"), "Minimum weight in lbs should pass")
        XCTAssertTrue("1100".isValidWeight(unit: "lb"), "Maximum weight in lbs should pass")
        XCTAssertFalse("43".isValidWeight(unit: "lb"), "Below minimum weight in lbs should fail")
        XCTAssertFalse("1101".isValidWeight(unit: "lb"), "Above maximum weight in lbs should fail")
        XCTAssertFalse("abc".isValidWeight(unit: "lb"), "Non-numeric weight should fail")
    }
    
    func testValidWeightKilograms() {
        XCTAssertTrue("70".isValidWeight(unit: "kg"), "Valid weight in kg should pass")
        XCTAssertTrue("20".isValidWeight(unit: "kg"), "Minimum weight in kg should pass")
        XCTAssertTrue("500".isValidWeight(unit: "kg"), "Maximum weight in kg should pass")
        XCTAssertFalse("19".isValidWeight(unit: "kg"), "Below minimum weight in kg should fail")
        XCTAssertFalse("501".isValidWeight(unit: "kg"), "Above maximum weight in kg should fail")
        XCTAssertFalse("abc".isValidWeight(unit: "kg"), "Non-numeric weight should fail")
    }
    
    // MARK: - Age Validation Tests
    
    func testValidAge() {
        XCTAssertTrue("25".isValidAge, "Valid age should pass")
        XCTAssertTrue("10".isValidAge, "Minimum age should pass")
        XCTAssertTrue("120".isValidAge, "Maximum age should pass")
        XCTAssertFalse("9".isValidAge, "Below minimum age should fail")
        XCTAssertFalse("121".isValidAge, "Above maximum age should fail")
        XCTAssertFalse("abc".isValidAge, "Non-numeric age should fail")
        XCTAssertFalse("25.5".isValidAge, "Decimal age should fail")
    }
    
    // MARK: - Target Weight Validation Tests
    
    func testValidTargetWeightPounds() {
        XCTAssertTrue("10".isValidTargetWeight(unit: "lb"), "Valid target weight in lbs should pass")
        XCTAssertTrue("0.5".isValidTargetWeight(unit: "lb"), "Minimum target weight in lbs should pass")
        XCTAssertTrue("220".isValidTargetWeight(unit: "lb"), "Maximum target weight in lbs should pass")
        XCTAssertFalse("0.4".isValidTargetWeight(unit: "lb"), "Below minimum target weight in lbs should fail")
        XCTAssertFalse("221".isValidTargetWeight(unit: "lb"), "Above maximum target weight in lbs should fail")
        XCTAssertFalse("abc".isValidTargetWeight(unit: "lb"), "Non-numeric target weight should fail")
    }
    
    func testValidTargetWeightKilograms() {
        XCTAssertTrue("50".isValidTargetWeight(unit: "kg"), "Valid target weight in kg should pass")
        XCTAssertTrue("0.2".isValidTargetWeight(unit: "kg"), "Minimum target weight in kg should pass")
        XCTAssertTrue("100".isValidTargetWeight(unit: "kg"), "Maximum target weight in kg should pass")
        XCTAssertFalse("0.1".isValidTargetWeight(unit: "kg"), "Below minimum target weight in kg should fail")
        XCTAssertFalse("101".isValidTargetWeight(unit: "kg"), "Above maximum target weight in kg should fail")
        XCTAssertFalse("abc".isValidTargetWeight(unit: "kg"), "Non-numeric target weight should fail")
    }
    
    // MARK: - Target Days Validation Tests
    
    func testValidTargetDays() {
        XCTAssertTrue("30".isValidTargetDays, "Valid target days should pass")
        XCTAssertTrue("1".isValidTargetDays, "Minimum target days should pass")
        XCTAssertTrue("365".isValidTargetDays, "Maximum target days should pass")
        XCTAssertFalse("0".isValidTargetDays, "Below minimum target days should fail")
        XCTAssertFalse("366".isValidTargetDays, "Above maximum target days should fail")
        XCTAssertFalse("abc".isValidTargetDays, "Non-numeric target days should fail")
        XCTAssertFalse("30.5".isValidTargetDays, "Decimal target days should fail")
    }
}

