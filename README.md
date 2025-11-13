# Modo Guide

**Modo** is a comprehensive health and wellness iOS application designed to help users track their diet and fitness goals through an intuitive task-based interface. Built with SwiftUI and Firebase, Modo provides personalized health recommendations, progress tracking, and AI-powered insights to support your wellness journey.

## What is Modo?

Modo is a health and wellness companion app that transforms your health goals into manageable daily tasks. Whether you're looking to lose weight, maintain a healthy lifestyle, or build muscle, Modo helps you stay on track with:

- **Task-Based Health Tracking**: Break down your health goals into daily diet and fitness tasks
- **Personalized Onboarding**: Customize your experience based on your height, weight, age, lifestyle, and goals
- **Progress Monitoring**: Track your daily streaks, calories, and overall progress
- **AI-Powered Insights**: Get personalized recommendations and ask questions about your health journey
- **Social Authentication**: Secure login with email/password or Google Sign-In
- **Cross-Platform Sync**: Your data is safely stored and synchronized across devices

## Prerequisites

Before installing Modo, ensure you have the following:

### Required Software
- **macOS**: macOS 12.0 (Monterey) or later
- **Xcode**: Version 14.0 or later
- **iOS Simulator**: iOS 15.0 or later (for testing)
- **Physical Device**: iPhone running iOS 15.0 or later (for full functionality)

### Required Accounts
- **Apple Developer Account**: For building and deploying to physical devices
- **Firebase Account**: For authentication and data storage (already configured)
- **Google Account**: For Google Sign-In functionality (optional)

### Installation Steps

1. **Clone the Repository**
   ```bash
   git clone https://github.com/LEOK66/Modo.git
   cd Modo
   ```
   
2. **Checkout develop branch**
   ```bash
   git checkout develop
   ```
   
3. **Open in Xcode**
   ```bash
   open Modo.xcodeproj
   ```
   
4. **Install Dependencies**
   - Xcode will automatically resolve Swift Package Manager dependencies
   - Wait for package resolution to complete (Firebase, Google Sign-In, etc.)

5. **Configure Firebase** (Already configured)
   - The `GoogleService-Info.plist` file is already included
   - Firebase project is set up for authentication and data storage

6. **Build and Run**
   - Select your target device or simulator
   - Press `Cmd + R` to build and run the app

## How to Run Modo

### Running on iOS Simulator
1. Open Xcode
2. Select an iOS Simulator from the device dropdown
3. Press `Cmd + R` or click the "Play" button
4. The app will launch in the simulator

### Running on Physical Device
1. Connect your iPhone to your Mac via USB
2. Trust the computer on your iPhone if prompted
3. Select your device from the device dropdown in Xcode
4. Press `Cmd + R` to build and install the app
5. On your iPhone, go to Settings > General > VPN & Device Management
6. Trust the developer certificate for the Modo app

## How to Use Modo

### Getting Started

1. **Launch the App**
   - Open Modo from your home screen
   - You'll see the login screen

2. **Create an Account**
   - Tap "New user?" to create an account
   - Enter your email and password
   - Verify your email address (check your inbox)
   - Sign in with Google (optional)

3. **Complete Onboarding**
   - Provide your height, weight, and age
   - Select your lifestyle (Sedentary, Moderately Active, Athletic)
   - Choose your goal (Lose Weight, Keep Healthy, Gain Muscle)
   - Set your target weight loss and timeframe
   - You can skip any step if you prefer

### Main Features

#### Daily Task Management
- **View Today's Tasks**: See your diet and fitness tasks for the day
- **Add New Tasks**: Tap "Add Task" to create custom diet or fitness tasks
- **AI Tasks**: Use "AI Tasks" for personalized recommendations (coming soon)
- **Mark Complete**: Tap any task to mark it as completed
- **Track Progress**: View your completion stats at the top

#### Task Categories
- **Diet Tasks** 🥗: Track meals, calories, and nutrition goals
- **Fitness Tasks** 🏃: Monitor workouts, duration, and exercise goals

#### Profile Management
- **View Profile**: Tap your avatar to access your profile
- **Track Stats**: Monitor your day streak and calorie intake
- **Progress Tracking**: View detailed progress and achievements
- **Settings**: Customize app preferences and notifications

#### Insights & AI
- **Ask Questions**: Use the Insights tab to ask health-related questions
- **Add Photos**: Upload photos for AI analysis (coming soon)
- **Get Recommendations**: Receive personalized health advice

### Navigation

- **Bottom Navigation**: Switch between Tasks, Insights, and Profile
- **Calendar**: Tap the calendar icon to view different dates
- **Back Navigation**: Use the back button or swipe gestures

## How to Report a Bug

We appreciate your feedback! To report a bug effectively, please include the following information:

### Bug Report Template
```
**Bug Description:**
[Brief description of the issue]

**Steps to Reproduce:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Expected Behavior:**
[What should happen]

**Actual Behavior:**
[What actually happens]

**Device Information:**
- Device: [iPhone model]
- iOS Version: [iOS version]
- App Version: [Current app version]

**Screenshots:**
[If applicable, attach screenshots]

**Additional Notes:**
[Any other relevant information]
```

### Reporting Methods
1. **GitHub Issues**: Create an issue in our GitHub repository
2. **Email**: Send detailed reports to [support email]
3. **In-App Feedback**: Use the Help & Support section in the app

### What Information We Need
- Clear description of the problem
- Steps to reproduce the issue
- Device and iOS version
- Screenshots or screen recordings
- Whether the issue occurs consistently
- Any error messages you see

## Known Issues and Limitations

### Current Limitations
- **AI Features**: AI task generation and photo analysis are work in progress
- **Offline Mode**: Limited offline functionality
- **Data Export**: Export functionality not yet available
- **Notifications**: Push notifications not implemented
- **Social Features**: Sharing and social integration coming soon

### Known Bugs
- None currently reported. If you encounter any issues, please report them using the bug reporting process above.

### Work in Progress Features
- AI-powered task recommendations
- Photo analysis for meal tracking
- Advanced progress analytics
- Social sharing and community features
- Apple Health integration
- Push notifications for reminders

## Support and Community

- **Documentation**: Check this README for the latest information
- **Developer Documentation**: See [DEVELOPER.md](DEVELOPER.md) for technical details and contribution guidelines
- **GitHub Issues**: Report bugs and request features
- **Email Support**: Contact us at [support email]
- **Version Updates**: Keep the app updated for the latest features and bug fixes

## Privacy and Security

- **Data Protection**: Your personal health data is encrypted and stored securely
- **Firebase Security**: All data is protected by Firebase's security measures
- **No Data Sharing**: We don't share your personal information with third parties
- **Account Security**: Use strong passwords and enable two-factor authentication when available

---

**Version**: 1.0.0  
**Last Updated**: January 2025  
**Compatibility**: iOS 15.0+  
**Developer**: Modo Development Team



