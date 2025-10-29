# Modo iOS App - Developer Documentation

This document provides comprehensive guidelines for developers who want to contribute to the Modo iOS application. It covers project setup, architecture, testing, and contribution guidelines.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Project Structure](#project-structure)
3. [Architecture Overview](#architecture-overview)
4. [Building the Software](#building-the-software)
5. [Testing](#testing)
6. [Adding New Tests](#adding-new-tests)
7. [Building a Release](#building-a-release)
8. [Code Style Guidelines](#code-style-guidelines)
9. [Contributing](#contributing)

## Getting Started

### Prerequisites

- **macOS**: macOS 12.0 (Monterey) or later
- **Xcode**: Version 14.0 or later
- **iOS Deployment Target**: iOS 15.0+
- **Swift**: Version 5.7+
- **Git**: For version control

### Obtaining the Source Code

1. **Clone the Repository**
   ```bash
   git clone https://github.com/your-username/Modo.git
   cd Modo
   ```

2. **Verify Dependencies**
   - The project uses Swift Package Manager for dependencies
   - Dependencies are automatically resolved when opening the project in Xcode
   - No additional setup required for Firebase or Google Sign-In

3. **Open the Project**
   ```bash
   open Modo.xcodeproj
   ```

### Dependencies

The project uses the following Swift Package Manager dependencies:

- **Firebase iOS SDK** (v12.4.0): Authentication, data storage, and analytics
- **Google Sign-In iOS** (v9.0.0): Social authentication
- **SwiftData**: Local data persistence
- **SwiftUI**: User interface framework

## Project Structure

```
Modo/
├── Modo/                          # Main app target
│   ├── ModoApp.swift              # App entry point and configuration
│   ├── Item.swift                 # SwiftData model placeholder
│   ├── Info.plist                 # App configuration
│   ├── GoogleService-Info.plist   # Firebase configuration
│   ├── Assets.xcassets/          # App icons and images
│   ├── Services/                  # Business logic and data services
│   │   ├── AuthService.swift     # Authentication management
│   │   └── ThemeManager.swift    # UI theming (future)
│   └── UI/                        # User interface components
│       ├── AuthenticatedView.swift # Main authenticated app container
│       ├── Components/            # Reusable UI components
│       │   ├── Branding/         # Logo and branding components
│       │   ├── Buttons/          # Custom button components
│       │   ├── Core/             # Core utilities and extensions
│       │   ├── Feedback/         # Toast notifications and feedback
│       │   ├── Icons/            # Custom icon components
│       │   ├── Inputs/           # Form input components
│       │   ├── Navigation/       # Navigation components
│       │   └── Profile/          # Profile-related components
│       ├── InfoGatheringPages/   # Onboarding flow
│       │   ├── InfoGatheringView.swift
│       │   └── UserProfile.swift # User profile data model
│       ├── MainPages/            # Core app screens
│       │   ├── AddTaskView.swift
│       │   ├── CalendarPopupView.swift
│       │   ├── InsightPageView.swift
│       │   ├── MainContainerView.swift
│       │   ├── MainPageView.swift
│       │   └── ProfilePageView.swift
│       ├── ProfileSubPages/       # Profile-related screens
│       │   ├── AchievementsView.swift
│       │   ├── HelpSupportView.swift
│       │   ├── ProgressView.swift
│       │   └── SettingsView.swift
│       └── RegisterLoginPages/    # Authentication screens
│           ├── EmailVerificationView.swift
│           ├── ForgotPasswordView.swift
│           ├── LoginView.swift
│           └── RegisterView.swift
├── ModoTests/                     # Unit tests
│   ├── AuthServiceTests.swift    # Authentication service tests
│   └── ModoTests.swift           # General app tests
├── ModoUITests/                  # UI tests
│   ├── ModoUITests.swift
│   └── ModoUITestsLaunchTests.swift
└── Modo.xcodeproj/              # Xcode project configuration
```

### Key Directories Explained

- **`Services/`**: Contains business logic, data services, and API integrations
- **`UI/Components/`**: Reusable UI components organized by functionality
- **`UI/MainPages/`**: Core application screens and main user flows
- **`UI/RegisterLoginPages/`**: Authentication and onboarding screens
- **`UI/ProfileSubPages/`**: Profile management and settings screens
- **`ModoTests/`**: Unit tests for business logic and services
- **`ModoUITests/`**: UI automation tests

## Architecture Overview

### Design Patterns

The app follows several key architectural patterns:

1. **MVVM (Model-View-ViewModel)**: SwiftUI views with `@ObservableObject` view models
2. **Service Layer Pattern**: Centralized business logic in service classes
3. **Repository Pattern**: Data access abstraction (implemented via Firebase and SwiftData)
4. **Dependency Injection**: Services injected via `@EnvironmentObject`

### Key Components

#### Authentication Service (`AuthService.swift`)
- Manages user authentication state
- Handles email/password and Google Sign-In
- Provides authentication state to the entire app
- Singleton pattern for global access

#### Data Models
- **`UserProfile`**: SwiftData model for user profile information
- **`Item`**: Placeholder SwiftData model for future data storage

#### UI Architecture
- **SwiftUI Views**: Declarative UI components
- **Navigation**: Uses `NavigationStack` for modern navigation
- **State Management**: `@State`, `@Binding`, and `@EnvironmentObject`
- **Data Flow**: Unidirectional data flow with published properties

### Data Flow

1. **Authentication**: `AuthService` manages auth state → Views react to changes
2. **User Data**: SwiftData models → Views display data
3. **Task Management**: Local state in views → Future: Firebase integration
4. **Navigation**: SwiftUI navigation system with type-safe routing

## Building the Software

### Development Build

1. **Open Xcode**
   ```bash
   open Modo.xcodeproj
   ```

2. **Select Target**
   - Choose iOS Simulator or connected device
   - Ensure deployment target is iOS 15.0+

3. **Build and Run**
   - Press `Cmd + R` or click the Play button
   - Xcode will automatically resolve dependencies and build

### Debug Build Configuration

- **Build Configuration**: Debug (default)
- **Optimization**: None (`-Onone`)
- **Debug Information**: Full (`-g`)
- **Swift Compilation Mode**: Incremental

### Release Build Configuration

- **Build Configuration**: Release
- **Optimization**: Speed (`-O`)
- **Debug Information**: None
- **Swift Compilation Mode**: Whole Module

### Build Requirements

- **Minimum iOS Version**: 15.0
- **Swift Language Version**: 5.7
- **Architecture**: arm64 (iOS devices), x86_64 (simulator)

## Testing

### Running Tests

#### Unit Tests
```bash
# Run all unit tests
xcodebuild test -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ModoTests/AuthServiceTests
```

#### UI Tests
```bash
# Run all UI tests
xcodebuild test -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ModoUITests
```

#### In Xcode
1. Press `Cmd + U` to run all tests
2. Use the Test Navigator to run specific tests
3. Use the diamond icons next to test methods to run individual tests

### Test Structure

#### Unit Tests (`ModoTests/`)
- **`AuthServiceTests.swift`**: Tests for authentication functionality
- **`ModoTests.swift`**: General app tests including validation logic

#### UI Tests (`ModoUITests/`)
- **`ModoUITests.swift`**: UI automation tests
- **`ModoUITestsLaunchTests.swift`**: App launch performance tests

### Test Coverage

Current test coverage includes:
- Email and password validation
- Authentication service methods
- User input validation (height, weight, age, etc.)
- Performance testing for validation functions

## Adding New Tests

### Test Naming Conventions

- **Test Classes**: `[ComponentName]Tests.swift`
- **Test Methods**: `test[Description]()`
- **Performance Tests**: `test[Description]Performance()`

### Example Test Structure

```swift
import XCTest
@testable import Modo

final class NewFeatureTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Setup code before each test
    }
    
    override func tearDownWithError() throws {
        // Cleanup code after each test
    }
    
    func testFeatureBehavior() throws {
        // Given
        let input = "test input"
        
        // When
        let result = feature.process(input)
        
        // Then
        XCTAssertEqual(result, expectedOutput)
    }
    
    func testFeaturePerformance() throws {
        self.measure {
            // Code to measure performance
        }
    }
}
```

### Test Categories

1. **Unit Tests**: Test individual components in isolation
2. **Integration Tests**: Test component interactions
3. **UI Tests**: Test user interface behavior
4. **Performance Tests**: Measure execution time and memory usage

### Testing Guidelines

- Write tests for all public methods
- Test both success and failure scenarios
- Use descriptive test names
- Follow the Given-When-Then pattern
- Mock external dependencies
- Test edge cases and boundary conditions

## Building a Release

### Pre-Release Checklist

1. **Update Version Numbers**
   - Update `CFBundleShortVersionString` in `Info.plist`
   - Update `CFBundleVersion` for build number
   - Update version in `README.md`

2. **Run Full Test Suite**
   ```bash
   xcodebuild test -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15'
   ```

3. **Code Review**
   - Ensure all code follows style guidelines
   - Verify no debug code remains
   - Check for TODO comments

4. **Build Verification**
   ```bash
   xcodebuild build -scheme Modo -configuration Release -destination 'platform=iOS Simulator,name=iPhone 15'
   ```

### Release Build Process

1. **Archive Build**
   - Select "Any iOS Device" as target
   - Product → Archive
   - Wait for build completion

2. **Distribution**
   - Use Xcode Organizer for App Store distribution
   - Or export for Ad Hoc/Enterprise distribution

3. **Post-Release Tasks**
   - Tag the release in Git
   - Update release notes
   - Notify team of release

### Version Management

- **Semantic Versioning**: `MAJOR.MINOR.PATCH`
- **Build Numbers**: Increment for each build
- **Git Tags**: Tag releases with version numbers

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

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/new-feature-name
   ```

2. **Make Changes**
   - Follow code style guidelines
   - Write tests for new functionality
   - Update documentation as needed

3. **Test Changes**
   ```bash
   xcodebuild test -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15'
   ```

4. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   ```

5. **Push and Create PR**
   ```bash
   git push origin feature/new-feature-name
   ```

### Commit Message Format

Use conventional commits format:
- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `style:` Code style changes
- `refactor:` Code refactoring
- `test:` Test additions/changes
- `chore:` Maintenance tasks

### Pull Request Guidelines

1. **Description**: Clear description of changes
2. **Tests**: Include test coverage
3. **Documentation**: Update relevant documentation
4. **Review**: Request review from team members
5. **CI**: Ensure all CI checks pass

### Code Review Process

1. **Automated Checks**: CI runs tests and linting
2. **Peer Review**: Team members review code
3. **Approval**: At least one approval required
4. **Merge**: Merge after approval and CI success

### Issue Reporting

When reporting issues, include:
- **Description**: Clear problem description
- **Steps to Reproduce**: Detailed reproduction steps
- **Expected Behavior**: What should happen
- **Actual Behavior**: What actually happens
- **Environment**: iOS version, device, Xcode version
- **Screenshots**: If applicable

---

**Last Updated**: January 2025  
**Maintainer**: Modo Development Team  
**License**: [Add license information]
