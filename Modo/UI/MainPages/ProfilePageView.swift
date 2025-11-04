import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseStorage
import PhotosUI
import UIKit

struct ProfilePageView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userProgress: UserProgress
    @EnvironmentObject var dailyCaloriesService: DailyCaloriesService
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    @State private var showLogoutConfirmation = false
    @State private var username: String = "Modor"
    @State private var showEditUsernameAlert = false
    @State private var tempUsername: String = "Modor"
    @State private var progressData: (percent: Double, completedDays: Int, targetDays: Int) = (0.0, 0, 0)
    // Avatar editing state
    @State private var showAvatarSheet = false
    @State private var showDefaultAvatarPicker = false
    @State private var photoPickerItem: PhotosPickerItem? = nil
    
    
    private let databaseService = DatabaseService.shared
    private let progressService = ProgressCalculationService.shared
    
    // Get current user's profile
    private var userProfile: UserProfile? {
        guard let userId = authService.currentUser?.uid else { return nil }
        return profiles.first { $0.userId == userId }
    }
    
    // Computed properties for display
    private var daysCompletedText: String {
        if progressData.targetDays == 0 {
            return "0/0"
        }
        return "\(progressData.completedDays)/\(progressData.targetDays)"
    }
    
    private var expectedCaloriesText: String {
        guard let profile = userProfile else { return "-" }
        
        // Check if we have data to calculate calories
        guard profile.hasDataForCaloriesCalculation() || profile.dailyCalories != nil else {
            return "-"
        }
        
        // Convert units if needed
        let weightKg: Double? = {
            guard let value = profile.weightValue,
                  let unit = profile.weightUnit else { return nil }
            return HealthCalculator.convertWeightToKg(value, unit: unit)
        }()
        
        let heightCm: Double? = {
            guard let value = profile.heightValue,
                  let unit = profile.heightUnit else { return nil }
            return HealthCalculator.convertHeightToCm(value, unit: unit)
        }()
        
        // Ensure goal is not empty
        guard let goal = profile.goal, !goal.isEmpty else {
            return "-"
        }
        
        guard let calories = HealthCalculator.targetCalories(
            goal: goal,
            age: profile.age,
            genderCode: profile.gender,
            weightKg: weightKg,
            heightCm: heightCm,
            lifestyleCode: profile.lifestyle,
            userInputCalories: profile.dailyCalories
        ) else {
            return "-"
        }
        
        return "\(calories)"
    }
    
    private var currentlyCaloriesText: String {
        let calories: Int = dailyCaloriesService.todayCalories
        if calories > 0 {
            return String(calories)
        } else {
            return "-"
        }
    }
    
    var body: some View {
        let content = baseView
            .navigationBarBackButtonHidden(true)
            .modifier(profileDataChangeModifier)
        
        return content
            .modifier(logoutAlertModifier)
            .modifier(usernameAlertModifier)
            .onReceive(NotificationCenter.default.publisher(for: .dayCompletionDidChange)) { _ in
                loadProgressData()
            }
            .sheet(isPresented: $showAvatarSheet) {
                AvatarActionSheet(
                    onChooseDefault: { showDefaultAvatarPicker = true },
                    photoPickerItem: $photoPickerItem,
                    onClose: { showAvatarSheet = false }
                )
            }
            .sheet(isPresented: $showDefaultAvatarPicker) {
                DefaultAvatarGrid(onSelect: { name in
                    applyDefaultAvatar(name: name)
                    showDefaultAvatarPicker = false
                })
            }
            .onChange(of: photoPickerItem) { newItem in
                guard let item = newItem else { return }
                // Dismiss the action sheet for a smoother transition
                showAvatarSheet = false
                Task { await handlePhotoPicked(item: item) }
            }
    }
    
    @ViewBuilder
    private var baseView: some View {
        let background = Color(hexString: "F9FAFB")
        let scrollBackground = Color(hexString: "F3F4F6")
        
        ZStack(alignment: .top) {
            background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                PageHeader(title: "Profile")
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                
                Spacer().frame(height: 12)
                
                ProfileContent(
                    username: username,
                    email: authService.currentUser?.email ?? "email@example.com",
                    progressPercent: progressData.percent,
                    daysCompletedText: daysCompletedText,
                    expectedCaloriesText: expectedCaloriesText,
                    currentlyCaloriesText: currentlyCaloriesText,
                    avatarName: userProfile?.avatarName,
                    profileImageURL: userProfile?.profileImageURL,
                    onEditUsername: {
                        tempUsername = username
                        showEditUsernameAlert = true
                    },
                    onLogoutTap: {
                        showLogoutConfirmation = true
                    },
                    onEditAvatar: { showAvatarSheet = true }
                )
                .background(scrollBackground)
            }
        }
    }
    
    private var profileDataChangeModifier: some ViewModifier {
        ProfileDataChangeModifier(
            profiles: profiles,
            userProfile: userProfile,
            onAppear: {
                ensureDefaultAvatarIfNeeded()
                loadUserProfile()
                loadProgressData()
            },
            onDataChange: {
                loadProgressData()
            }
        )
    }
    
    private var logoutAlertModifier: some ViewModifier {
        LogoutAlertModifier(isPresented: $showLogoutConfirmation, onLogout: performLogout)
    }
    
    private var usernameAlertModifier: some ViewModifier {
        UsernameAlertModifier(isPresented: $showEditUsernameAlert, username: $tempUsername, onSave: saveUsername)
    }
    
    private func loadUserProfile() {
        guard let userId = authService.currentUser?.uid else {
            print("⚠️ ProfilePageView: No user logged in")
            return
        }
        
        databaseService.fetchUsername(userId: userId) { result in
            switch result {
            case .success(let fetchedUsername):
                DispatchQueue.main.async {
                    if let fetchedUsername = fetchedUsername, !fetchedUsername.isEmpty {
                        self.username = fetchedUsername
                    }
                }
                print("✅ ProfilePageView: Loaded username")
            case .failure(let error):
                print("❌ ProfilePageView: Failed to load username - \(error.localizedDescription)")
            }
        }
    }
    
    private func saveUsername() {
        guard let userId = authService.currentUser?.uid else {
            print("⚠️ ProfilePageView: No user logged in")
            return
        }
        
        // Store previous value for rollback
        let previousUsername = username
        
        // Update local state with animation
        withAnimation(.easeInOut(duration: 0.3)) {
            username = tempUsername
        }
        
        // Save to database
        databaseService.updateUsername(userId: userId, username: tempUsername) { result in
            switch result {
            case .success:
                print("✅ ProfilePageView: Username saved successfully")
            case .failure(let error):
                print("❌ ProfilePageView: Failed to save username - \(error.localizedDescription)")
                // Revert on failure
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.username = previousUsername
                    }
                }
            }
        }
    }

    private func ensureDefaultAvatarIfNeeded() {
        guard let profile = userProfile else { return }
        // If no uploaded photo and no default avatar, assign one
        if (profile.profileImageURL == nil || profile.profileImageURL?.isEmpty == true) &&
            (profile.avatarName == nil || profile.avatarName?.isEmpty == true) {
            if let randomName = DefaultAvatars.random() {
                profile.avatarName = randomName
                profile.updatedAt = Date()
                do { try modelContext.save() } catch { print("Save error: \(error.localizedDescription)") }
                DatabaseService.shared.saveUserProfile(profile) { _ in }
            }
        }
    }

    private func applyDefaultAvatar(name: String) {
        guard let profile = userProfile, let userId = authService.currentUser?.uid else { return }
        profile.avatarName = name
        // Clear uploaded photo URL so default avatar can be displayed
        if profile.profileImageURL != nil {
            profile.profileImageURL = nil
            // Optionally delete the old photo from Storage to save space
            deleteOldProfileImage(userId: userId)
        }
        profile.updatedAt = Date()
        do { try modelContext.save() } catch { print("Save error: \(error.localizedDescription)") }
        DatabaseService.shared.saveUserProfile(profile) { _ in }
    }
    
    private func deleteOldProfileImage(userId: String) {
        let storageRef = Storage.storage().reference().child("users/\(userId)/profile.jpg")
        storageRef.delete { error in
            if let error = error {
                print("⚠️ Failed to delete old profile image: \(error.localizedDescription)")
            } else {
                print("✅ Deleted old profile image from Storage")
            }
        }
    }

    private func handlePhotoPicked(item: PhotosPickerItem) async {
        guard let profile = userProfile, let userId = authService.currentUser?.uid else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                print("📸 Loaded photo from picker, size: \(data.count) bytes")
                AvatarUploadService.shared.uploadProfileImage(userId: userId, image: image) { result in
                    switch result {
                    case .success(let url):
                        DispatchQueue.main.async {
                            profile.profileImageURL = url
                            profile.updatedAt = Date()
                            do { try? modelContext.save() }
                            DatabaseService.shared.saveUserProfile(profile) { _ in }
                        }
                    case .failure(let error):
                        print("❌ Upload failed: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("❌ Photo load failed: \(error.localizedDescription)")
        }
    }
    
    private func performLogout() {
        do {
            try authService.signOut()
            // ModoApp will automatically navigate to LoginView
        } catch {
            print("Logout error: \(error.localizedDescription)")
        }
    }
    
    private func loadProgressData() {
        guard let profile = userProfile else {
            if progressData != (0.0, 0, 0) || userProgress.progressPercent != 0.0 {
                DispatchQueue.main.async {
                    self.progressData = (0.0, 0, 0)
                    self.userProgress.progressPercent = 0.0
                }
            }
            return
        }
        
        // Check if we have minimum data for progress calculation
        guard profile.hasMinimumDataForProgress(),
              let startDate = profile.goalStartDate,
              let targetDays = profile.targetDays else {
            let targetDaysValue = profile.targetDays ?? 0
            if progressData != (0.0, 0, targetDaysValue) || userProgress.progressPercent != 0.0 {
                DispatchQueue.main.async {
                    self.progressData = (0.0, 0, targetDaysValue)
                    self.userProgress.progressPercent = 0.0
                }
            }
            return
        }
        
        Task {
            // Get completed days
            let completedDays = await progressService.getCompletedDays(
                userId: profile.userId,
                startDate: startDate,
                targetDays: targetDays,
                modelContext: modelContext
            )
            
            // Calculate buffer days
            let bufferDays = profile.bufferDays ?? max(3, Int(Double(targetDays) * 0.1))
            
            // Calculate progress
            let progress = progressService.calculateProgress(
                completedDays: completedDays,
                targetDays: targetDays,
                bufferDays: bufferDays
            )
            
            // Update UI on main thread
            await MainActor.run {
                self.progressData = (progress, completedDays, targetDays)
                self.userProgress.progressPercent = progress
            }
        }
    }
}

// MARK: - View Modifiers

private struct ProfileDataChangeModifier: ViewModifier {
    let profiles: [UserProfile]
    let userProfile: UserProfile?
    let onAppear: () -> Void
    let onDataChange: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                onAppear()
            }
            .modifier(ProfilesChangeModifier(profiles: profiles, onDataChange: onDataChange))
            .modifier(UserProfileChangeModifier(userProfile: userProfile, onDataChange: onDataChange))
    }
}

