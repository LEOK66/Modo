import XCTest
@testable import Modo
import FirebaseAuth

final class ModoTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called before the invocation of each test method in the class.
    }

    // MARK: - Email Validation Tests
    func testEmailValidation() throws {
        // Test email validation functionality
        let validEmail = "test@example.com"
        let invalidEmail = "invalid-email"
        
        // XCTAssertTrue checks if condition is true
        XCTAssertTrue(validEmail.isValidEmail, "Valid email should pass validation")
        XCTAssertFalse(invalidEmail.isValidEmail, "Invalid email should fail validation")
    }
    
    func testEmailValidationEdgeCases() throws {
        // Test various email formats
        let validEmails = [
            "user@domain.com",
            "test.email@example.org",
            "user+tag@example.co.uk",
            "firstname.lastname@company.com"
        ]
        
        let invalidEmails = [
            "",
            "plainaddress",
            "@missingdomain.com",
            "missing@.com",
            "missing.domain@",
            "spaces in@email.com"
        ]
        
        for email in validEmails {
            XCTAssertTrue(email.isValidEmail, "Email '\(email)' should be valid")
        }
        
        for email in invalidEmails {
            XCTAssertFalse(email.isValidEmail, "Email '\(email)' should be invalid")
        }
    }

    // MARK: - Password Validation Tests
    func testPasswordValidation() throws {
        // Test password validation functionality
        let validPassword = "password123"  // Has letters and numbers
        let invalidPassword = "password"     // Only letters, no numbers
        
        XCTAssertTrue(validPassword.isValidPassword, "Valid password should pass validation")
        XCTAssertFalse(invalidPassword.isValidPassword, "Invalid password should fail validation")
    }
    
    func testPasswordValidationEdgeCases() throws {
        // Test various password formats
        let validPasswords = [
            "password123",
            "MyPass123",
            "test1234",
            "Abc123def",
            "12345678a",
            "password123!"  // Special characters are allowed in current regex
        ]
        
        let invalidPasswords = [
            "",
            "password",      // No numbers
            "12345678",      // No letters
            "pass123",       // Too short
            "abc"           // Too short and no numbers
        ]
        
        for password in validPasswords {
            XCTAssertTrue(password.isValidPassword, "Password '\(password)' should be valid")
        }
        
        for password in invalidPasswords {
            XCTAssertFalse(password.isValidPassword, "Password '\(password)' should be invalid")
        }
    }
    
    // MARK: - Additional Validation Tests
    func testStringValidation() throws {
        // Test isNotEmpty validation
        XCTAssertTrue("hello".isNotEmpty, "Non-empty string should pass validation")
        XCTAssertFalse("".isNotEmpty, "Empty string should fail validation")
        XCTAssertFalse("   ".isNotEmpty, "Whitespace-only string should fail validation")
        XCTAssertTrue("  hello  ".isNotEmpty, "String with whitespace should pass validation")
    }
    
    func testNumberValidation() throws {
        // Test isValidNumber validation
        XCTAssertTrue("123".isValidNumber, "Positive number should be valid")
        XCTAssertTrue("123.45".isValidNumber, "Positive decimal should be valid")
        XCTAssertFalse("0".isValidNumber, "Zero should be invalid")
        XCTAssertFalse("-123".isValidNumber, "Negative number should be invalid")
        XCTAssertFalse("abc".isValidNumber, "Non-numeric string should be invalid")
        XCTAssertFalse("".isValidNumber, "Empty string should be invalid")
    }
    
    func testHeightValidation() throws {
        // Test isValidHeight validation with inches
        XCTAssertTrue("70".isValidHeight(unit: "in"), "Valid height in inches should pass")
        XCTAssertTrue("20".isValidHeight(unit: "in"), "Minimum height in inches should pass")
        XCTAssertTrue("96".isValidHeight(unit: "in"), "Maximum height in inches should pass")
        XCTAssertFalse("19".isValidHeight(unit: "in"), "Below minimum height in inches should fail")
        XCTAssertFalse("97".isValidHeight(unit: "in"), "Above maximum height in inches should fail")
        XCTAssertFalse("abc".isValidHeight(unit: "in"), "Non-numeric height should fail")
        
        // Test with cm
        XCTAssertTrue("175".isValidHeight(unit: "cm"), "Valid height in cm should pass")
        XCTAssertTrue("50".isValidHeight(unit: "cm"), "Minimum height in cm should pass")
        XCTAssertTrue("250".isValidHeight(unit: "cm"), "Maximum height in cm should pass")
        XCTAssertFalse("49".isValidHeight(unit: "cm"), "Below minimum height in cm should fail")
        XCTAssertFalse("251".isValidHeight(unit: "cm"), "Above maximum height in cm should fail")
        XCTAssertFalse("abc".isValidHeight(unit: "cm"), "Non-numeric height should fail")
    }
    
    func testWeightValidation() throws {
        // Test isValidWeight validation with lbs
        XCTAssertTrue("150".isValidWeight(unit: "lb"), "Valid weight in lbs should pass")
        XCTAssertTrue("44".isValidWeight(unit: "lb"), "Minimum weight in lbs should pass")
        XCTAssertTrue("1100".isValidWeight(unit: "lb"), "Maximum weight in lbs should pass")
        XCTAssertFalse("43".isValidWeight(unit: "lb"), "Below minimum weight in lbs should fail")
        XCTAssertFalse("1101".isValidWeight(unit: "lb"), "Above maximum weight in lbs should fail")
        XCTAssertFalse("abc".isValidWeight(unit: "lb"), "Non-numeric weight should fail")
        
        // Test with kg
        XCTAssertTrue("70".isValidWeight(unit: "kg"), "Valid weight in kg should pass")
        XCTAssertTrue("20".isValidWeight(unit: "kg"), "Minimum weight in kg should pass")
        XCTAssertTrue("500".isValidWeight(unit: "kg"), "Maximum weight in kg should pass")
        XCTAssertFalse("19".isValidWeight(unit: "kg"), "Below minimum weight in kg should fail")
        XCTAssertFalse("501".isValidWeight(unit: "kg"), "Above maximum weight in kg should fail")
        XCTAssertFalse("abc".isValidWeight(unit: "kg"), "Non-numeric weight should fail")
    }
    
    func testAgeValidation() throws {
        // Test isValidAge validation
        XCTAssertTrue("25".isValidAge, "Valid age should pass")
        XCTAssertTrue("10".isValidAge, "Minimum age should pass")
        XCTAssertTrue("120".isValidAge, "Maximum age should pass")
        XCTAssertFalse("9".isValidAge, "Below minimum age should fail")
        XCTAssertFalse("121".isValidAge, "Above maximum age should fail")
        XCTAssertFalse("abc".isValidAge, "Non-numeric age should fail")
    }
    
    func testTargetWeightValidation() throws {
        // Test isValidTargetWeight validation with lbs
        XCTAssertTrue("10".isValidTargetWeight(unit: "lb"), "Valid target weight in lbs should pass")
        XCTAssertTrue("0.5".isValidTargetWeight(unit: "lb"), "Minimum target weight in lbs should pass")
        XCTAssertTrue("220".isValidTargetWeight(unit: "lb"), "Maximum target weight in lbs should pass")
        XCTAssertFalse("0.4".isValidTargetWeight(unit: "lb"), "Below minimum target weight in lbs should fail")
        XCTAssertFalse("221".isValidTargetWeight(unit: "lb"), "Above maximum target weight in lbs should fail")
        XCTAssertFalse("abc".isValidTargetWeight(unit: "lb"), "Non-numeric target weight should fail")
        
        // Test with kg
        XCTAssertTrue("50".isValidTargetWeight(unit: "kg"), "Valid target weight in kg should pass")
        XCTAssertTrue("0.2".isValidTargetWeight(unit: "kg"), "Minimum target weight in kg should pass")
        XCTAssertTrue("100".isValidTargetWeight(unit: "kg"), "Maximum target weight in kg should pass")
        XCTAssertFalse("0.1".isValidTargetWeight(unit: "kg"), "Below minimum target weight in kg should fail")
        XCTAssertFalse("101".isValidTargetWeight(unit: "kg"), "Above maximum target weight in kg should fail")
        XCTAssertFalse("abc".isValidTargetWeight(unit: "kg"), "Non-numeric target weight should fail")
    }
    
    func testTargetDaysValidation() throws {
        // Test isValidTargetDays validation
        XCTAssertTrue("30".isValidTargetDays, "Valid target days should pass")
        XCTAssertTrue("1".isValidTargetDays, "Minimum target days should pass")
        XCTAssertTrue("365".isValidTargetDays, "Maximum target days should pass")
        XCTAssertFalse("0".isValidTargetDays, "Below minimum target days should fail")
        XCTAssertFalse("366".isValidTargetDays, "Above maximum target days should fail")
        XCTAssertFalse("abc".isValidTargetDays, "Non-numeric target days should fail")
    }
    
    // MARK: - Performance Tests
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
            let emails = ["test1@example.com", "test2@example.com", "test3@example.com"]
            for email in emails {
                _ = email.isValidEmail
            }
        }
    }
    
    func testEmailValidationPerformance() throws {
        // Test performance of email validation with many inputs
        self.measure {
            let testEmails = (1...1000).map { "user\($0)@example.com" }
            for email in testEmails {
                _ = email.isValidEmail
            }
        }
    }

}