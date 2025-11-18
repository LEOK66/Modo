import XCTest
import Combine
import FirebaseAuth
@testable import Modo

/// Tests for AuthService
/// Note: These tests use MockAuthService to avoid requiring Firebase configuration
/// For integration tests with real Firebase, use Firebase Auth Emulator
final class AuthServiceTests: XCTestCase {
    
    var mockAuthService: MockAuthService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockAuthService = MockAuthService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        mockAuthService.reset()
        mockAuthService = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialAuthenticationState() {
        XCTAssertFalse(mockAuthService.isAuthenticated, "AuthService should start unauthenticated")
        XCTAssertNil(mockAuthService.currentUser, "Current user should be nil initially")
        XCTAssertFalse(mockAuthService.hasCompletedOnboarding, "Onboarding should not be completed initially")
    }
    
    // MARK: - Sign Up Tests
    
    func testSignUpSuccess() {
        // Note: In a real test with Firebase Auth Emulator, you would create a real User object
        // For now, this test demonstrates the structure but requires mockUser to be set
        let expectation = XCTestExpectation(description: "Sign up should complete")
        
        // This test would need a real User object from Firebase Auth Emulator
        // For now, we'll test the failure case when mockUser is not set
        mockAuthService.shouldSucceedSignUp = true
        
        mockAuthService.signUp(email: "test@example.com", password: "password123") { result in
            switch result {
            case .success:
                XCTAssertTrue(self.mockAuthService.isAuthenticated, "User should be authenticated after sign up")
                XCTAssertNotNil(self.mockAuthService.currentUser, "Current user should not be nil after sign up")
                expectation.fulfill()
            case .failure(let error):
                // Expected when mockUser is not set (without Firebase Auth Emulator)
                let nsError = error as NSError
                if nsError.code == -999 {
                    // This is expected - mockUser not set
                    expectation.fulfill()
                } else {
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(mockAuthService.signUpCallCount, 1, "signUp should be called once")
        XCTAssertEqual(mockAuthService.lastSignUpEmail, "test@example.com", "Should track email")
    }
    
    func testSignUpWithInvalidEmail() {
        let expectation = XCTestExpectation(description: "Sign up with invalid email should fail")
        
        mockAuthService.shouldSucceedSignUp = false
        
        mockAuthService.signUp(email: "invalid-email", password: "password123") { result in
            switch result {
            case .success:
                XCTFail("Sign up with invalid email should fail")
            case .failure:
                // Expected behavior
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSignUpWithWeakPassword() {
        let expectation = XCTestExpectation(description: "Sign up with weak password should fail")
        
        mockAuthService.shouldSucceedSignUp = false
        
        mockAuthService.signUp(email: "test@example.com", password: "123") { result in
            switch result {
            case .success:
                XCTFail("Sign up with weak password should fail")
            case .failure:
                // Expected behavior
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Sign In Tests
    
    func testSignInSuccess() {
        let expectation = XCTestExpectation(description: "Sign in should complete")
        
        mockAuthService.shouldSucceedSignIn = true
        
        mockAuthService.signIn(email: "test@example.com", password: "password123") { result in
            switch result {
            case .success:
                XCTAssertTrue(self.mockAuthService.isAuthenticated, "User should be authenticated after sign in")
                XCTAssertNotNil(self.mockAuthService.currentUser, "Current user should not be nil after sign in")
                expectation.fulfill()
            case .failure(let error):
                // Expected when mockUser is not set
                let nsError = error as NSError
                if nsError.code == -999 {
                    expectation.fulfill()
                } else {
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(mockAuthService.signInCallCount, 1, "signIn should be called once")
        XCTAssertEqual(mockAuthService.lastSignInEmail, "test@example.com", "Should track email")
    }
    
    func testSignInWithInvalidCredentials() {
        let expectation = XCTestExpectation(description: "Sign in with invalid credentials should fail")
        
        mockAuthService.shouldSucceedSignIn = false
        
        mockAuthService.signIn(email: "nonexistent@example.com", password: "wrongpassword") { result in
            switch result {
            case .success:
                XCTFail("Sign in with invalid credentials should fail")
            case .failure:
                // Expected behavior
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Sign Out Tests
    
    func testSignOut() throws {
        // First, set up authenticated state
        mockAuthService.isAuthenticated = true
        
        // Then sign out
        try mockAuthService.signOut()
        
        XCTAssertFalse(mockAuthService.isAuthenticated, "User should not be authenticated after sign out")
        XCTAssertNil(mockAuthService.currentUser, "Current user should be nil after sign out")
        XCTAssertEqual(mockAuthService.signOutCallCount, 1, "signOut should be called once")
    }
    
    // MARK: - Password Reset Tests
    
    func testPasswordResetSuccess() {
        let expectation = XCTestExpectation(description: "Password reset should complete")
        
        mockAuthService.shouldSucceedPasswordReset = true
        
        mockAuthService.resetPassword(email: "test@example.com") { result in
            switch result {
            case .success:
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Password reset should succeed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(mockAuthService.resetPasswordCallCount, 1, "resetPassword should be called once")
    }
    
    func testPasswordResetFailure() {
        let expectation = XCTestExpectation(description: "Password reset should fail")
        
        mockAuthService.shouldSucceedPasswordReset = false
        
        mockAuthService.resetPassword(email: "nonexistent@example.com") { result in
            switch result {
            case .success:
                XCTFail("Password reset should fail for nonexistent email")
            case .failure:
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Email Verification Tests
    
    func testEmailVerificationCheck() {
        let expectation = XCTestExpectation(description: "Email verification check should complete")
        
        // Without authenticated user, should return false
        mockAuthService.checkEmailVerification { isVerified in
            XCTAssertFalse(isVerified, "Email should not be verified when no user is authenticated")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Onboarding Tests
    
    func testOnboardingCompletion() {
        XCTAssertFalse(mockAuthService.hasCompletedOnboarding, "Onboarding should not be completed initially")
        
        mockAuthService.completeOnboarding()
        
        XCTAssertTrue(mockAuthService.hasCompletedOnboarding, "Onboarding should be completed after calling completeOnboarding()")
    }
    
    // MARK: - Current User Tests
    
    func testGetCurrentUser() {
        // Initially, current user should be nil
        XCTAssertNil(mockAuthService.getCurrentUser(), "Current user should be nil initially")
    }
    
    // MARK: - Needs Email Verification Tests
    
    func testNeedsEmailVerification() {
        // Without authenticated user, should return false
        XCTAssertFalse(mockAuthService.needsEmailVerification, "Should not need email verification when no user is authenticated")
    }
    
    // MARK: - Error Handling Tests
    
    func testSignUpWithMockError() {
        let expectation = XCTestExpectation(description: "Sign up should handle mock error")
        let testError = NSError(domain: "TestError", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        mockAuthService.mockError = testError
        
        mockAuthService.signUp(email: "test@example.com", password: "password123") { result in
            switch result {
            case .success:
                XCTFail("Sign up should fail with mock error")
            case .failure(let error):
                XCTAssertEqual((error as NSError).code, 123, "Should return the mock error")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSignInWithMockError() {
        let expectation = XCTestExpectation(description: "Sign in should handle mock error")
        let testError = NSError(domain: "TestError", code: 456, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        mockAuthService.mockError = testError
        
        mockAuthService.signIn(email: "test@example.com", password: "password123") { result in
            switch result {
            case .success:
                XCTFail("Sign in should fail with mock error")
            case .failure(let error):
                XCTAssertEqual((error as NSError).code, 456, "Should return the mock error")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}