private struct ProfilesChangeModifier: ViewModifier {
    let profiles: [UserProfile]
    let onDataChange: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: profiles.count) { _, _ in
                onDataChange()
            }
    }
}

private struct UserProfileChangeModifier: ViewModifier {
    let userProfile: UserProfile?
    let onDataChange: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: userProfile?.goalStartDate) { oldValue, newValue in
                guard userProfile != nil, oldValue != newValue else { return }
                onDataChange()
            }
            .onChange(of: userProfile?.targetDays) { oldValue, newValue in
                guard userProfile != nil, oldValue != newValue else { return }
                onDataChange()
            }
            .onChange(of: userProfile?.goal) { _, _ in
                onDataChange()
            }
            .modifier(ProfileMetricsChangeModifier(userProfile: userProfile, onDataChange: onDataChange))
    }
}

private struct ProfileMetricsChangeModifier: ViewModifier {
    let userProfile: UserProfile?
    let onDataChange: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: userProfile?.heightValue) { _, _ in
                onDataChange()
            }
            .onChange(of: userProfile?.weightValue) { _, _ in
                onDataChange()
            }
            .onChange(of: userProfile?.dailyCalories) { _, _ in
                onDataChange()
            }
    }
}

private struct LogoutAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onLogout: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Logout", isPresented: $isPresented) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    onLogout()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
    }
}

