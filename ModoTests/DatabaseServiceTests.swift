import XCTest
@testable import Modo

/// Tests for DatabaseService using MockDatabaseService
/// These tests verify database operations without requiring Firebase connection
final class DatabaseServiceTests: XCTestCase {
    
    var mockDatabaseService: MockDatabaseService!
    
    override func setUp() {
        super.setUp()
        mockDatabaseService = MockDatabaseService()
    }
    
    override func tearDown() {
        mockDatabaseService.reset()
        mockDatabaseService = nil
        super.tearDown()
    }
    
    // MARK: - User Profile Tests
    
    func testSaveUserProfile() {
        let expectation = XCTestExpectation(description: "Save user profile should complete")
        let profile = TestHelpers.createTestUserProfile(userId: "test-user-1")
        
        mockDatabaseService.saveUserProfile(profile) { result in
            TestHelpers.assertSuccess(result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(mockDatabaseService.saveUserProfileCallCount, 1, "saveUserProfile should be called once")
    }
    
    func testSaveUserProfileFailure() {
        let expectation = XCTestExpectation(description: "Save user profile should fail")
        let profile = TestHelpers.createTestUserProfile(userId: "test-user-1")
        
        mockDatabaseService.shouldSucceed = false
        mockDatabaseService.saveUserProfile(profile) { result in
            TestHelpers.assertFailure(result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFetchUserProfile() {
        let expectation = XCTestExpectation(description: "Fetch user profile should complete")
        let profile = TestHelpers.createTestUserProfile(userId: "test-user-1")
        
        // First save the profile
        mockDatabaseService.saveUserProfile(profile) { _ in
            // Then fetch it
            self.mockDatabaseService.fetchUserProfile(userId: "test-user-1") { result in
                let fetchedProfile = TestHelpers.assertSuccessValue(result)
                XCTAssertNotNil(fetchedProfile, "Fetched profile should not be nil")
                XCTAssertEqual(fetchedProfile?.userId, "test-user-1", "User ID should match")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(mockDatabaseService.fetchUserProfileCallCount, 1, "fetchUserProfile should be called once")
    }
    
    func testFetchUserProfileNotFound() {
        let expectation = XCTestExpectation(description: "Fetch non-existent profile should fail")
        
        mockDatabaseService.fetchUserProfile(userId: "nonexistent-user") { result in
            TestHelpers.assertFailure(result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateUsername() {
        let expectation = XCTestExpectation(description: "Update username should complete")
        
        mockDatabaseService.updateUsername(userId: "test-user-1", username: "newusername") { result in
            TestHelpers.assertSuccess(result)
            
            // Verify username was updated
            self.mockDatabaseService.fetchUsername(userId: "test-user-1") { fetchResult in
                let username = TestHelpers.assertSuccessValue(fetchResult)
                XCTAssertEqual(username, "newusername", "Username should be updated")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Task Tests
    
    func testSaveTask() {
        let expectation = XCTestExpectation(description: "Save task should complete")
        let task = TestHelpers.createTestTaskItem(title: "Test Task")
        let date = Date()
        
        mockDatabaseService.saveTask(userId: "test-user-1", task: task, date: date) { result in
            TestHelpers.assertSuccess(result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(mockDatabaseService.saveTaskCallCount, 1, "saveTask should be called once")
    }
    
    func testDeleteTask() {
        let expectation = XCTestExpectation(description: "Delete task should complete")
        let task = TestHelpers.createTestTaskItem(title: "Test Task")
        let date = Date()
        
        // First save the task
        mockDatabaseService.saveTask(userId: "test-user-1", task: task, date: date) { _ in
            // Then delete it
            self.mockDatabaseService.deleteTask(userId: "test-user-1", taskId: task.id, date: date) { result in
                TestHelpers.assertSuccess(result)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(mockDatabaseService.deleteTaskCallCount, 1, "deleteTask should be called once")
    }
    
    func testFetchTasksForDate() {
        let expectation = XCTestExpectation(description: "Fetch tasks should complete")
        let task1 = TestHelpers.createTestTaskItem(title: "Task 1")
        let task2 = TestHelpers.createTestTaskItem(title: "Task 2")
        let date = Date()
        
        // Save multiple tasks
        mockDatabaseService.saveTask(userId: "test-user-1", task: task1, date: date) { _ in
            self.mockDatabaseService.saveTask(userId: "test-user-1", task: task2, date: date) { _ in
                // Fetch tasks for the date
                self.mockDatabaseService.fetchTasksForDate(userId: "test-user-1", date: date) { result in
                    let tasks = TestHelpers.assertSuccessValue(result)
                    XCTAssertNotNil(tasks, "Tasks should not be nil")
                    XCTAssertEqual(tasks?.count, 2, "Should fetch 2 tasks")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(mockDatabaseService.fetchTasksCallCount, 1, "fetchTasksForDate should be called once")
    }
    
    func testDeleteAllTasks() {
        let expectation = XCTestExpectation(description: "Delete all tasks should complete")
        let task = TestHelpers.createTestTaskItem(title: "Test Task")
        let date = Date()
        
        // Save a task
        mockDatabaseService.saveTask(userId: "test-user-1", task: task, date: date) { _ in
            // Delete all tasks
            self.mockDatabaseService.deleteAllTasks(userId: "test-user-1") { result in
                TestHelpers.assertSuccess(result)
                
                // Verify tasks are deleted
                self.mockDatabaseService.fetchTasksForDate(userId: "test-user-1", date: date) { fetchResult in
                    let tasks = TestHelpers.assertSuccessValue(fetchResult)
                    XCTAssertEqual(tasks?.count, 0, "All tasks should be deleted")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Daily Completion Tests
    
    func testSaveDailyCompletion() {
        let expectation = XCTestExpectation(description: "Save daily completion should complete")
        let date = Date()
        
        mockDatabaseService.saveDailyCompletion(userId: "test-user-1", date: date, isCompleted: true) { result in
            TestHelpers.assertSuccess(result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFetchDailyCompletion() {
        let expectation = XCTestExpectation(description: "Fetch daily completion should complete")
        let date = Date()
        
        // First save completion
        mockDatabaseService.saveDailyCompletion(userId: "test-user-1", date: date, isCompleted: true) { _ in
            // Then fetch it
            self.mockDatabaseService.fetchDailyCompletion(userId: "test-user-1", date: date) { result in
                let isCompleted = TestHelpers.assertSuccessValue(result)
                XCTAssertEqual(isCompleted, true, "Completion status should match")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFetchDailyCompletionsRange() {
        let expectation = XCTestExpectation(description: "Fetch daily completions range should complete")
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .day, value: 2, to: startDate)!
        
        // Save completions for multiple dates
        mockDatabaseService.saveDailyCompletion(userId: "test-user-1", date: startDate, isCompleted: true) { _ in
            self.mockDatabaseService.saveDailyCompletion(userId: "test-user-1", date: endDate, isCompleted: false) { _ in
                // Fetch range
                self.mockDatabaseService.fetchDailyCompletions(userId: "test-user-1", startDate: startDate, endDate: endDate) { result in
                    let completions = TestHelpers.assertSuccessValue(result)
                    XCTAssertNotNil(completions, "Completions should not be nil")
                    XCTAssertEqual(completions?.count, 3, "Should fetch 3 days (start, middle, end)")
                    XCTAssertEqual(completions?[startDate], true, "Start date should be completed")
                    XCTAssertEqual(completions?[endDate], false, "End date should not be completed")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Daily Challenge Tests
    
    func testSaveDailyChallenge() {
        let expectation = XCTestExpectation(description: "Save daily challenge should complete")
        let challenge = TestHelpers.createTestDailyChallenge()
        let date = Date()
        
        mockDatabaseService.saveDailyChallenge(
            userId: "test-user-1",
            challenge: challenge,
            date: date,
            isCompleted: false,
            isLocked: false,
            completedAt: nil,
            taskId: nil
        ) { result in
            TestHelpers.assertSuccess(result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFetchDailyChallenge() {
        let expectation = XCTestExpectation(description: "Fetch daily challenge should complete")
        let challenge = TestHelpers.createTestDailyChallenge()
        let date = Date()
        
        // First save the challenge
        mockDatabaseService.saveDailyChallenge(
            userId: "test-user-1",
            challenge: challenge,
            date: date,
            isCompleted: false,
            isLocked: false,
            completedAt: nil,
            taskId: nil
        ) { _ in
            // Then fetch it
            self.mockDatabaseService.fetchDailyChallenge(userId: "test-user-1", date: date) { result in
                let challengeData = TestHelpers.assertSuccessValue(result)
                XCTAssertNotNil(challengeData, "Challenge data should not be nil")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateDailyChallengeCompletion() {
        let expectation = XCTestExpectation(description: "Update daily challenge completion should complete")
        let challenge = TestHelpers.createTestDailyChallenge()
        let date = Date()
        
        // First save the challenge
        mockDatabaseService.saveDailyChallenge(
            userId: "test-user-1",
            challenge: challenge,
            date: date,
            isCompleted: false,
            isLocked: false,
            completedAt: nil,
            taskId: nil
        ) { _ in
            // Update completion
            self.mockDatabaseService.updateDailyChallengeCompletion(
                userId: "test-user-1",
                date: date,
                isCompleted: true,
                isLocked: false,
                completedAt: Date()
            ) { result in
                TestHelpers.assertSuccess(result)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateDailyChallengeTaskId() {
        let expectation = XCTestExpectation(description: "Update daily challenge task ID should complete")
        let challenge = TestHelpers.createTestDailyChallenge()
        let taskId = UUID()
        let date = Date()
        
        // First save the challenge
        mockDatabaseService.saveDailyChallenge(
            userId: "test-user-1",
            challenge: challenge,
            date: date,
            isCompleted: false,
            isLocked: false,
            completedAt: nil,
            taskId: nil
        ) { _ in
            // Update task ID
            self.mockDatabaseService.updateDailyChallengeTaskId(
                userId: "test-user-1",
                date: date,
                taskId: taskId
            ) { result in
                TestHelpers.assertSuccess(result)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testSaveTaskWithError() {
        let expectation = XCTestExpectation(description: "Save task should handle error")
        let task = TestHelpers.createTestTaskItem()
        let testError = NSError(domain: "TestError", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        mockDatabaseService.mockError = testError
        mockDatabaseService.saveTask(userId: "test-user-1", task: task, date: Date()) { result in
            switch result {
            case .success:
                XCTFail("Save should fail with mock error")
            case .failure(let error):
                XCTAssertEqual((error as NSError).code, 123, "Should return the mock error")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}

