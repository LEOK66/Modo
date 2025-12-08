# Modo

<p align="center">
  <strong>Your Personal Health & Wellness Companion</strong>
</p>

<p align="center">
  <a href="#overview">Overview</a> •
  <a href="#features">Features</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="USER_MANUAL.md">User Manual</a> •
  <a href="DEVELOPER.md">Developer Docs</a>
</p>

---

## Overview

**Modo** is a comprehensive health and wellness iOS application that transforms your health goals into manageable daily tasks. Built with SwiftUI and Firebase, Modo provides personalized health recommendations, progress tracking, and AI-powered insights to support your wellness journey.

Whether you're looking to lose weight, maintain a healthy lifestyle, or build muscle, Modo helps you stay on track with an intuitive task-based approach to health management.

---

## Features

### Core Features

- **Task-Based Health Tracking** - Break down health goals into daily diet and fitness tasks
- **Personalized Onboarding** - Customize your experience based on your profile and goals
- **Progress Monitoring** - Track daily streaks, calories, and completion rates
- **Smart Goal Setting** - Choose from lose weight, maintain health, or gain muscle
- **Cloud Sync** - Your data safely stored and synchronized across devices
- **Achievements & Milestones** – Track progress by earning badges and unlocking accomplishments for completed goals

### Authentication

- Email/password authentication
- Google Sign-In integration
- Secure email verification
- Password reset functionality

### Tracking & Analytics

- Daily task completion tracking
- Calorie intake monitoring
- Day streak tracking
- Progress visualization
- Historical data review

### AI Integration

- AI-powered task recommendations
- Health question answering
- Photo analysis for meal tracking
- Personalized insights

---

## Quick Start

### For Users

**1. Install the App**

```bash
git clone https://github.com/LEOK66/Modo.git
cd Modo
open Modo.xcodeproj
```

Build and run in Xcode (Cmd + R)

**2. Create Your Account**

- Launch the app
- Tap "New user?" to register
- Verify your email
- Complete the onboarding questionnaire

**3. Start Using Modo**

- Add your first diet or fitness task
- Mark tasks complete throughout the day
- Track your progress and maintain your streak

**→ For detailed instructions, see the [User Manual](USER_MANUAL.md)**

### For Developers

**1. Clone & Setup**

```bash
git clone https://github.com/LEOK66/Modo.git
cd Modo
open Modo.xcodeproj
```

**2. Install Dependencies**

Dependencies are managed via Swift Package Manager and resolve automatically when you open the project.

**3. Build & Test**

```bash
# Run all tests
xcodebuild test -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15'

# Build the app
xcodebuild build -scheme Modo -destination 'platform=iOS Simulator,name=iPhone 15'
```

**→ For complete documentation, see [Developer Guide](DEVELOPER.md)**

---

## Documentation

- **[User Manual](USER_MANUAL.md)** - Complete guide for installing, using, and troubleshooting Modo
- **[Developer Documentation](DEVELOPER.md)** - Technical documentation for contributors and developers

---

## System Requirements

**Minimum:**

- iOS 15.0 or later
- iPhone 6s or later
- Xcode 14.0+ (for development)
- Internet connection

**Recommended:**

- iOS 16.0 or later
- iPhone 12 or later
- macOS 12.0+ with Xcode 14.0+

---

## Technology Stack

**Frontend:**

- SwiftUI
- Swift 5.7+
- MVVM Architecture

**Backend:**

- Firebase Authentication
- Firebase Realtime Database
- Cloud Functions

**Dependencies:**

- Firebase iOS SDK v12.4.0
- Google Sign-In iOS v9.0.0
- SwiftData

---

## Project Structure

```
Modo/
├── .github/                           # GitHub workflows and CI/CD
├── Modo.xcodeproj/                   # Xcode project configuration
├── Modo/                             # Main application target
│   ├── Assets.xcassets/             # App icons, images, and colors
│   ├── Constants/                   # App-wide constants and configuration
│   ├── DependencyInjection/         # Dependency injection container
│   ├── Errors/                      # Custom error types
│   ├── Models/                      # Data models and entities
│   ├── Protocols/                   # Protocol definitions
│   ├── Repositories/                # Data access layer
│   ├── Resources/                   # Additional resources (configs, assets)
│   ├── Services/                    # Business logic and service layer
│   ├── UI/                          # SwiftUI views and components
│   ├── ViewModels/                  # MVVM view models
│   ├── AppDelegate.swift            # App lifecycle management
│   ├── Info.plist                   # App configuration
│   ├── Modo.entitlements            # App capabilities and permissions
│   └── ModoApp.swift                # App entry point
├── ModoTests/                        # Unit tests
│   ├── Mocks/                       # Mock objects for testing
│   ├── TestHelpers/                 # Testing utilities
│   └── ...Tests.swift
├── ModoUITests/                      # UI automation tests
├── modo-firebase-functions/          # Backend Firebase Cloud Functions
├── .gitignore                        # Git ignore rules
└── README.md                         # Project overview and quick start
```

---

## Contributing

We welcome contributions! To get started:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with tests
4. Commit using conventional commits (`feat:`, `fix:`, etc.)
5. Push and create a pull request

See [DEVELOPER.md](DEVELOPER.md) for detailed contribution guidelines.

---

## Support

**Documentation:**

- [User Manual](USER_MANUAL.md) - Installation and usage guide
- [Developer Guide](DEVELOPER.md) - Technical documentation

**Get Help:**

- [Report Bugs](https://github.com/LEOK66/Modo/issues)
- [GitHub Discussions](https://github.com/LEOK66/Modo/discussions)
- Email: support@modo-app.com

---

## Roadmap

### Version 1.0.0 (Current)

- User authentication
- Task management
- Progress tracking
- Firebase cloud sync
- Task editing & deletion
- Data export
- AI task recommendations
- Photo analysis
- Push notifications

### Coming Soon

- Apple Health integration

---

## Acknowledgments

Built with SwiftUI, Firebase, and dedication from the Modo development team.

---

<p align="center">
  <sub>Version 1.0.0 | Last Updated: December 2025</sub>
</p>