private struct UsernameAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var username: String
    let onSave: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Edit Username", isPresented: $isPresented) {
                TextField("Username", text: $username)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    onSave()
                }
            } message: {
                Text("Enter your username")
            }
    }
}

// MARK: - Subviews

private struct ProfileHeaderView: View {
    let username: String
    let email: String
    let avatarName: String?
    let profileImageURL: String?
    let onEdit: () -> Void
    let onEditAvatar: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                // Avatar circle background
                Circle()
                    .stroke(Color.black, lineWidth: 2)
                    .frame(width: 96, height: 96)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 10)
                    .background(
                        Circle()
                            .fill(Color(hexString: "F3F4F6"))
                            .padding(4)
                    )

                // Content image
                Group {
                    if let urlString = profileImageURL, let url = URL(string: urlString) {
                        // Use cached image with a neutral placeholder (not the default avatar)
                        // This prevents showing default avatar when user has uploaded a custom image
                        CachedAsyncImage(url: url) {
                            // Use a subtle placeholder that matches the background, not the default avatar
                            // This prevents the flash of default avatar when cached image loads
                            Circle()
                                .fill(Color(hexString: "E5E7EB"))
                                .frame(width: 96, height: 96)
                                .overlay(
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        .foregroundStyle(Color.gray.opacity(0.4))
                                )
                        }
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                    } else if let name = avatarName, !name.isEmpty, UIImage(named: name) != nil {
                        Image(name)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 96)
                            .foregroundStyle(Color.gray.opacity(0.6))
                    }
                }

                // Pencil button
                Button(action: onEditAvatar) {
                    ZStack {
                        Circle().fill(Color.white).frame(width: 28, height: 28)
                        Circle().stroke(Color(hexString: "E5E7EB"), lineWidth: 1).frame(width: 28, height: 28)
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hexString: "6A7282"))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .offset(x: 6, y: 6)
            }
            Button(action: onEdit) {
                HStack(spacing: 4) {
                    Text(username)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(Color(hexString: "0A0A0A"))
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .id(username)
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hexString: "6A7282"))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .animation(.easeInOut(duration: 0.3), value: username)
            
            Text(email)
                .font(.system(size: 14))
                .foregroundColor(Color(hexString: "6A7282"))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Default avatar grid picker
