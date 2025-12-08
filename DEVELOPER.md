# Modo iOS App - Developer Documentation

This document provides comprehensive guidelines for developers who want to contribute to the Modo iOS application. It covers project setup, architecture, testing, CI/CD, and contribution guidelines.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Project Structure](#project-structure)
3. [Architecture Overview](#architecture-overview)
4. [Building the Software](#building-the-software)
5. [Testing](#testing)
6. [Adding New Tests](#adding-new-tests)
7. [Continuous Integration](#continuous-integration)
8. [Building a Release](#building-a-release)
9. [Code Style Guidelines](#code-style-guidelines)
10. [Contributing](#contributing)

## Getting Started

### Prerequisites

- **macOS**: macOS 12.0 (Monterey) or later
- **Xcode**: Version 14.0 or later
- **iOS Deployment Target**: iOS 15.0+
- **Swift**: Version 5.7+
- **Git**: For version control
- **Firebase CLI** (optional): For backend function development
- **Node.js** (optional): Required if working with Firebase functions

### Obtaining the Source Code

1. **Clone the Repository**

   ```bash
   git clone https://github.com/your-username/Modo.git
   cd Modo
   ```

2. **Verify Dependencies**

   - The project uses Swift Package Manager for dependencies
   - Dependencies are automatically resolved when opening the project in Xcode
   - No additional manual setup required for Firebase or Google Sign-In

3. **Open the Project**

   ```bash
   open Modo.xcodeproj
   ```

4. **Initial Build**
   - Select your target device or simulator in Xcode
   - Press `Cmd + B` to build the project
   - Xcode will automatically fetch and resolve all Swift Package Manager dependencies

### Dependencies

The project uses the following Swift Package Manager dependencies:

- **Firebase iOS SDK** (v12.4.0): Authentication, Realtime Database, and analytics
- **Google Sign-In iOS** (v9.0.0): Social authentication
- **SwiftData**: Local data persistence and caching
- **SwiftUI**: Modern declarative UI framework

## Project Structure

```
Modo/
├── .github/
│   └── workflows/
│       └── main.yml                    # CI/CD configuration
├── Modo/                               # Main app target
│   ├── ModoApp.swift                   # App entry point and configuration
│   ├── AppDelegate.swift               # App lifecycle management
│   ├── Info.plist                      # App configuration
│   ├── Modo.entitlements               # App capabilities
│   ├── Assets.xcassets/               # App icons, images, and colors
│   ├── Constants/                      # App-wide constants and configuration
│   ├── DependencyInjection/           # Dependency injection container
│   ├── Errors/                        # Custom error types
│   ├── Models/                        # Data models and entities
│   ├── Protocols/                     # Protocol definitions
│   ├── Repositories/                  # Data access layer
│   ├── Resources/                     # Additional resources (configs, assets)
│   ├── Services/                      # Business logic and service layer
│   │   ├── AuthService.swift         # Authentication management
│   │   ├── DatabaseService.swift     # Firebase database operations
│   │   ├── TaskService.swift         # Task management
│   │   ├── TaskCacheService.swift    # Task caching layer
│   │   ├── UserProfileService.swift  # User profile management
│   │   ├── DailyCaloriesService.swift # Calorie tracking
│   │   ├── DailyChallengeService.swift # Daily challenge logic
│   │   ├── DayCompletionService.swift # Day completion tracking
│   │   ├── ProgressCalculationService.swift # Progress metrics
│   │   ├── HealthCalculator.swift    # Health-related calculations
│   │   └── AIService/                # AI integration services
│   ├── UI/                           # User interface components
│   │   ├── AuthenticatedView.swift   # Main authenticated app container
│   │   ├── Components/               # Reusable UI components
│   │   │   ├── Branding/            # Logo and branding
│   │   │   ├── Buttons/             # Custom buttons
│   │   │   ├── Core/                # Core utilities and extensions
│   │   │   ├── Feedback/            # Toast notifications
│   │   │   ├── Icons/               # Custom icons
│   │   │   ├── Inputs/              # Form inputs
│   │   │   ├── Navigation/          # Navigation components
│   │   │   └── Profile/             # Profile components
│   │   ├── InfoGatheringPages/      # Onboarding flow
│   │   ├── MainPages/               # Core app screens
│   │   ├── ProfileSubPages/         # Profile-related screens
│   │   └── RegisterLoginPages/      # Authentication screens
│   └── ViewModels/                  # View models for MVVM architecture
├── ModoTests/                       # Unit tests
│   ├── Mocks/                       # Mock objects for testing
│   ├── TestHelpers/                 # Testing utilities
│   ├── AuthServiceTests.swift       # Authentication tests
│   ├── DatabaseServiceTests.swift   # Database operation tests
│   ├── TaskServiceTests.swift       # Task management tests
│   ├── TaskCacheServiceTests.swift  # Cache layer tests
│   ├── UserProfileServiceTests.swift # Profile management tests
│   ├── DailyCaloriesServiceTests.swift
│   ├── DailyChallengeServiceTests.swift
│   ├── DayCompletionServiceTests.swift
│   ├── ProgressCalculationServiceTests.swift
│   ├── HealthCalculatorTests.swift
│   ├── StringValidationTests.swift
│   ├── AIServiceUtilsTests.swift
│   └── AIInfrastructureIntegrationTests.swift
├── ModoUITests/                    # UI automation tests
├── modo-firebase-functions/        # Backend Firebase functions
│   ├── functions/                  # Cloud function implementations
│   ├── .firebaserc                 # Firebase project configuration
│   ├── firebase.json               # Firebase hosting/functions config
│   ├── database.rules.json         # Database security rules
│   └── storage.rules               # Storage security rules
├── Modo.xcodeproj/                # Xcode project configuration
├── .gitignore                     # Git ignore rules
└── README.md                      # Project overview
```

### Key Directories Explained

#### Core Application (`Modo/`)

- **`Constants/`**: Centralized constants for URLs, API keys, configuration values
- **`DependencyInjection/`**: Service locator and dependency injection setup
- **`Errors/`**: Custom error types and error handling utilities
- **`Models/`**: Data models representing entities like User, Task, Profile, etc.
- **`Protocols/`**: Protocol definitions for dependency injection and abstraction
- **`Repositories/`**: Data access layer abstracting Firebase and local storage
- **`Services/`**: Business logic layer containing all service implementations
- **`UI/`**: All SwiftUI views organized by feature
- **`ViewModels/`**: MVVM view models managing view state and business logic

#### Testing (`ModoTests/`)

- **`Mocks/`**: Mock implementations of services and repositories for testing
- **`TestHelpers/`**: Shared testing utilities and helper functions
- **Individual test files**: One test file per service/component being tested

#### Backend (`modo-firebase-functions/`)

- **`functions/`**: Node.js cloud functions for server-side logic
- **Configuration files**: Firebase project setup and security rules

## Architecture Overview

### Design Patterns

The app follows a clean architecture approach with these key patterns:

1. **MVVM (Model-View-ViewModel)**

   - SwiftUI views observe view models via `@ObservableObject`
   - View models contain presentation logic and state management
   - Views remain passive and declarative

2. **Repository Pattern**

   - Repositories abstract data sources (Firebase, local storage)
   - Services interact with repositories, not directly with data sources
   - Enables easy testing and data source swapping

3. **Service Layer Pattern**

   - Business logic centralized in service classes
   - Each service has a single responsibility
   - Services are injected via dependency injection

4. **Dependency Injection**
   - Services injected via `@EnvironmentObject` or initializer injection
   - Facilitates testing with mock implementations
   - Reduces coupling between components

### Key Components

#### Services Layer

**Authentication (`AuthService.swift`)**

- Manages user authentication state
- Handles email/password and Google Sign-In flows
- Provides authentication state to the entire app
- Singleton pattern for global access

**Database (`DatabaseService.swift`)**

- Firebase Realtime Database operations
- CRUD operations for all data entities
- Real-time data synchronization

**Task Management (`TaskService.swift` & `TaskCacheService.swift`)**

- Task creation, updating, and deletion
- Local caching layer for offline support
- Task prioritization and scheduling

**User Profile (`UserProfileService.swift`)**

- Profile data management
- User preferences and settings
- Profile picture handling

**Health & Progress Services**

- `DailyCaloriesService`: Calorie tracking and calculations
- `DailyChallengeService`: Daily challenge generation and tracking
- `DayCompletionService`: Day completion tracking and streaks
- `ProgressCalculationService`: Progress metrics and analytics
- `HealthCalculator`: BMI, BMR, TDEE calculations

**AI Integration (`AIService/`)**

- AI-powered features and recommendations
- Natural language processing
- Smart task suggestions

#### Data Flow Architecture

```
View → ViewModel → Service → Repository → Data Source (Firebase/Local)
  ↑                   ↓
  └─── Updates ───────┘
```

1. **View** displays data and captures user input
2. **ViewModel** manages view state and coordinates with services
3. **Service** implements business logic and rules
4. **Repository** abstracts data access
5. **Data Source** stores data (Firebase Realtime Database or local cache)

### State Management

- **`@State`**: Local view state
- **`@Binding`**: Two-way data flow between parent and child views
- **`@ObservedObject`**: External reference types that views observe
- **`@EnvironmentObject`**: Shared objects passed down the view hierarchy
- **`@Published`**: Properties that trigger view updates when changed

## Building the Software

### Development Build

1. **Open Xcode**

   ```bash
   open Modo.xcodeproj
   ```

2. **Select Target**

   - Choose your target: `Modo` (main app)
   - Select iOS Simulator (iPhone 15 recommended) or connected physical device
   - Ensure deployment target is iOS 15.0 or later

3. **Build the Project**

   ```bash
   # Build only (without running)
   xcodebuild build -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15'

   # Or use Xcode: Press Cmd + B
   ```

4. **Run the App**
   - Press `Cmd + R` in Xcode, or
   - Click the Play button in the toolbar
   - The app will launch on your selected simulator/device

### Build Configurations

#### Debug Configuration (Default)

- **Optimization**: None (`-Onone`)
- **Debug Symbols**: Full (`-g`)
- **Assertions**: Enabled
- **Logging**: Verbose
- **Swift Compilation**: Incremental (faster builds)
- **Use Case**: Development, debugging, testing

#### Release Configuration

- **Optimization**: Speed (`-O`)
- **Debug Symbols**: None
- **Assertions**: Disabled
- **Logging**: Minimal
- **Swift Compilation**: Whole Module (smaller binary)
- **Use Case**: App Store distribution, performance testing

### Troubleshooting Build Issues

**Issue: Swift Package Dependencies Fail to Resolve**

```bash
# Solution: Reset package cache
File → Packages → Reset Package Caches

# Or via command line:
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/Developer/Xcode/DerivedData
```

**Issue: Code Signing Errors**

- Ensure you have a valid Apple Developer account
- Check Team selection in project settings
- Verify provisioning profiles are up to date

**Issue: Firebase Configuration Missing**

- Ensure `GoogleService-Info.plist` is present in the project
- Verify the file is added to the Modo target

## Testing

### Running Tests

#### Quick Test Commands

```bash
# Run ALL tests (unit + UI)
xcodebuild test -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15'

# Run ONLY unit tests
xcodebuild test -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ModoTests

# Run ONLY UI tests
xcodebuild test -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ModoUITests

# Run a specific test class
xcodebuild test -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ModoTests/AuthServiceTests

# Run a specific test method
xcodebuild test -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ModoTests/AuthServiceTests/testEmailValidation
```

#### Running Tests in Xcode

1. **Run All Tests**: Press `Cmd + U`
2. **Run Specific Test Suite**:
   - Open Test Navigator (`Cmd + 6`)
   - Click the play button next to the test suite name
3. **Run Single Test**: Click the diamond icon next to the test method
4. **Run Tests on Specific Line**: Click in the gutter next to any test

### Test Structure

The project includes comprehensive test coverage across multiple layers:

#### Unit Tests (`ModoTests/`)

Tests are organized by the component they test:

- **Service Tests**: Test business logic in isolation

  - `AuthServiceTests.swift`: Authentication flows, validation
  - `DatabaseServiceTests.swift`: Database operations
  - `TaskServiceTests.swift`: Task management logic
  - `TaskCacheServiceTests.swift`: Caching behavior
  - `UserProfileServiceTests.swift`: Profile management
  - `DailyCaloriesServiceTests.swift`: Calorie calculations
  - `DailyChallengeServiceTests.swift`: Challenge logic
  - `DayCompletionServiceTests.swift`: Completion tracking
  - `ProgressCalculationServiceTests.swift`: Progress metrics

- **Utility Tests**: Test helper functions and utilities

  - `StringValidationTests.swift`: Input validation
  - `HealthCalculatorTests.swift`: Health calculations
  - `AIServiceUtilsTests.swift`: AI utility functions

- **Integration Tests**: Test component interactions
  - `AIInfrastructureIntegrationTests.swift`: AI system integration

#### UI Tests (`ModoUITests/`)

- **`ModoUITests.swift`**: End-to-end UI automation tests
- **`ModoUITestsLaunchTests.swift`**: App launch performance tests

#### Test Helpers (`ModoTests/TestHelpers/` & `ModoTests/Mocks/`)

- **Mocks**: Mock implementations of services for isolated testing
- **Helpers**: Shared utilities for test setup and assertions

### Test Coverage Areas

Current test coverage includes:

- ✅ Authentication (email/password, Google Sign-In, verification)
- ✅ Input validation (email, password, height, weight, age)
- ✅ Database operations (CRUD, real-time updates)
- ✅ Task management (creation, updates, prioritization)
- ✅ Caching layer (storage, retrieval, invalidation)
- ✅ Health calculations (BMI, BMR, TDEE)
- ✅ Progress tracking (streaks, completion rates)
- ✅ AI service utilities
- ✅ Performance benchmarks

## Adding New Tests

### Step-by-Step Guide

#### 1. Determine Test Type

- **Unit Test**: Testing a single component in isolation → Add to `ModoTests/`
- **UI Test**: Testing user interface behavior → Add to `ModoUITests/`
- **Integration Test**: Testing multiple components together → Add to `ModoTests/`

#### 2. Create Test File

**For a new service test:**

1. Right-click on `ModoTests/` in Xcode
2. Select **New File** → **Unit Test Case Class**
3. Name it `[ServiceName]Tests.swift` (e.g., `NotificationServiceTests.swift`)
4. Ensure it's added to the `ModoTests` target

#### 3. Set Up Test Class Structure

```swift
import XCTest
@testable import Modo

final class NotificationServiceTests: XCTestCase {

    // MARK: - Properties

    var sut: NotificationService!  // System Under Test
    var mockDatabase: MockDatabaseService!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create mock dependencies
        mockDatabase = MockDatabaseService()

        // Initialize the system under test
        sut = NotificationService(database: mockDatabase)
    }

    override func tearDownWithError() throws {
        // Clean up
        sut = nil
        mockDatabase = nil

        try super.tearDownWithError()
    }

    // MARK: - Tests

    func testNotificationScheduling() throws {
        // Test implementation here
    }
}
```

#### 4. Write Test Methods

Follow the **Given-When-Then** pattern:

```swift
func testScheduleNotificationCreatesNotificationSuccessfully() throws {
    // GIVEN: A valid notification request
    let title = "Daily Reminder"
    let body = "Complete your daily tasks"
    let scheduledDate = Date().addingTimeInterval(3600)

    // WHEN: We schedule the notification
    let result = try sut.scheduleNotification(
        title: title,
        body: body,
        date: scheduledDate
    )

    // THEN: The notification is created successfully
    XCTAssertTrue(result.isSuccess)
    XCTAssertEqual(mockDatabase.createCallCount, 1)
    XCTAssertEqual(sut.scheduledNotifications.count, 1)
}

func testScheduleNotificationWithPastDateThrowsError() throws {
    // GIVEN: A date in the past
    let pastDate = Date().addingTimeInterval(-3600)

    // WHEN/THEN: Scheduling should throw an error
    XCTAssertThrowsError(
        try sut.scheduleNotification(
            title: "Test",
            body: "Test",
            date: pastDate
        )
    ) { error in
        XCTAssertEqual(error as? NotificationError, .invalidDate)
    }
}
```

#### 5. Test Edge Cases

Always test:

- ✅ **Success path**: Normal expected behavior
- ✅ **Failure paths**: Error conditions
- ✅ **Edge cases**: Boundary values, empty inputs, nil values
- ✅ **Invalid inputs**: Malformed data, out-of-range values

```swift
func testEdgeCases() throws {
    // Empty strings
    XCTAssertThrowsError(try sut.process(""))

    // Nil values
    XCTAssertNil(sut.getOptionalValue())

    // Maximum values
    let maxResult = try sut.calculate(Int.max)
    XCTAssertNotNil(maxResult)

    // Minimum values
    let minResult = try sut.calculate(0)
    XCTAssertEqual(minResult, expectedMinimum)
}
```

#### 6. Add Performance Tests (When Needed)

For computationally intensive operations:

```swift
func testCalculationPerformance() throws {
    let input = generateLargeDataSet()

    measure {
        // This block will be executed 10 times
        _ = sut.performComplexCalculation(input)
    }

    // Xcode will report average execution time
}
```

#### 7. Create Mocks (If Needed)

If your test requires mock dependencies, add them to `ModoTests/Mocks/`:

```swift
// File: ModoTests/Mocks/MockNotificationManager.swift

import Foundation
@testable import Modo

final class MockNotificationManager: NotificationManagerProtocol {

    var scheduleCallCount = 0
    var cancelCallCount = 0
    var shouldSucceed = true

    func schedule(notification: Notification) throws {
        scheduleCallCount += 1

        if !shouldSucceed {
            throw NotificationError.schedulingFailed
        }
    }

    func cancel(identifier: String) {
        cancelCallCount += 1
    }
}
```

### Test Naming Conventions

- **Test Classes**: `[ComponentName]Tests.swift`
- **Test Methods**: `test[MethodName][Scenario][ExpectedResult]()`
  - Examples:
    - `testLoginWithValidCredentialsSucceeds()`
    - `testLoginWithInvalidPasswordFails()`
    - `testFetchTasksWithEmptyDatabaseReturnsEmptyArray()`

### Running Your New Tests

```bash
# Run your specific test file
xcodebuild test -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ModoTests/NotificationServiceTests

# Run a specific test method
xcodebuild test -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ModoTests/NotificationServiceTests/testNotificationScheduling
```

### Test Quality Checklist

Before committing tests, ensure:

- ☑️ Tests are isolated (no dependencies on other tests)
- ☑️ Tests are deterministic (same result every time)
- ☑️ Tests are fast (unit tests < 100ms, integration tests < 1s)
- ☑️ Test names clearly describe what's being tested
- ☑️ Both success and failure scenarios are covered
- ☑️ Edge cases and boundary conditions are tested
- ☑️ Mocks are used instead of real dependencies
- ☑️ No hardcoded values (use constants or helper methods)
- ☑️ Assertions are clear and specific
- ☑️ Tests pass consistently in CI environment

## Continuous Integration

### CI/CD Pipeline

The project uses **GitHub Actions** for automated testing and continuous integration. The CI pipeline is defined in `.github/workflows/main.yml`.

### CI Workflow Overview

The CI pipeline runs on **push and pull request events** to the `develop` and `main` branches:

1. **Checks out the code** from the repository.
2. **Cleans build artifacts** by removing derived data and Xcode caches.
3. **Caches Swift Package Manager (SPM) dependencies** to speed up builds.
4. **Creates a dummy `GoogleService-Info.plist`** for Firebase services (so tests can run without real credentials).
5. **Lists available iOS simulators** for debugging.
6. **Builds the project** in Debug configuration on the iOS simulator.
7. **Runs unit tests** (`ModoTests`) on iPhone 16 with iOS 18.4.
8. **Uploads logs and test results** for review.
9. **Fails the build** if any test fails.

### Viewing CI Build History

1. **Navigate to GitHub Actions**

   - Go to your repository on GitHub.
   - Click the **"Actions"** tab at the top.

2. **View Workflow Runs**

   - See a list of all CI runs.
   - Green checkmark ✅ = successful build.
   - Red X ❌ = failed build.
   - Yellow circle 🟡 = build in progress.

3. **View Build Details**
   - Click on any workflow run.
   - See detailed logs for each step.
   - View test results and failure reasons.
   - Download artifacts (`xcodebuild.log` and `TestResults`).

### CI Configuration File

Location: `.github/workflows/main.yml`

**Key configuration:**

```yaml
name: iOS CI

on:
  push:
    branches-ignore:
      - develop
      - main
  pull_request:
    branches: [develop, main]

jobs:
  test:
    name: Build and Test
    runs-on: macos-15 # macOS 15 comes with Xcode 16.x
    timeout-minutes: 30

    steps:
      - uses: actions/checkout@v4

      - name: Clean build artifacts
        run: |
          rm -rf ~/Library/Developer/Xcode/DerivedData
          rm -rf ~/Library/Caches/com.apple.dt.Xcode

      - name: Cache SPM packages
        uses: actions/cache@v4
        with:
          path: ~/Library/Developer/Xcode/DerivedData/*/SourcePackages
          key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
          restore-keys: |
            ${{ runner.os }}-spm-

      - name: Create GoogleService-Info.plist
        run: |
          mkdir -p Modo
          cat > Modo/GoogleService-Info.plist << 'EOF'
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
              <key>API_KEY</key>
              <string>AIzaSyDUMMY_KEY_FOR_CI_1234567890asdfsd</string>
              <key>GCM_SENDER_ID</key>
              <string>123456789</string>
              <key>PROJECT_ID</key>
              <string>modo-ci-test</string>
              <key>STORAGE_BUCKET</key>
              <string>modo-ci-test.appspot.com</string>
              <key>GOOGLE_APP_ID</key>
              <string>1:123456789:ios:abc123def456</string>
              <key>CLIENT_ID</key>
              <string>123456789-abcdefg.apps.googleusercontent.com</string>
              <key>REVERSED_CLIENT_ID</key>
              <string>com.googleusercontent.apps.123456789-abcdefg</string>
          </dict>
          </plist>
          EOF

      - name: List Available Simulators
        run: |
          echo "📱 Available destinations for scheme 'Modo':"
          xcodebuild -project Modo.xcodeproj -scheme Modo -showdestinations | grep "iPhone" | head -10

      - name: Build and Test
        timeout-minutes: 20
        run: |
          set -o pipefail
          echo "🧪 Testing on iOS Simulator"
          xcodebuild test \
            -project Modo.xcodeproj \
            -scheme Modo \
            -destination "platform=iOS Simulator,name=iPhone 16,OS=18.4" \
            -only-testing:ModoTests \
            CODE_SIGN_IDENTITY="-" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            ONLY_ACTIVE_ARCH=YES \
            -resultBundlePath TestResults \
            2>&1 | tee xcodebuild.log

      - name: Upload logs
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: build-logs
          path: |
            xcodebuild.log
            TestResults
```

### Local CI Simulation

You can run the same commands locally to simulate the full CI pipeline:

```bash
# Clean, build, and test locally
xcodebuild clean test -project Modo.xcodeproj -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'
```

## Building a Release

### Pre-Release Checklist

Before building a release, complete these steps:

#### 1. Update Version Numbers

**In Xcode:**

1. Select the `Modo` project in Project Navigator
2. Select the `Modo` target
3. Go to the **General** tab
4. Update:
   - **Version**: `CFBundleShortVersionString` (e.g., `1.2.0`)
   - **Build**: `CFBundleVersion` (e.g., `42`)

**Or edit `Info.plist` directly:**

```xml
<key>CFBundleShortVersionString</key>
<string>1.2.0</string>
<key>CFBundleVersion</key>
<string>42</string>
```

**Also update:**

- Version in `README.md`
- Version in release notes

#### 2. Run Full Test Suite

```bash
# Run all tests in Release configuration
xcodebuild test -scheme Modo -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Ensure **all tests pass** before proceeding.

#### 3. Code Quality Review

- ☑️ Remove all `print()` debug statements
- ☑️ Remove or address all `TODO` and `FIXME` comments
- ☑️ Verify no commented-out code remains
- ☑️ Check for memory leaks using Instruments
- ☑️ Run static analyzer (`Cmd + Shift + B`)
- ☑️ Ensure code follows style guidelines

#### 4. Build Verification

```bash
# Build in Release configuration to verify no errors
xcodebuild build -scheme Modo -configuration Release \
  -destination 'generic/platform=iOS'
```

### Release Build Process

#### Step 1: Archive the Build

1. In Xcode, select **Any iOS Device** as the target (not a simulator)
2. Go to **Product** → **Archive**
3. Wait for the archive process to complete (2-5 minutes)
4. The Organizer window will open automatically

#### Step 2: Validate the Archive

1. In Organizer, select the new archive
2. Click **Validate App**
3. Choose your distribution method (App Store Connect)
4. Select signing certificate
5. Wait for validation to complete
6. Fix any issues reported

#### Step 3: Distribute the App

**For App Store:**

1. Click **Distribute App**
2. Choose **App Store Connect**
3. Select **Upload**
4. Choose signing options
5. Review app details
6. Click **Upload**
7. Wait for upload to complete

**For TestFlight (Beta Testing):**

- After uploading to App Store Connect
- Go to App Store Connect website
- Select your app → TestFlight
- Add internal/external testers
- Submit for beta review

### Post-Release Tasks

#### 1. Tag the Release in Git

```bash
# Create and push a version tag
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin v1.2.0
```

#### 2. Create GitHub Release

1. Go to GitHub repository
2. Click **Releases** → **Draft a new release**
3. Choose the tag you just created
4. Add release title (e.g., "Version 1.2.0")
5. Add release notes (see template below)
6. Attach any relevant files
7. Publish release

#### 3. Update Documentation

- Update CHANGELOG.md with new version
- Update any user-facing documentation
- Notify team via Slack/email

### Release Notes Template

```markdown
## Version 1.2.0

**Release Date**: January 15, 2025

### New Features

- Added dark mode support
- Implemented AI-powered task suggestions
- New progress tracking dashboard

### Improvements

- Improved app startup time by 30%
- Enhanced task synchronization reliability
- Updated UI animations

### Bug Fixes

- Fixed crash when editing completed tasks
- Resolved sync issue with offline changes
- Fixed calendar display on iPad

### Technical Changes

- Updated Firebase SDK to v12.4.0
- Migrated to new authentication flow
- Performance optimizations
```

### Version Numbering

Follow **Semantic Versioning** (`MAJOR.MINOR.PATCH`):

- **MAJOR**: Breaking changes, major new features (e.g., `1.0.0` → `2.0.0`)
- **MINOR**: New features, backward compatible (e.g., `1.2.0` → `1.3.0`)
- **PATCH**: Bug fixes, minor improvements (e.g., `1.2.0` → `1.2.1`)

**Build Number**: Increment for every build, regardless of version changes.

## Code Style Guidelines

### Swift Style Guide

Follow Apple's Swift API Design Guidelines and these project-specific rules:

#### Naming Conventions

- **Classes**: PascalCase (`AuthService`, `UserProfile`)
- **Methods**: camelCase (`signInWithGoogle`, `checkEmailVerification`)
- **Variables**: camelCase (`currentUser`, `isAuthenticated`)
- **Constants**: camelCase (`maxRetryCount`)

#### Code Organization

- **File Structure**: One main class per file
- **Extensions**: Separate files for extensions
- **Imports**: Alphabetical order, grouped by type

#### SwiftUI Guidelines

- **View Names**: Descriptive names ending in "View"
- **State Variables**: Use `@State` for local state
- **Binding**: Use `@Binding` for two-way data flow
- **Environment**: Use `@EnvironmentObject` for shared state

### Code Formatting

- **Indentation**: 4 spaces (no tabs)
- **Line Length**: Maximum 120 characters
- **Braces**: Opening brace on same line
- **Spacing**: One space around operators

### Documentation

- **Public APIs**: Document all public methods and properties
- **Complex Logic**: Add inline comments for complex algorithms
- **TODO Comments**: Use `// TODO:` for future improvements

## Contributing

### Development Workflow

#### 1. Create a Feature Branch

```bash
# Always create a new branch from main
git checkout main
git pull origin main
git checkout -b feature/task-priority-sorting
```

**Branch naming conventions:**

- `feature/` - New features
- `bugfix/` - Bug fixes
- `hotfix/` - Critical production fixes
- `refactor/` - Code refactoring
- `docs/` - Documentation updates

#### 2. Make Changes

- Write clean, well-documented code
- Follow code style guidelines
- Write tests for new functionality
- Update documentation as needed

#### 3. Test Your Changes

```bash
# Run tests locally
xcodebuild test -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific tests if needed
xcodebuild test -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ModoTests/TaskServiceTests
```

#### 4. Commit Changes

```bash
# Stage your changes
git add .

# Commit with conventional commit message
git commit -m "feat: add priority sorting to task list"
```

#### 5. Push and Create Pull Request

```bash
# Push your branch
git push origin feature/task-priority-sorting

# Create PR on GitHub
# Go to repository → Pull Requests → New Pull Request
```

### Commit Message Format

Use **Conventional Commits** format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks, dependency updates

**Examples:**

```bash
feat: add dark mode support to all screens

fix: resolve crash when editing completed task
Fixes #123

docs: update API documentation for TaskService

refactor: extract validation logic into separate service

test: add unit tests for HealthCalculator

chore: update Firebase SDK to v12.4.0
```

### Pull Request Guidelines

#### PR Description Template

```markdown
## Description

Brief description of changes

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing

- [ ] Unit tests added/updated
- [ ] UI tests added/updated
- [ ] Manual testing completed
- [ ] All tests pass locally

## Checklist

- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No new warnings introduced
- [ ] Related issues linked

## Screenshots (if applicable)

[Add screenshots for UI changes]

## Related Issues

Closes #123
```

#### PR Requirements

Before submitting a PR:

1. ☑️ All tests pass locally
2. ☑️ Code follows style guidelines
3. ☑️ Documentation is updated
4. ☑️ Commit messages follow conventions
5. ☑️ Branch is up to date with main
6. ☑️ No merge conflicts
7. ☑️ PR description is complete

### Code Review Process

#### For Authors

1. **Self-review** your code before requesting review
2. **Respond to feedback** promptly and professionally
3. **Make requested changes** and re-request review
4. **Keep PRs focused** - one feature or fix per PR
5. **Keep PRs small** - aim for < 400 lines of changes

#### For Reviewers

1. **Review promptly** (within 24 hours)
2. **Be constructive** and respectful
3. **Explain your reasoning** for change requests
4. **Approve when ready** or request specific changes
5. **Test the changes** if possible

#### Review Checklist

- ☑️ Code is clear and readable
- ☑️ Tests adequately cover changes
- ☑️ No obvious bugs or issues
- ☑️ Follows architecture patterns
- ☑️ Performance considerations addressed
- ☑️ Security implications considered
- ☑️ Documentation is accurate

### Merging

After approval and CI passes:

1. **Squash and merge** (preferred) - Creates clean history
2. **Merge commit** - Preserves all commits
3. **Rebase and merge** - Linear history

**Delete branch** after merging to keep repository clean.

### Issue Reporting

When reporting bugs or requesting features:

#### Bug Report Template

```markdown
## Bug Description

Clear, concise description of the bug

## Steps to Reproduce

1. Open the app
2. Navigate to Tasks screen
3. Tap on completed task
4. App crashes

## Expected Behavior

Task details screen should open

## Actual Behavior

App crashes immediately

## Environment

- iOS Version: 16.5
- Device: iPhone 14 Pro
- App Version: 1.2.0
- Xcode Version: 14.3

## Screenshots/Logs

[Attach crash logs or screenshots]

## Additional Context

This only happens with tasks completed more than 7 days ago
```

#### Feature Request Template

```markdown
## Feature Description

Brief description of the proposed feature

## Use Case

Why is this feature needed? What problem does it solve?

## Proposed Solution

How should this feature work?

## Alternatives Considered

What other approaches did you consider?

## Additional Context

Any mockups, examples, or references
```

### Getting Help

If you need assistance:

1. **Check documentation** first (this file, README.md)
2. **Search existing issues** on GitHub
3. **Ask in discussions** for general questions
4. **Create an issue** for specific problems
5. **Contact maintainers** for urgent matters

---

**Last Updated**: December 2025  
**Document Version**: 2.0  
**Maintainers**: Modo Development Team  
**License**: [Specify license]

---

## Quick Reference

### Common Commands

```bash
# Build
xcodebuild build -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15'

# Test
xcodebuild test -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15'

# Clean
xcodebuild clean -scheme Modo

# Archive
xcodebuild archive -scheme Modo -archivePath ./build/Modo.xcarchive
```

### Keyboard Shortcuts (Xcode)

- `Cmd + B` - Build
- `Cmd + R` - Run
- `Cmd + U` - Run tests
- `Cmd + .` - Stop running
- `Cmd + Shift + K` - Clean build folder
- `Cmd + 0` - Show/hide navigator
- `Cmd + 6` - Show test navigator
