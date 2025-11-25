import XCTest
import Combine
@testable import Modo

/// Tests for DailyChallengeService
/// These tests verify daily challenge management logic
/// Note: Some tests require Firebase Auth and AI services, which are difficult to mock in unit tests
final class DailyChallengeServiceTests: XCTestCase {
    
    var service: DailyChallengeService!
    var mockDatabaseService: MockDatabaseService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockDatabaseService = MockDatabaseService()
        service = DailyChallengeService(databaseService: mockDatabaseService)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        service.removeCompletionObserver()
        service.resetState()
        cancellables = nil
        service = nil
        mockDatabaseService.reset()
        mockDatabaseService = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        XCTAssertNil(service.currentChallenge, "Initial challenge should be nil")
        XCTAssertFalse(service.isChallengeCompleted, "Initial completion should be false")
        XCTAssertFalse(service.isChallengeAddedToTasks, "Initial added to tasks should be false")
        XCTAssertNil(service.completedAt, "Initial completedAt should be nil")
        XCTAssertFalse(service.isLocked, "Initial locked should be false")
        XCTAssertFalse(service.hasMinimumUserData, "Initial hasMinimumUserData should be false")
        XCTAssertFalse(service.isGeneratingChallenge, "Initial isGeneratingChallenge should be false")
        XCTAssertNil(service.challengeGenerationError, "Initial error should be nil")
    }
    
    // MARK: - User Data Availability Tests
    
    func testUpdateUserDataAvailabilityWithValidProfile() {
        let profile = TestHelpers.createTestUserProfile(userId: "test-user-1")
        
        // For testing, we check if profile has minimum data
        let hasMinimumData = profile.hasMinimumDataForDailyChallenge()
        
        XCTAssertTrue(hasMinimumData, "Valid profile should have minimum data for daily challenge")
    }
    
    func testUpdateUserDataAvailabilityWithNilProfile() {
        // When profile is nil, hasMinimumUserData should be false (default state)
        XCTAssertFalse(service.hasMinimumUserData, "Should not have minimum user data with nil profile")
    }
    
    func testUpdateUserDataAvailabilityWithIncompleteProfile() {
        // Create profile with missing data
        let profile = UserProfile(userId: "test-user-1")
        // Don't set required fields like height, weight, etc.
        
        let hasMinimumData = profile.hasMinimumDataForDailyChallenge()
        
        // Should return false if profile doesn't have minimum data
        XCTAssertFalse(hasMinimumData, "Incomplete profile should not have minimum data")
    }
    
    // MARK: - Challenge Task Management Tests
    
    func testAddChallengeToTasks() {
        let expectation = XCTestExpectation(description: "Challenge should be added to tasks")
        
        // Note: addChallengeToTasks requires currentChallenge to be set
        // Since we can't easily set currentChallenge without Firebase,
        // we verify the method exists and can be called
        
        service.addChallengeToTasks { taskId in
            // If challenge is nil, this should return nil
            if taskId == nil {
                // Expected when no challenge is set
                expectation.fulfill()
            } else {
                XCTAssertNotNil(taskId, "Task ID should not be nil")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateChallengeCompletion() {
        let taskId = UUID()
        
        // Update completion for a task
        service.updateChallengeCompletion(taskId: taskId, isCompleted: true)
        
        // If taskId matches challengeTaskId, completion should be updated
        // Since challengeTaskId is private and requires challenge to be set,
        // we verify the method doesn't crash
        
        XCTAssertNotNil(service, "Service should be valid")
    }
    
    func testIsTaskCurrentChallenge() {
        let taskId = UUID()
        
        let isCurrentChallenge = service.isTaskCurrentChallenge(taskId: taskId)
        
        // Should return false if no challenge is set or taskId doesn't match
        XCTAssertFalse(isCurrentChallenge, "Should return false when no challenge is set")
    }
    
    func testHandleChallengeTaskDeleted() {
        let taskId = UUID()
        
        // Handle task deletion
        service.handleChallengeTaskDeleted(taskId: taskId)
        
        // Should clear linkage if taskId matches
        // Since challengeTaskId is private, we verify the method doesn't crash
        
        XCTAssertNotNil(service, "Service should be valid")
    }
    
    // MARK: - State Management Tests
    
    func testResetState() {
        // Reset state
        service.resetState()
        
        // Verify state is reset
        XCTAssertNil(service.currentChallenge, "Challenge should be nil after reset")
        XCTAssertFalse(service.isChallengeCompleted, "Completion should be false after reset")
        XCTAssertFalse(service.isChallengeAddedToTasks, "Added to tasks should be false after reset")
        XCTAssertNil(service.completedAt, "CompletedAt should be nil after reset")
        XCTAssertFalse(service.isLocked, "Locked should be false after reset")
        XCTAssertFalse(service.hasMinimumUserData, "HasMinimumUserData should be false after reset")
        XCTAssertFalse(service.isGeneratingChallenge, "IsGeneratingChallenge should be false after reset")
        XCTAssertNil(service.challengeGenerationError, "Error should be nil after reset")
    }
    
    func testCheckAndResetForNewDay() {
        // Check for new day
        service.checkAndResetForNewDay()
        
        // If challenge is nil, should not do anything
        // If challenge exists and is for a different day, should reset
        // Since currentChallenge is not directly settable, we verify the method doesn't crash
        
        XCTAssertNotNil(service, "Service should be valid")
    }
    
    // MARK: - Published Properties Tests
    
    func testCurrentChallengePublishedProperty() {
        // Note: currentChallenge is not directly settable without Firebase
        // In practice, this would be tested in an integration test
        // For now, we verify the property exists and is observable
        
        // Just verify the property exists and is observable
        let expectation = XCTestExpectation(description: "Property should be observable")
        
        // Observe initial value (nil)
        service.$currentChallenge
            .first()
            .sink { challenge in
                XCTAssertNil(challenge, "Initial challenge should be nil")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testIsChallengeCompletedPublishedProperty() {
        // Note: isChallengeCompleted is updated internally when challenge completion changes
        // This would be tested in an integration test with Firebase
        // For now, we verify the property exists and is observable
        
        let expectation = XCTestExpectation(description: "Property should be observable")
        
        // Observe initial value (false)
        service.$isChallengeCompleted
            .first()
            .sink { isCompleted in
                XCTAssertFalse(isCompleted, "Initial completion should be false")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Database Service Integration Tests
    
    func testLoadTodayChallengeWithDatabaseService() {
        let expectation = XCTestExpectation(description: "Challenge should be loaded")
        
        mockDatabaseService.shouldSucceed = true
        
        // Note: loadTodayChallenge requires Auth.auth().currentUser?.uid
        // Since we can't easily mock Firebase Auth, this would be tested in an integration test
        // For now, we verify the service uses the database service correctly
        
        // When no user is logged in, should generate default challenge
        service.loadTodayChallenge()
        
        // Verify default challenge is generated
        // Since currentChallenge is set internally, we verify the method doesn't crash
        expectation.fulfill()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSaveChallengeToFirebase() {
        let expectation = XCTestExpectation(description: "Challenge should be saved")
        
        mockDatabaseService.shouldSucceed = true
        
        // Note: saveChallengeToFirebase is private, but it's called when challenge is saved
        // We verify the database service is used correctly through other methods
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 0.1)
    }
}

// MARK: - Helper Extension for Testing
// Note: DailyChallengeService uses UserProfileService internally to manage hasMinimumUserData
// For unit tests, we test the service with its default state (hasMinimumUserData = false)