private struct DefaultAvatarGrid: View {
    let onSelect: (String) -> Void
    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(DefaultAvatars.all, id: \.self) { name in
                        Button {
                            onSelect(name)
                        } label: {
                            Image(name)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color(hexString: "E5E7EB"), lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(20)
            }
            .navigationTitle("Choose Avatar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Avatar action sheet (bottom sheet)
private struct AvatarActionSheet: View {
    let onChooseDefault: () -> Void
    @Binding var photoPickerItem: PhotosPickerItem?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Color(hexString: "E5E7EB")).frame(width: 36, height: 5).padding(.top, 8)
            Text("Change avatar").font(.system(size: 17, weight: .semibold))
            VStack(spacing: 12) {
                Button(action: { onChooseDefault(); onClose() }) {
                    HStack {
                        Image(systemName: "person.circle").foregroundColor(Color(hexString: "364153"))
                        Text("Choose default avatar")
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(Color(hexString: "99A1AF"))
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hexString: "F9FAFB")))
                }
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle").foregroundColor(Color(hexString: "364153"))
                        Text("Upload picture")
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(Color(hexString: "99A1AF"))
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hexString: "F9FAFB")))
                }
                Button(role: .cancel, action: { onClose() }) {
                    Text("Cancel").frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 8)
        }
        .presentationDetents([.height(240), .medium])
    }
}

