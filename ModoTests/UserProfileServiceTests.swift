import XCTest
import Combine
@testable import Modo

/// Tests for UserProfileService
/// These tests verify user profile management
final class UserProfileServiceTests: XCTestCase {
    
    var service: UserProfileService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        service = UserProfileService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        service = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        XCTAssertNil(service.currentProfile, "Initial profile should be nil")
        XCTAssertNil(service.avatarName, "Initial avatar name should be nil")
        XCTAssertNil(service.profileImageURL, "Initial profile image URL should be nil")
        XCTAssertNil(service.username, "Initial username should be nil")
    }
    
    // MARK: - Update Profile Tests
    
    func testUpdateProfileFromArray() {
        let userId = "test-user-1"
        let profile1 = TestHelpers.createTestUserProfile(userId: userId)
        let profile2 = TestHelpers.createTestUserProfile(userId: "test-user-2")
        
        let profiles = [profile1, profile2]
        
        // Note: updateProfile requires Auth.auth().currentUser?.uid
        // Since we can't easily mock Firebase Auth in unit tests,
        // we test the setProfile method instead, which is more testable
        
        service.setProfile(profile1)
        
        XCTAssertNotNil(service.currentProfile, "Profile should be set")
        XCTAssertEqual(service.currentProfile?.userId, userId, "User ID should match")
    }
    
    func testSetProfile() {
        let profile = TestHelpers.createTestUserProfile(userId: "test-user-1")
        
        service.setProfile(profile)
        
        XCTAssertNotNil(service.currentProfile, "Profile should be set")
        XCTAssertEqual(service.currentProfile?.userId, "test-user-1", "User ID should match")
        XCTAssertEqual(service.currentProfile?.username, "testuser", "Username should match")
    }
    
    func testSetProfileNil() {
        let profile = TestHelpers.createTestUserProfile(userId: "test-user-1")
        
        // First set a profile
        service.setProfile(profile)
        XCTAssertNotNil(service.currentProfile, "Profile should be set")
        
        // Then set to nil
        service.setProfile(nil)
        XCTAssertNil(service.currentProfile, "Profile should be nil after setting to nil")
    }
    
    // MARK: - Convenience Properties Tests
    
    func testAvatarName() {
        let profile = TestHelpers.createTestUserProfile(userId: "test-user-1")
        profile.avatarName = "avatar-1"
        
        service.setProfile(profile)
        
        XCTAssertEqual(service.avatarName, "avatar-1", "Avatar name should match")
    }
    
    func testProfileImageURL() {
        let profile = TestHelpers.createTestUserProfile(userId: "test-user-1")
        profile.profileImageURL = "https://example.com/avatar.jpg"
        
        service.setProfile(profile)
        
        XCTAssertEqual(service.profileImageURL, "https://example.com/avatar.jpg", "Profile image URL should match")
    }
    
    func testUsername() {
        let profile = TestHelpers.createTestUserProfile(userId: "test-user-1")
        profile.username = "newusername"
        
        service.setProfile(profile)
        
        XCTAssertEqual(service.username, "newusername", "Username should match")
    }
    
    func testConveniencePropertiesWithNilProfile() {
        service.setProfile(nil)
        
        XCTAssertNil(service.avatarName, "Avatar name should be nil when profile is nil")
        XCTAssertNil(service.profileImageURL, "Profile image URL should be nil when profile is nil")
        XCTAssertNil(service.username, "Username should be nil when profile is nil")
    }
    
    // MARK: - Profile Updates Tests
    
    func testUpdateExistingProfile() {
        let profile1 = TestHelpers.createTestUserProfile(userId: "test-user-1")
        profile1.username = "username1"
        
        service.setProfile(profile1)
        XCTAssertEqual(service.username, "username1", "Username should be username1")
        
        // Update profile
        let profile2 = TestHelpers.createTestUserProfile(userId: "test-user-1")
        profile2.username = "username2"
        
        service.setProfile(profile2)
        XCTAssertEqual(service.username, "username2", "Username should be updated to username2")
    }
    
    // MARK: - Published Properties Tests
    
    func testCurrentProfilePublishedProperty() {
        let expectation = XCTestExpectation(description: "Profile should be published")
        let profile = TestHelpers.createTestUserProfile(userId: "test-user-1")
        
        // Observe changes
        service.$currentProfile
            .dropFirst() // Skip initial nil value
            .sink { profile in
                XCTAssertNotNil(profile, "Profile should be published")
                XCTAssertEqual(profile?.userId, "test-user-1", "User ID should match")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Set profile
        service.setProfile(profile)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCurrentProfilePublishedPropertyNil() {
        let expectation = XCTestExpectation(description: "Profile nil should be published")
        let profile = TestHelpers.createTestUserProfile(userId: "test-user-1")
        
        var valueCount = 0
        
        // Observe all changes
        service.$currentProfile
            .sink { profile in
                valueCount += 1
                if valueCount == 1 {
                    // Initial nil
                    XCTAssertNil(profile, "Initial profile should be nil")
                } else if valueCount == 2 {
                    // After setProfile(profile)
                    XCTAssertNotNil(profile, "Profile should be set")
                } else if valueCount == 3 {
                    // After setProfile(nil)
                    XCTAssertNil(profile, "Profile should be nil after setting to nil")
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // First set profile
        service.setProfile(profile)
        
        // Wait a bit for the sink to process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then set to nil
            self.service.setProfile(nil)
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
}

