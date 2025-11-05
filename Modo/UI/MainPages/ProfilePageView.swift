import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseStorage
import PhotosUI
import UIKit

struct ProfilePageView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userProgress: UserProgress
    @EnvironmentObject var dailyCaloriesService: DailyCaloriesService
    @EnvironmentObject var userProfileService: UserProfileService
    @Environment(\.modelContext) private var modelContext
    
    @State private var showLogoutConfirmation = false
    @State private var username: String = "Modor"
    @State private var showEditUsernameAlert = false
    @State private var tempUsername: String = "Modor"
    @State private var progressData: (percent: Double, completedDays: Int, targetDays: Int) = (0.0, 0, 0)
    // Avatar editing state
    @State private var showAvatarSheet = false
    @State private var showDefaultAvatarPicker = false
    @State private var photoPickerItem: PhotosPickerItem? = nil
    
    init(isPresented: Binding<Bool> = .constant(false)) {
        self._isPresented = isPresented
    }
    
    // Computed property to get display username - this is evaluated during view rendering
    // so it will use the latest value from userProfileService immediately
    private var displayUsername: String {
        // First priority: use profile service username if available
        // We check the profile exists first, then use its username (even if "Modor")
        // This ensures we use the profile's actual value rather than defaulting
        if let profile = userProfileService.currentProfile {
            // If profile exists, use its username (could be "Modor" if user hasn't changed it)
            if let profileUsername = profile.username, !profileUsername.isEmpty {
                return profileUsername
            }
        }
        
        // Second priority: use local state if it's been set and not default
        // This handles the case where we've loaded from Firebase but profile isn't set yet
        if !username.isEmpty && username != "Modor" {
            return username
        }
        
        // Default fallback - only use if profile doesn't exist or is truly empty
        return "Modor"
    }
    
    
    private let databaseService = DatabaseService.shared
    private let progressService = ProgressCalculationService.shared
    
    
    // Computed properties for display
    private var daysCompletedText: String {
        if progressData.targetDays == 0 {
            return "0/0"
        }
        return "\(progressData.completedDays)/\(progressData.targetDays)"
    }
    
    private var expectedCaloriesText: String {
        guard let profile = userProfileService.currentProfile else { return "-" }
        
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
    
    @Environment(\.dismiss) private var dismiss
    
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
            .onChange(of: userProfileService.currentProfile?.username) { oldValue, newValue in
                // Sync username when profile username changes
                // This ensures local state stays in sync for smooth animations
                syncUsernameFromProfile()
            }
            .onChange(of: userProfileService.currentProfile) { oldValue, newValue in
                // When profile loads (e.g., from SwiftData Query), sync username immediately
                // This handles the case where profile loads asynchronously
                // We update immediately without animation to prevent flash
                if let profile = newValue {
                    if let profileUsername = profile.username, !profileUsername.isEmpty {
                        // Update username immediately to prevent flash
                        username = profileUsername
                        tempUsername = profileUsername
                    }
                }
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
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        let horizontalAmount = value.translation.width
                        let verticalAmount = value.translation.height
                        
                        // Only handle horizontal swipes (ignore vertical)
                        // Swipe from left to right: go back to main page
                        if abs(horizontalAmount) > abs(verticalAmount) && horizontalAmount > 0 {
                            withAnimation {
                                isPresented = false
                            }
                        }
                    }
            )
    }
    
    @ViewBuilder
    private var baseView: some View {
        let background = Color(hexString: "F9FAFB")
        let scrollBackground = Color(hexString: "F3F4F6")
        
        ZStack(alignment: .top) {
            background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    BackButton {
                        // Handle back button - works for both swipe navigation and button tap
                        // Always try isPresented binding first (for swipe/button navigation)
                        // Fall back to dismiss only if isPresented is not active
                        if $isPresented.wrappedValue {
                            // If presented via swipe or button tap (isPresented binding is true)
                            withAnimation {
                                isPresented = false
                            }
                        } else {
                            // Fallback: if isPresented is false, use dismiss (for NavigationLink)
                            dismiss()
                        }
                    }
                    
                    Spacer()
                    
                    Text("Profile")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hexString: "101828"))
                    
                    Spacer()
                    
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.top, 12)
                .padding(.horizontal, 24)
                
                Spacer().frame(height: 12)
                
                ProfileContent(
                    username: displayUsername,
                    email: authService.currentUser?.email ?? "email@example.com",
                    progressPercent: progressData.percent,
                    daysCompletedText: daysCompletedText,
                    expectedCaloriesText: expectedCaloriesText,
                    currentlyCaloriesText: currentlyCaloriesText,
                    avatarName: userProfileService.avatarName,
                    profileImageURL: userProfileService.profileImageURL,
                    onEditUsername: {
                        tempUsername = displayUsername
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
            onAppear: {
                // Initialize username from profile service first (synchronous access)
                // This ensures we have the username ready before first render
                initializeUsername()
                ensureDefaultAvatarIfNeeded()
                loadUserProfile()
                loadProgressData()
            },
            onDataChange: {
                // Update local username when profile changes
                // This keeps local state in sync for animations
                syncUsernameFromProfile()
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
    
    /// Initialize username from profile service (synchronous, for immediate display)
    private func initializeUsername() {
        // Prioritize profile service username if available
        if let profileUsername = userProfileService.currentProfile?.username,
           !profileUsername.isEmpty,
           profileUsername != "Modor" {
            // Only update if different to avoid unnecessary state updates
            if username != profileUsername {
                username = profileUsername
            }
            if tempUsername != profileUsername {
                tempUsername = profileUsername
            }
        } else {
            // If profile doesn't have a custom username, keep current username
            // Don't reset to "Modor" if we already have a custom username
            if username.isEmpty {
                username = "Modor"
            }
        }
    }
    
    /// Sync username from profile service when profile changes
    private func syncUsernameFromProfile() {
        // Always sync with profile if it exists - this keeps local state for animations
        if let profile = userProfileService.currentProfile {
            if let profileUsername = profile.username, !profileUsername.isEmpty {
                // Update local state to match profile (for smooth animations)
                if username != profileUsername {
                    username = profileUsername
                }
            } else {
                // Profile exists but username is nil/empty - use "Modor"
                if username != "Modor" {
                    username = "Modor"
                }
            }
        }
        // If profile doesn't exist yet, keep current username state
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
                    // Update local state if we got a username from Firebase
                    if let fetchedUsername = fetchedUsername, !fetchedUsername.isEmpty {
                        self.username = fetchedUsername
                        // Also sync with profile if it exists
                        if let profile = self.userProfileService.currentProfile {
                            profile.username = fetchedUsername
                            do {
                                try? self.modelContext.save()
                            }
                            self.userProfileService.setProfile(profile)
                        }
                    } else {
                        // If no username in Firebase, check if we have one in local profile
                        self.syncUsernameFromProfile()
                    }
                }
                print("✅ ProfilePageView: Loaded username")
            case .failure(let error):
                print("❌ ProfilePageView: Failed to load username - \(error.localizedDescription)")
                // On failure, still try to sync from local profile
                DispatchQueue.main.async {
                    self.syncUsernameFromProfile()
                }
            }
        }
    }
    
    private func saveUsername() {
        guard let userId = authService.currentUser?.uid,
              let profile = userProfileService.currentProfile else {
            print("⚠️ ProfilePageView: No user logged in or no profile")
            return
        }
        
        // Store previous value for rollback
        let previousUsername = displayUsername
        
        // Update local state and profile immediately
        username = tempUsername
        profile.username = tempUsername
        profile.updatedAt = Date()
        
        // Save to SwiftData
        do {
            try modelContext.save()
        } catch {
            print("❌ ProfilePageView: Failed to save username to SwiftData - \(error.localizedDescription)")
        }
        
        // Update the shared service
        userProfileService.setProfile(profile)
        
        // Save to Firebase
        databaseService.updateUsername(userId: userId, username: tempUsername) { result in
            switch result {
            case .success:
                print("✅ ProfilePageView: Username saved successfully")
            case .failure(let error):
                print("❌ ProfilePageView: Failed to save username to Firebase - \(error.localizedDescription)")
                // Revert on failure
                DispatchQueue.main.async {
                    self.username = previousUsername
                    profile.username = previousUsername
                    do {
                        try? self.modelContext.save()
                    }
                    self.userProfileService.setProfile(profile)
                }
            }
        }
    }

    private func ensureDefaultAvatarIfNeeded() {
        guard let profile = userProfileService.currentProfile else { return }
        // If no uploaded photo and no default avatar, assign one
        if (profile.profileImageURL == nil || profile.profileImageURL?.isEmpty == true) &&
            (profile.avatarName == nil || profile.avatarName?.isEmpty == true) {
            if let randomName = DefaultAvatars.random() {
                profile.avatarName = randomName
                profile.updatedAt = Date()
                do { try modelContext.save() } catch { print("Save error: \(error.localizedDescription)") }
                DatabaseService.shared.saveUserProfile(profile) { _ in }
                // Refresh the shared service
                userProfileService.setProfile(profile)
            }
        }
    }

    private func applyDefaultAvatar(name: String) {
        guard let profile = userProfileService.currentProfile, let userId = authService.currentUser?.uid else { return }
        profile.avatarName = name
        // Clear uploaded photo URL so default avatar can be displayed
        if profile.profileImageURL != nil {
            profile.profileImageURL = nil
            // Optionally delete the old photo from Storage to save space
            deleteOldProfileImage(userId: userId)
        }
        profile.updatedAt = Date()
        // Preserve username when changing avatar
        if profile.username == nil || profile.username?.isEmpty == true {
            profile.username = displayUsername
        }
        do { try modelContext.save() } catch { print("Save error: \(error.localizedDescription)") }
        DatabaseService.shared.saveUserProfile(profile) { _ in }
        // Refresh the shared service
        userProfileService.setProfile(profile)
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
        guard let profile = userProfileService.currentProfile, let userId = authService.currentUser?.uid else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                print("📸 Loaded photo from picker, size: \(data.count) bytes")
                AvatarUploadService.shared.uploadProfileImage(userId: userId, image: image) { result in
                    switch result {
                    case .success(let url):
                        DispatchQueue.main.async {
                            profile.profileImageURL = url
                            // Clear default avatar when uploading custom photo
                            profile.avatarName = nil
                            profile.updatedAt = Date()
                            // Preserve username when changing avatar
                            if profile.username == nil || profile.username?.isEmpty == true {
                                profile.username = self.displayUsername
                            }
                            do { try? modelContext.save() }
                            DatabaseService.shared.saveUserProfile(profile) { _ in }
                            // Refresh the shared service
                            userProfileService.setProfile(profile)
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
        guard let profile = userProfileService.currentProfile else {
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
    @EnvironmentObject var userProfileService: UserProfileService
    let onAppear: () -> Void
    let onDataChange: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                onAppear()
            }
            .modifier(UserProfileChangeModifier(onDataChange: onDataChange))
    }
}

private struct UserProfileChangeModifier: ViewModifier {
    @EnvironmentObject var userProfileService: UserProfileService
    let onDataChange: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: userProfileService.currentProfile?.goalStartDate) { oldValue, newValue in
                guard userProfileService.currentProfile != nil, oldValue != newValue else { return }
                onDataChange()
            }
            .onChange(of: userProfileService.currentProfile?.targetDays) { oldValue, newValue in
                guard userProfileService.currentProfile != nil, oldValue != newValue else { return }
                onDataChange()
            }
            .onChange(of: userProfileService.currentProfile?.goal) { _, _ in
                onDataChange()
            }
            .modifier(ProfileMetricsChangeModifier(onDataChange: onDataChange))
    }
}

