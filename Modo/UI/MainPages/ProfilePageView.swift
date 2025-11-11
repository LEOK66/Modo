import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseStorage
import PhotosUI
import UIKit
import AVFoundation
import ImageIO

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
    @State private var showAvatarCropper = false
    @State private var pickedUIImage: UIImage? = nil
    @State private var showImageTooSmallAlert = false
    
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
            .sheet(isPresented: $showAvatarCropper) {
                if let uiImage = pickedUIImage {
                    AvatarCropView(
                        sourceImage: uiImage,
                        onCancel: { showAvatarCropper = false },
                        onConfirm: { cropped in
                            showAvatarCropper = false
                            Task { await uploadCroppedAvatar(cropped) }
                        }
                    )
                }
            }
            .onChange(of: photoPickerItem) { newItem in
                guard let item = newItem else { return }
                // Dismiss the action sheet for a smoother transition
                showAvatarSheet = false
                Task { await preparePickedPhotoForCropping(item: item) }
            }
            .alert("Image too small", isPresented: $showImageTooSmallAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please choose a higher-resolution image (at least 512×512).")
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
        guard let userId = authService.currentUser?.uid else { return }
        
        // ✅ Ensure profile exists - create if missing (e.g., after database migration)
        var profile = userProfileService.currentProfile
        if profile == nil {
            // Create new profile if it doesn't exist
            profile = UserProfile(userId: userId)
            modelContext.insert(profile!)
            do {
                try modelContext.save()
                userProfileService.setProfile(profile)
                print("✅ Created new profile for default avatar")
            } catch {
                print("❌ Failed to create profile: \(error.localizedDescription)")
                return
            }
        }
        
        guard let profile = profile else { return }
        
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

    private func preparePickedPhotoForCropping(item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                print("📸 Loaded photo from picker, size: \(data.count) bytes")
                // Downsample for performance and normalize orientation
                let preview = downsampleAndNormalize(data: data, maxDimension: 2048) ?? (UIImage(data: data) ?? UIImage())
                await MainActor.run {
                    pickedUIImage = preview
                    showAvatarCropper = true
                }
            }
        } catch {
            print("❌ Photo load failed: \(error.localizedDescription)")
        }
    }

    private func downsampleAndNormalize(data: Data, maxDimension: CGFloat) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension)
        ]
        guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { return nil }
        let thumb = UIImage(cgImage: cgThumb)
        // Normalize to .up by redrawing once
        let size = thumb.size
        let renderer = UIGraphicsImageRenderer(size: size)
        let normalized = renderer.image { _ in
            thumb.draw(in: CGRect(origin: .zero, size: size))
        }
        return normalized
    }

    private func uploadCroppedAvatar(_ image: UIImage) async {
        guard let userId = authService.currentUser?.uid else { return }
        
        // ✅ Ensure profile exists - create if missing (e.g., after database migration)
        var profile = userProfileService.currentProfile
        if profile == nil {
            // Create new profile if it doesn't exist
            profile = UserProfile(userId: userId)
            modelContext.insert(profile!)
            do {
                try modelContext.save()
                userProfileService.setProfile(profile)
                print("✅ Created new profile for avatar upload")
            } catch {
                print("❌ Failed to create profile: \(error.localizedDescription)")
                return
            }
        }
        
        guard let profile = profile else { return }
        
        // Enforce minimum resolution 512×512
        if Int(image.size.width) < 512 || Int(image.size.height) < 512 {
            await MainActor.run { showImageTooSmallAlert = true }
            return
        }
        AvatarUploadService.shared.uploadProfileImage(userId: userId, image: image) { result in
            switch result {
            case .success(let url):
                DispatchQueue.main.async {
                    profile.profileImageURL = url
                    profile.avatarName = nil
                    profile.updatedAt = Date()
                    if profile.username == nil || profile.username?.isEmpty == true {
                        profile.username = self.displayUsername
                    }
                    do { try? modelContext.save() }
                    DatabaseService.shared.saveUserProfile(profile) { _ in }
                    userProfileService.setProfile(profile)
                }
            case .failure(let error):
                print("❌ Upload failed: \(error.localizedDescription)")
            }
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

// MARK: - Subviews (Some components extracted to separate files)

// Components extracted to separate files:
// - ProfileHeaderView -> UI/Components/Profile/ProfileHeaderView.swift
// - StatsCardView -> UI/Components/Profile/StatsCardView.swift
// - LogoutRow -> UI/Components/Profile/LogoutRow.swift
// - DefaultAvatarGrid -> UI/Components/Profile/DefaultAvatarGrid.swift
// - AvatarActionSheet -> UI/Components/Profile/AvatarActionSheet.swift
// - LoadingDotsView -> UI/Components/Profile/LoadingDotsView.swift
// - DailyChallengeCardView -> UI/Components/Challenge/DailyChallengeCardView.swift
// - DailyChallengeDetailView -> UI/Components/Challenge/DailyChallengeDetailView.swift
// - View Modifiers -> UI/Components/Profile/ProfileViewModifiers.swift

// ProfileContent extracted to UI/Components/Profile/ProfileContent.swift
// DailyChallengeCardView and DailyChallengeDetailView extracted to UI/Components/Challenge/

#Preview {
    NavigationStack {
        ProfilePageView(isPresented: .constant(true))
            .environmentObject(AuthService.shared)
            .environmentObject(UserProgress())
            .environmentObject(DailyCaloriesService())
            .environmentObject(UserProfileService())
            .modelContainer(for: [UserProfile.self, DailyCompletion.self])
    }
}
