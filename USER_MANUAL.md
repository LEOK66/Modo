# Modo User Manual

**Version 1.0.0** | Last Updated: December 2025

---

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Getting Started](#getting-started)
4. [Creating an Account](#creating-an-account)
5. [Onboarding](#onboarding)
6. [Using Modo](#using-modo)
7. [Features Guide](#features-guide)
8. [Troubleshooting](#troubleshooting)
9. [Reporting Bugs](#reporting-bugs)

---

## Introduction

### What is Modo?

Modo is a comprehensive health and wellness iOS application designed to help you track your diet and fitness goals through an intuitive task-based interface. Whether you're looking to lose weight, maintain a healthy lifestyle, or build muscle, Modo helps you stay on track with:

- Daily diet and fitness task management
- Personalized health recommendations
- Progress tracking with streaks and statistics
- AI-powered insights (coming soon)
- Secure cloud synchronization

### Who is Modo for?

- Anyone looking to improve their health and fitness
- People who want to track diet and exercise in one place
- Users who prefer task-based goal management
- Individuals seeking personalized health insights

### System Requirements

**Minimum Requirements:**
- iOS 15.0 or later
- iPhone 6s or later
- 100MB free storage
- Internet connection (WiFi or cellular)

**Recommended:**
- iOS 16.0 or later
- iPhone 12 or later
- 200MB free storage
- WiFi connection for optimal performance

---

## Installation

### Prerequisites

Before installing Modo, ensure you have:

**Hardware:**
- Mac computer running macOS 12.0 (Monterey) or later
- iPhone running iOS 15.0 or later (for deployment to device)
- At least 2GB of free disk space

**Software:**
- Xcode 14.0 or later (download from Mac App Store)
- Git (for cloning the repository)

**Accounts:**
- Apple ID for App Store and Xcode
- Apple Developer Account (for deploying to physical device)
- Google Account (optional, for Google Sign-In)

### Step-by-Step Installation

#### Step 1: Install Xcode

1. Open the **Mac App Store**
2. Search for **"Xcode"**
3. Click **"Get"** or **"Download"**
4. Wait for installation to complete (30-60 minutes)
5. Open Xcode and accept the license agreement
6. Wait for additional components to install

#### Step 2: Clone the Repository

Open **Terminal** and run:

```bash
# Navigate to your desired directory
cd ~/Documents

# Clone the Modo repository
git clone https://github.com/LEOK66/Modo.git

# Navigate into the project directory
cd Modo
```

**Alternative**: Download the ZIP file from GitHub and extract it.

#### Step 3: Open the Project

```bash
# Open the project in Xcode
open Modo.xcodeproj
```

Or manually:
1. Open Xcode
2. Go to **File** → **Open**
3. Navigate to the Modo folder
4. Select `Modo.xcodeproj`

#### Step 4: Install Dependencies

Xcode will automatically resolve Swift Package Manager dependencies:

1. Wait for "Resolving Package Dependencies" to complete (2-5 minutes)
2. Dependencies include Firebase iOS SDK, Google Sign-In, and supporting libraries

If dependencies don't resolve:
- Go to **File** → **Packages** → **Resolve Package Versions**

#### Step 5: Build the Project

1. Select a target device from the dropdown menu:
   - Choose any iPhone simulator (e.g., "iPhone 15")
   - Or select your connected physical iPhone

2. Press **`Cmd + B`** or click **Product** → **Build**

3. Wait for build to complete (1-3 minutes on first build)

4. If build errors occur:
   - Try **Product** → **Clean Build Folder** (`Cmd + Shift + K`)
   - Rebuild the project

#### Step 6: Run on Simulator

1. Select an iOS Simulator (e.g., "iPhone 15")
2. Press **`Cmd + R`** or click the **Play (▶️)** button
3. The simulator will launch and install the app
4. Modo will open automatically

**Success!** You should see the Modo login screen.

#### Step 7: Run on Physical Device (Optional)

To install on your iPhone:

1. **Connect your iPhone** to your Mac via USB
2. **Unlock your iPhone** and tap **"Trust This Computer"**
3. In Xcode, **select your iPhone** from the device dropdown
4. **Configure signing**:
   - Select the **Modo** project in the navigator
   - Select the **Modo** target
   - Go to **"Signing & Capabilities"** tab
   - Check **"Automatically manage signing"**
   - Select your **Team** (your Apple ID)
5. Press **`Cmd + R`** to build and install
6. **On your iPhone**:
   - Go to **Settings** → **General** → **VPN & Device Management**
   - Tap your developer certificate
   - Tap **"Trust"**
7. Return to home screen and open **Modo**

---

## Getting Started

### First Launch

When you first launch Modo, you'll see the **Login Screen** with options to:

1. **Sign in** (if you already have an account)
2. **New user?** (to create a new account)

Let's walk through creating a new account.

---

## Creating an Account

### Registration Methods

You can create a Modo account using:
- Email and password
- Google Sign-In

### Email & Password Registration

#### Step 1: Navigate to Registration

1. On the login screen, tap **"New user?"** at the bottom
2. You'll be taken to the registration screen

#### Step 2: Enter Your Information

1. **Email Address**
   - Must be a valid email format
   - Example: `john.doe@example.com`

2. **Password**
   - Minimum 8 characters
   - Should include letters, numbers, and symbols
   - Example: `MySecure123!`

3. **Confirm Password**
   - Re-enter your password to confirm

4. Tap **"Register"**

#### Step 3: Verify Your Email

After registration:

1. You'll see the **Email Verification** screen
2. Check your email inbox for a verification message from Firebase
3. Click the verification link in the email
4. Return to the app
5. Tap **"I've verified my email"**
6. Tap **"Continue"** to proceed

**Important**: You must verify your email before continuing.

**Troubleshooting**:
- **No email?** Check your spam/junk folder
- **Still no email?** Tap "Resend verification email"
- **Wrong email?** Tap "Sign out" and register again

### Google Sign-In Registration

1. On the registration screen, tap **"Sign in with Google"**
2. Select your Google account from the popup
3. Grant permissions when prompted
4. You'll be automatically signed in and taken to onboarding

---

## Onboarding

The onboarding process personalizes Modo to your health goals. You can **skip any step** if you prefer, but providing accurate information helps Modo give better recommendations.

### Step 1: Enter Your Height

**Imperial Units (Feet & Inches):**
- Select feet from the first picker (3-8 feet)
- Select inches from the second picker (0-11 inches)
- Example: 5 feet 9 inches

**Metric Units (Centimeters):**
- Tap **"Switch to cm"** at the bottom
- Enter your height in centimeters (100-250 cm)
- Example: 175 cm

Tap **"Next"** to continue or **"Skip"** to skip.

### Step 2: Enter Your Weight

**Imperial Units (Pounds):**
- Enter your current weight in pounds (50-500 lbs)
- Example: 165 lbs

**Metric Units (Kilograms):**
- Tap **"Switch to kg"** at the bottom
- Enter your weight in kilograms (20-200 kg)
- Example: 75 kg

Tap **"Next"** to continue or **"Skip"** to skip.

### Step 3: Enter Your Age

- Enter your age in years (13-120)
- Example: 28

Tap **"Next"** to continue or **"Skip"** to skip.

### Step 4: Select Your Lifestyle

Choose the option that best describes your daily activity level:

**Sedentary 🪑**
- Desk job, minimal physical activity
- Less than 30 minutes of activity per day
- Example: Office worker, driver

**Moderately Active 🚶**
- Regular light exercise or active job
- 30-60 minutes of activity per day
- Example: Teacher, retail worker, casual gym-goer

**Athletic 🏃**
- High physical activity or intense training
- 60+ minutes of activity per day
- Example: Construction worker, athlete, fitness enthusiast

Tap your selection, then **"Next"** or **"Skip"**.

### Step 5: Choose Your Goal

Select your primary health objective:

**Lose Weight ⬇️**
- Reduce body weight through calorie deficit
- Focus on fat loss and healthy eating

**Keep Healthy ➡️**
- Maintain current weight and fitness level
- Focus on balanced nutrition and activity

**Gain Muscle ⬆️**
- Increase muscle mass through training and nutrition
- Focus on protein intake and strength building

Tap your selection, then **"Next"** or **"Skip"**.

### Step 6: Set Target Weight (If Losing Weight)

If you selected "Lose Weight":

1. **Enter your target weight**
   - Same units as your current weight
   - Should be lower than your current weight
   - Example: 150 lbs (if current is 165 lbs)

2. **Select timeframe**
   - 1-3 months
   - 3-6 months
   - 6-12 months
   - 12+ months

3. Modo will calculate your required daily calorie deficit

Tap **"Next"** to continue or **"Skip"** to skip.

### Step 7: Complete Onboarding

You've completed the onboarding process! Tap **"Get Started"** to enter the main app.

**Note**: You can update all this information later in **Profile** → **Settings**.

---

## Using Modo

### Main Interface Overview

After onboarding, you'll see the **Main Task View**. The app has three main sections accessible via the bottom navigation bar:

1. **Tasks** (Home icon) - Your daily task list
2. **Insights** (Brain icon) - AI-powered insights and Q&A
3. **Profile** (Person icon) - Your profile and settings

---

## Features Guide

### Tasks Screen (Main View)

The Tasks screen is your daily command center.

#### Header Section

**Today's Stats:**
- Greeting: "Welcome back, [Your Name]!"
- Tasks completed: "3/10 tasks"
- Current streak: "5 day streak"
- Daily calories: "1,245/2,000 cal"
- Calendar icon: View different dates

#### Task List

Tasks are organized by category:
- **Diet Tasks** 🥗 (green background)
- **Fitness Tasks** 🏃 (blue background)

Each task displays:
- Task name
- Calories (diet tasks) or duration (fitness tasks)
- Checkbox for completion

#### Adding Tasks

**Manual Task Creation:**

1. Tap **"Add Task"** at the bottom
2. Select task type:
   - **Diet Task** 🥗
   - **Fitness Task** 🏃
3. Fill in details:
   - **Name**: Task description
   - **Calories/Duration**: Amount
      - May search for specific foods for accurate macros
   - **Date**: When to complete (defaults to today)
4. Tap **"Save"**

**AI Tasks :**
- Tap **"AI Tasks"** for personalized recommendations
  - **AI** button on main task page will create tasks for the day
  - Use **AI** for suggestions when adding tasks

#### Completing Tasks

1. **Tap any task** to mark it complete
2. Task is checked off automatically
3. Stats update immediately
4. Contributes to your daily streak

#### Viewing Different Dates

1. Tap the **calendar icon** in header
2. Select a date from the calendar popup
3. View tasks for that day
4. Tap **"Today"** to return to current day

---

### Insights Screen

The Insights screen provides AI-powered health insights and question answering.

#### How to Use

1. Tap **"Insights"** in bottom navigation
2. View the interface with:
   - Question input field
   - Photo upload button (coming soon)
   - Previous insights

#### Asking Questions

1. Tap the text field
2. Type your health question:
   - "What should I eat for breakfast?"
   - "How many calories should I consume?"
   - "What's a good beginner workout?"
3. Tap **"Send"**
4. Wait for AI response

#### Photo Analysis

- Take or upload meal photos
- Get nutritional analysis
- Receive calorie estimates


---

### Profile Screen

Your personal dashboard for settings and progress.

#### Profile Header

Displays:
- Profile picture
- Your name
- Email address

#### Quick Stats

- **Day Streak**: Consecutive days of task completion
- **Daily Calories**: Today's calorie intake

#### Menu Options

**Progress**
- View detailed progress over time
- Track completion rates and trends

**Achievements**
- View earned badges
- See achievement progress
- Unlock new achievements

**Help & Support**
- Access help documentation
- Contact support
- View FAQ

**Settings**
- Update profile information
- Change height, weight, age
- Modify goals and preferences
- Notification settings (coming soon)
- Privacy settings
- Account management

**Sign Out**
- Log out of your account
- Data remains safely stored in cloud

#### Editing Profile

1. Tap **"Settings"**
2. Select information to update
3. Make changes
4. Tap **"Save"**

---

### Navigation

#### Bottom Navigation Bar

- **Tasks** (house icon): Main task view
- **Insights** (brain icon): AI insights

#### In-App Navigation

- **Profile** (person icon): Profile and settings
- **Back Button**: Top-left corner
- **Swipe Gesture**: Swipe from left edge to go back
- **Tab Bar**: Always visible for quick switching

---

## Troubleshooting

### Authentication Issues

#### Can't Sign In

**"Invalid email or password" error:**
- Double-check your credentials
- Ensure Caps Lock is off
- Try "Forgot Password?" link
- For Google Sign-In, verify correct account

**"Email not verified" error:**
- Check email inbox (and spam folder)
- Tap "Resend verification email"
- Wait a few minutes and try again

---

#### App Launch Issues

**App crashes on launch:**
- Restart your device
- Reinstall the app (delete and rebuild)
- Check iOS version (requires 15.0+)
- Clear app data by reinstalling

**Stuck on loading screen:**
- Check internet connection
- Force close and reopen app
- Verify Firebase service status

---

### Task Management Issues

**Tasks not saving:**
- Check internet connection (Firebase required)
- Sign out and sign back in
- Force refresh by pulling down on task list

**Can't mark tasks complete:**
- Ensure tapping directly on the task
- Check for error messages
- Sign out and back in
- Report bug if persists

---

### Onboarding Problems

**Can't proceed past a step:**
- Ensure all required fields are filled correctly
- Check value ranges (age, height, weight)
- Try skipping the problematic step
- Restart app and try again

**Onboarding shows again after completion:**
- Profile wasn't saved properly
- Complete onboarding again without skipping
- Ensure good internet connection
- Report bug if issue persists

---

### Connection Issues

**"Failed to connect to Firebase" error:**
- Check internet connection
- Verify `GoogleService-Info.plist` is in project
- Try signing out and back in
- Reinstall the app

**Google Sign-In not working:**
- Ensure Google account on device
- Check internet connection
- Wait and try again
- Use email/password instead

---

### Performance Issues

**App running slowly:**
- Close other apps to free memory
- Restart your device
- Clear app cache (reinstall)
- Check device storage
- Update iOS to latest version

**High battery usage:**
- Close app when not in use
- Reduce screen brightness
- Check for app updates

---

### Data Sync Issues

**Data not syncing:**
- Check internet connection
- Sign out and sign back in
- Force close and reopen
- Allow up to 60 seconds for sync

**Lost data after update:**
- Sign in with same account
- Wait for cloud sync
- Verify correct email/Google account
- Contact support if data still missing

---

### Getting More Help

If these solutions don't resolve your issue:

1. Check [Known Issues](#known-issues) section
2. Review this troubleshooting guide thoroughly
3. Report a bug following the [Bug Reporting](#reporting-bugs) process
4. Contact support at support@modo-app.com

---

## Reporting Bugs

### Before Reporting

1. **Check known issues**: Review the [Known Issues](#known-issues) section
2. **Try troubleshooting**: Follow the [Troubleshooting](#troubleshooting) guide
3. **Reproduce the issue**: Ensure the bug happens consistently
4. **Gather information**: Note device details and steps to reproduce

### How to Report

#### Option 1: GitHub Issues (Recommended)

1. Go to [github.com/LEOK66/Modo/issues](https://github.com/LEOK66/Modo/issues)
2. Click **"New Issue"**
3. Use the bug report template below
4. Submit

#### Option 2: Email

Send bug reports to: **support@modo-app.com**

### Bug Report Template

```markdown
### Bug Description
[Clear, concise description of the problem]

### Steps to Reproduce
1. [First step]
2. [Second step]
3. [Third step]
4. [Bug occurs]

### Expected Behavior
[What should happen]

### Actual Behavior
[What actually happens]

### Device Information
- **Device Model**: [e.g., iPhone 14 Pro]
- **iOS Version**: [e.g., iOS 16.5]
- **App Version**: [e.g., 1.0.0]
- **Build Number**: [If known]

### Screenshots/Videos
[Attach screenshots or screen recordings if applicable]

### Frequency
- [ ] Happens every time
- [ ] Happens sometimes
- [ ] Happened only once

### Additional Context
[Any other relevant information]
```

### Example Bug Report

```markdown
### Bug Description
App crashes when adding diet task with more than 5000 calories

### Steps to Reproduce
1. Open app and sign in
2. Tap "Add Task"
3. Select "Diet Task"
4. Enter name: "Large meal"
5. Enter calories: 5500
6. Tap "Save"
7. App crashes immediately

### Expected Behavior
Task should save successfully or show error if calories too high

### Actual Behavior
App crashes to home screen without warning

### Device Information
- **Device Model**: iPhone 14 Pro
- **iOS Version**: iOS 16.5
- **App Version**: 1.0.0

### Screenshots
[Screenshot attached]

### Frequency
- [x] Happens every time

### Additional Context
Works fine with calories under 5000
```

### What Happens Next

1. We review reports within 1-3 business days
2. May request additional information
3. Investigate and attempt to reproduce
4. Fix bug and include in next update
5. Notify you when fix is released

### Bug Priority Levels

1. **Critical**: App crashes, data loss, security issues
2. **High**: Major features broken, significant UX issues
3. **Medium**: Minor features broken, cosmetic issues
4. **Low**: Small visual bugs, enhancement requests

---

## Privacy & Security

### Data Protection

- 🔒 **Encryption**: All data encrypted in transit and at rest
- 🔐 **Firebase Security**: Industry-standard security rules
- 🚫 **No Sharing**: We never share your personal health data
- 🛡️ **Secure Authentication**: Strong passwords and Google Sign-In

### Data Collection

**We Collect:**
- Account information (email, name)
- Health data (height, weight, age, goals)
- Usage data (tasks, progress, streaks)
- Anonymous analytics

**We Don't Collect:**
- Location data
- Contact lists
- Photos (until feature is released)

### Your Rights

- **Access**: View all your data in Profile
- **Edit**: Update information anytime
- **Delete**: Request account deletion via support
- **Export**: Data export coming soon

---

## Support & Contact

### Documentation

- **User Manual**: This document
- **Developer Guide**: [DEVELOPER.md](DEVELOPER.md)
- **README**: [README.md](README.md)

### Get Help

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/LEOK66/Modo/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/LEOK66/Modo/discussions)
- 📧 **Email**: support@modo-app.com

### Response Times

- **Critical Bugs**: Within 24 hours
- **General Support**: 2-3 business days
- **Feature Requests**: Reviewed weekly

---

## Glossary

- **Task**: Daily action item for diet or fitness
- **Streak**: Consecutive days of task completion
- **Onboarding**: Initial setup and profile creation
- **Firebase**: Cloud platform for data storage
- **Diet Task**: Task related to eating or calories
- **Fitness Task**: Task related to exercise
- **AI Insights**: Personalized recommendations
- **BMI**: Body Mass Index
- **TDEE**: Total Daily Energy Expenditure
- **Calorie Deficit**: Consuming fewer calories than burned
- **Calorie Surplus**: Consuming more calories than burned

---

## Version History

### Version 1.0.0 (Current)
**Release Date**: January 2025

**Features:**
- User authentication (email/password, Google)
- Task management
- Progress tracking
- Personalized onboarding
- Profile management
- Firebase cloud sync
- AI Features

---

<p align="center">
  <strong>Need more help?</strong><br>
  Visit our <a href="https://github.com/LEOK66/Modo">GitHub repository</a> or email <a href="mailto:support@modo-app.com">support@modo-app.com</a>
</p>

<p align="center">
  <sub>Version 1.0.0 | Last Updated: December 2025</sub>
</p>

---

**End of User Manual**