private struct ProfileMetricsChangeModifier: ViewModifier {
    @EnvironmentObject var userProfileService: UserProfileService
    let onDataChange: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: userProfileService.currentProfile?.heightValue) { _, _ in
                onDataChange()
            }
            .onChange(of: userProfileService.currentProfile?.weightValue) { _, _ in
                onDataChange()
            }
            .onChange(of: userProfileService.currentProfile?.dailyCalories) { _, _ in
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

private struct DailyChallengeCardView: View {
    @StateObject private var challengeService = DailyChallengeService.shared
    @EnvironmentObject var userProfileService: UserProfileService
    @State private var showDetailView = false
    @State private var showCompletionToast = false
    @State private var previousCompletionState = false
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                // Header with buttons
                HStack {
                    Text("Today's Challenge")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hexString: "6B7280"))
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // Add to tasks button
                        Button(action: {
                            if !challengeService.isChallengeAddedToTasks {
                                addChallengeToTasks()
                            }
                        }) {
                            Image(systemName: challengeService.isChallengeAddedToTasks ? "checkmark" : "plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(challengeService.isChallengeAddedToTasks ? Color(hexString: "22C55E") : Color(hexString: "8B5CF6"))
                        }
                        .disabled(challengeService.isChallengeAddedToTasks || challengeService.isGeneratingChallenge || challengeService.isChallengeCompleted)
                        .opacity((challengeService.isChallengeAddedToTasks || challengeService.isGeneratingChallenge || challengeService.isChallengeCompleted) ? 0.5 : 1.0)
                        
                        // Refresh button
                        Button(action: {
                            Task {
                                await challengeService.generateAIChallenge(userProfile: userProfileService.currentProfile)
                            }
                        }) {
                            Image(systemName: challengeService.isChallengeCompleted ? "checkmark.circle.fill" : "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(challengeService.isChallengeCompleted ? Color(hexString: "22C55E") : Color(hexString: "8B5CF6"))
                                .rotationEffect(.degrees(challengeService.isGeneratingChallenge ? 360 : 0))
                                .animation(
                                    challengeService.isGeneratingChallenge ?
                                    Animation.linear(duration: 1).repeatForever(autoreverses: false) :
                                        .default,
                                    value: challengeService.isGeneratingChallenge
                                )
                        }
                        .disabled(challengeService.isGeneratingChallenge || challengeService.isChallengeCompleted)
                        .opacity((challengeService.isGeneratingChallenge || challengeService.isChallengeCompleted) ? 0.5 : 1.0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
                // Challenge content with transition
                HStack(spacing: 12) {
                    // Challenge icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(challengeService.isChallengeCompleted ? Color(hexString: "DCFCE7") : Color(hexString: "EDE9FE"))
                            .frame(width: 48, height: 48)
                        
                        if challengeService.isChallengeCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hexString: "22C55E"))
                        } else {
                            Text(challengeService.currentChallenge?.emoji ?? "👟")
                                .font(.system(size: 24))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(challengeService.currentChallenge?.title ?? "Loading...")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(hexString: "111827"))
                            .lineLimit(1)
                        
                        if challengeService.isChallengeCompleted {
                            Text("Completed! Great job! 🎉")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hexString: "22C55E"))
                        } else if challengeService.isChallengeAddedToTasks {
                            Text("Added to your tasks")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hexString: "6B7280"))
                        } else if let subtitle = challengeService.currentChallenge?.subtitle {
                            Text(subtitle)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hexString: "6B7280"))
                                .lineLimit(2)
                        } else {
                            Text("Tap + to add to tasks")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hexString: "6B7280"))
                        }
                    }
                    
                    Spacer()
                    
                    // Chevron indicator for detail view
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hexString: "9CA3AF"))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .id(challengeService.currentChallenge?.id)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
                .contentShape(Rectangle())
                .onTapGesture {
                    if challengeService.hasMinimumUserData && !challengeService.isGeneratingChallenge {
                        showDetailView = true
                    }
                }
            }
            .blur(radius: challengeService.hasMinimumUserData ? 0 : 8)
            .opacity(challengeService.isGeneratingChallenge ? 0.5 : 1.0)
            .disabled(!challengeService.hasMinimumUserData || challengeService.isGeneratingChallenge)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            
            // Loading overlay with custom animation
            if challengeService.isGeneratingChallenge {
                VStack(spacing: 16) {
                    // Custom loading animation
                    LoadingDotsView()
                    
                    Text("Generating your challenge...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hexString: "8B5CF6"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.95))
                .cornerRadius(16)
                .transition(.opacity)
            }
            
            // Overlay for locked state
            if !challengeService.hasMinimumUserData {
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hexString: "8B5CF6"))
                    
                    Text("Start Your Challenge")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hexString: "111827"))
                    
                    Text("Please add your health data in Progress")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "6B7280"))
                        .multilineTextAlignment(.center)
                    
                    NavigationLink(destination: ProgressView()) {
                        Text("Go to Setup")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color(hexString: "8B5CF6"))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.95))
                .cornerRadius(16)
                .transition(.opacity)
            }
        }
        .frame(width: 327, height: 160)
        .clipped()
        .animation(.easeInOut(duration: 0.3), value: challengeService.hasMinimumUserData)
        .animation(.easeInOut(duration: 0.3), value: challengeService.isGeneratingChallenge)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: challengeService.currentChallenge?.id)
        .onAppear {
            // Update data availability when view appears
            challengeService.updateUserDataAvailability(profile: userProfileService.currentProfile)
        }
        .onChange(of: userProfileService.currentProfile) { _, newProfile in
            // Update when profile changes
            challengeService.updateUserDataAvailability(profile: newProfile)
        }
        .onChange(of: challengeService.isChallengeCompleted) { oldValue, newValue in
            // Show toast when challenge is completed
            if !previousCompletionState && newValue {
                showCompletionToast = true
                // Add haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Auto hide toast after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showCompletionToast = false
                }
            }
            previousCompletionState = newValue
        }
        .sheet(isPresented: $showDetailView) {
            DailyChallengeDetailView(
                challenge: challengeService.currentChallenge,
                isCompleted: challengeService.isChallengeCompleted,
                isAddedToTasks: challengeService.isChallengeAddedToTasks,
                onAddToTasks: {
                    showDetailView = false
                    addChallengeToTasks()
                }
            )
        }
        .overlay(alignment: .top) {
            // Completion Toast
            if showCompletionToast {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hexString: "F59E0B"))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("挑战完成！")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hexString: "111827"))
                            
                            Text("太棒了！你完成了今日挑战！🎉")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hexString: "6B7280"))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 5)
                    )
                }
                .padding(.top, -80)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .zIndex(1000)
            }
        }
    }
    
    /// Add challenge to task list
    private func addChallengeToTasks() {
        guard let challenge = challengeService.currentChallenge else {
            print("⚠️ No challenge to add")
            return
        }
        
        // Add animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            challengeService.addChallengeToTasks { taskId in
                guard let taskId = taskId else {
                    print("❌ Failed to add challenge to tasks")
                    return
                }
                
                // Post notification to MainPageView to create task
                let userInfo: [String: Any] = [
                    "taskId": taskId.uuidString,
                    "title": challenge.title,
                    "subtitle": challenge.subtitle,
                    "emoji": challenge.emoji,
                    "category": "fitness",
                    "type": challenge.type.rawValue,
                    "targetValue": challenge.targetValue
                ]
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("AddDailyChallengeTask"),
                    object: nil,
                    userInfo: userInfo
                )
                
                print("✅ Posted notification to add daily challenge task")
            }
        }
    }
}

