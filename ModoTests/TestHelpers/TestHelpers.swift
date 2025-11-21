import Foundation
import XCTest
@testable import Modo

/// Test helper utilities for creating test data and common test operations
enum TestHelpers {
    /// Creates a test UserProfile with default values
    static func createTestUserProfile(
        userId: String = "test-user-id"
    ) -> UserProfile {
        let profile = UserProfile(userId: userId)
        profile.username = "testuser"
        profile.heightValue = 70
        profile.heightUnit = "in"
        profile.weightValue = 150
        profile.weightUnit = "lb"
        profile.age = 25
        profile.gender = "male"
        profile.lifestyle = "moderate"
        profile.goal = "lose_weight"
        profile.targetWeightLossValue = 10
        profile.targetWeightLossUnit = "lb"
        profile.targetDays = 30
        return profile
    }
    
    /// Creates a test TaskItem with default values
    static func createTestTaskItem(
        id: UUID = UUID(),
        title: String = "Test Task",
        subtitle: String = "Test Subtitle",
        category: TaskCategory = .fitness,
        isDone: Bool = false,
        timeDate: Date? = nil
    ) -> TaskItem {
        let now = Date()
        let taskTimeDate = timeDate ?? now
        return TaskItem(
            id: id,
            title: title,
            subtitle: subtitle,
            time: "10:00 AM",
            timeDate: taskTimeDate,
            endTime: nil,
            meta: "Test meta",
            isDone: isDone,
            emphasisHex: "#FF0000",
            category: category,
            dietEntries: [],
            fitnessEntries: [],
            createdAt: now,
            updatedAt: now
        )
    }
    
    /// Creates a test DailyChallenge with default values
    static func createTestDailyChallenge(
        id: UUID = UUID(),
        title: String = "Test Challenge",
        subtitle: String = "Test Subtitle",
        emoji: String = "🏃",
        type: DailyChallenge.ChallengeType = .fitness,
        targetValue: Int = 30,
        date: Date = Date()
    ) -> DailyChallenge {
        return DailyChallenge(
            id: id,
            title: title,
            subtitle: subtitle,
            emoji: emoji,
            type: type,
            targetValue: targetValue,
            date: date
        )
    }
    
    /// Waits for an expectation with a timeout
    static func waitForExpectation(
        _ expectation: XCTestExpectation,
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        if result != .completed {
            XCTFail("Expectation not fulfilled within \(timeout) seconds", file: file, line: line)
        }
    }
    
    /// Asserts that a Result is a success
    static func assertSuccess<T>(
        _ result: Result<T, Error>,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)", file: file, line: line)
        }
    }
    
    /// Asserts that a Result is a failure
    static func assertFailure<T>(
        _ result: Result<T, Error>,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        switch result {
        case .success:
            XCTFail("Expected failure but got success", file: file, line: line)
        case .failure:
            break
        }
    }
    
    /// Asserts that a Result is a success and returns the value
    static func assertSuccessValue<T>(
        _ result: Result<T, Error>,
        file: StaticString = #file,
        line: UInt = #line
    ) -> T? {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)", file: file, line: line)
            return nil
        }
    }
}