private struct StatsCardView: View {
    let progressPercent: Double
    let daysCompletedText: String
    let expectedCaloriesText: String
    let currentlyCaloriesText: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Progress")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hexString: "101828"))
                Text(daysCompletedText)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hexString: "6A7282"))
            }
            .frame(width: 66, alignment: .leading)
            .padding(.leading, 8)

            ZStack {
                Circle()
                    .stroke(Color(hexString: "E5E7EB"), lineWidth: 8)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: progressPercent)
                    .stroke(Color(hexString: "22C55E"), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 56, height: 56)
                    .animation(.easeInOut(duration: 0.5), value: progressPercent)
                Text("\(Int(progressPercent * 100))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hexString: "101828"))
            }
            .frame(width: 56, height: 88)
            .padding(.horizontal, 0)

            Rectangle()
                .fill(Color(hexString: "E5E7EB"))
                .frame(width: 1, height: 64)
                .padding(.horizontal, 12)

            VStack(alignment: .center, spacing: 10) {
                Text("Calories")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hexString: "101828"))
                HStack(spacing: 0) {
                    VStack(alignment: .center, spacing: 2) {
                        Text("Expected")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hexString: "6A7282"))
                            .multilineTextAlignment(.center)
                        Text(expectedCaloriesText)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color(hexString: "101828"))
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 65)
                    Divider().frame(width: 1, height: 22).padding(.horizontal, 6)
                    VStack(alignment: .center, spacing: 2) {
                        Text("Currently")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hexString: "6A7282"))
                            .multilineTextAlignment(.center)
                        Text(currentlyCaloriesText)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color(hexString: "101828"))
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 65)
                }
            }
            .padding(.horizontal, 6)
            .padding(.trailing, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
                )
        )
        .frame(width: 327, height: 124)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct LogoutRow: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hexString: "FEF2F2"))
                        .frame(width: 44, height: 44)
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hexString: "E7000B"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Logout")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hexString: "E7000B"))
                    Text("Sign out of your account")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "FF6467"))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(hexString: "FF6467"))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hexString: "FFE2E2"), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 327)
    }
}

// Extracted content to reduce type-checking pressure in main body
private struct ProfileContent: View {
    let username: String
    let email: String
    let progressPercent: Double
    let daysCompletedText: String
    let expectedCaloriesText: String
    let currentlyCaloriesText: String
    let avatarName: String?
    let profileImageURL: String?
    let onEditUsername: () -> Void
    let onLogoutTap: () -> Void
    let onEditAvatar: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Profile header
                ProfileHeaderView(
                    username: username,
                    email: email,
                    avatarName: avatarName,
                    profileImageURL: profileImageURL,
                    onEdit: onEditUsername,
                    onEditAvatar: onEditAvatar
                )
                .padding(.top, 8)

                // MARK: - Stats row
                NavigationLink(destination: ProgressView()) {
                    StatsCardView(
                        progressPercent: progressPercent,
                        daysCompletedText: daysCompletedText,
                        expectedCaloriesText: expectedCaloriesText,
                        currentlyCaloriesText: currentlyCaloriesText
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // MARK: - Performance & Achievements section
                VStack(spacing: 12) {
                    NavigationRow(icon: "rosette", title: "Achievements", subtitle: "Unlock badges", destination: AnyView(AchievementsView()))
                    NavigationRow(icon: "gearshape", title: "Settings", subtitle: "App preferences", destination: AnyView(SettingsView()))
                    NavigationRow(icon: "questionmark.circle", title: "Help & Support", subtitle: "Get assistance", destination: AnyView(HelpSupportView()))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                // MARK: - Logout
                LogoutRow {
                    onLogoutTap()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    NavigationStack {
        ProfilePageView()
            .environmentObject(AuthService.shared)
            .environmentObject(UserProgress())
            .environmentObject(DailyCaloriesService())
            .modelContainer(for: [UserProfile.self, DailyCompletion.self])
    }
}