// MARK: - Loading Dots Animation
private struct LoadingDotsView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color(hexString: "8B5CF6"))
                    .frame(width: 12, height: 12)
                    .offset(y: animationOffset)
                    .animation(
                        Animation
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            animationOffset = -10
        }
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

                // MARK: - Daily Challenge
                DailyChallengeCardView()
                    .frame(maxWidth: .infinity, alignment: .center)

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

// MARK: - Daily Challenge Detail View

private struct DailyChallengeDetailView: View {
    let challenge: DailyChallenge?
    let isCompleted: Bool
    let isAddedToTasks: Bool
    let onAddToTasks: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Challenge header with icon
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isCompleted ? Color(hexString: "DCFCE7") : Color(hexString: "EDE9FE"))
                                .frame(width: 80, height: 80)
                            
                            if isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color(hexString: "22C55E"))
                            } else {
                                Text(challenge?.emoji ?? "👟")
                                    .font(.system(size: 40))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Today's Challenge")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hexString: "6B7280"))
                            
                            if isCompleted {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hexString: "22C55E"))
                                    Text("Completed")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hexString: "22C55E"))
                                }
                            } else if isAddedToTasks {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hexString: "8B5CF6"))
                                    Text("Added to Tasks")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hexString: "8B5CF6"))
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    
                    Divider()
                        .padding(.horizontal, 24)
                    
                    // Challenge details
                    VStack(alignment: .leading, spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Challenge")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hexString: "6B7280"))
                            
                            Text(challenge?.title ?? "Loading...")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hexString: "111827"))
                        }
                        
                        // Subtitle/Description
                        if let subtitle = challenge?.subtitle, !subtitle.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hexString: "6B7280"))
                                
                                Text(subtitle)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hexString: "374151"))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        // Challenge type and target
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Details")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hexString: "6B7280"))
                            
                            HStack(spacing: 16) {
                                // Type badge
                                HStack(spacing: 8) {
                                    Image(systemName: typeIcon)
                                        .font(.system(size: 14))
                                        .foregroundColor(typeColor)
                                    
                                    Text(typeText)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(hexString: "374151"))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(typeColor.opacity(0.1))
                                )
                                
                                // Target value
                                if let targetValue = challenge?.targetValue, targetValue > 0 {
                                    HStack(spacing: 8) {
                                        Image(systemName: "target")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(hexString: "8B5CF6"))
                                        
                                        Text("\(targetValue) \(targetUnit)")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hexString: "374151"))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(hexString: "8B5CF6").opacity(0.1))
                                    )
                                }
                            }
                        }
                        
                        // Tips section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hexString: "F59E0B"))
                                
                                Text("Tips")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hexString: "6B7280"))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                TipRow(icon: "checkmark.circle", text: "Complete this challenge to earn bonus points")
                                TipRow(icon: "star.fill", text: "Track your progress in the main tasks view")
                                TipRow(icon: "trophy.fill", text: "Daily challenges help build healthy habits")
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hexString: "FFFBEB"))
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .background(Color(hexString: "F9FAFB"))
            .navigationTitle("Challenge Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hexString: "6B7280"))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isAddedToTasks && !isCompleted {
                        Button {
                            onAddToTasks()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Add")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color(hexString: "8B5CF6"), Color(hexString: "6366F1")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
    
    private var typeText: String {
        switch challenge?.type {
        case .fitness: return "Fitness"
        case .diet: return "Nutrition"
        case .mindfulness: return "Mindfulness"
        case .other, .none: return "Challenge"
        }
    }
    
    private var typeIcon: String {
        switch challenge?.type {
        case .fitness: return "figure.run"
        case .diet: return "leaf.fill"
        case .mindfulness: return "brain.head.profile"
        case .other, .none: return "star.fill"
        }
    }
    
    private var typeColor: Color {
        switch challenge?.type {
        case .fitness: return Color(hexString: "8B5CF6")
        case .diet: return Color(hexString: "22C55E")
        case .mindfulness: return Color(hexString: "3B82F6")
        case .other, .none: return Color(hexString: "F59E0B")
        }
    }
    
    private var targetUnit: String {
        switch challenge?.type {
        case .fitness: return "steps"
        case .diet: return "cal"
        case .mindfulness: return "min"
        case .other, .none: return ""
        }
    }
}

// MARK: - Tip Row Component

private struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(hexString: "F59E0B"))
                .frame(width: 16)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color(hexString: "374151"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        ProfilePageView(isPresented: .constant(true))
            .environmentObject(AuthService.shared)
            .environmentObject(UserProgress())
            .environmentObject(DailyCaloriesService())
            .modelContainer(for: [UserProfile.self, DailyCompletion.self])
    }
}
