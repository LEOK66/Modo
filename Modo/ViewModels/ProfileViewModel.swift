import Foundation
import SwiftUI
import SwiftData
import Combine
import FirebaseAuth
import UIKit
import PhotosUI
import ImageIO

/// ViewModel for managing user profile state and business logic
///
/// This ViewModel handles:
/// - User profile loading and updates
/// - Avatar upload and management
/// - Username editing
/// - Progress data calculation
/// - Logout functionality
final class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Current user profile
    @Published private(set) var userProfile: UserProfile?
    
    /// Display username
    @Published var username: String = "Modor"
    
    /// Temporary username for editing
    @Published var tempUsername: String = "Modor"
    
    /// Progress data (percent, completedDays, targetDays)
    @Published private(set) var progressData: (percent: Double, completedDays: Int, targetDays: Int) = (0.0, 0, 0)
    
    /// Avatar image
    @Published var avatarImage: UIImage? = nil
    
    /// Photo picker item
    @Published var photoPickerItem: PhotosPickerItem? = nil
    
    /// Picked UIImage for cropping
    @Published var pickedUIImage: UIImage? = nil
    
    /// Loading state
    @Published private(set) var isLoading: Bool = false
    
    /// Whether profile is being updated
    @Published private(set) var isUpdating: Bool = false
    
    /// Whether avatar is being uploaded
    @Published private(set) var isUploadingAvatar: Bool = false
    
    /// Error message
    @Published var errorMessage: String? = nil
    
    /// Whether logout confirmation should be shown
    @Published var showLogoutConfirmation: Bool = false
    
    /// Whether edit username alert should be shown
    @Published var showEditUsernameAlert: Bool = false
    
    /// Whether avatar sheet should be shown
    @Published var showAvatarSheet: Bool = false
    
    /// Whether default avatar picker should be shown
    @Published var showDefaultAvatarPicker: Bool = false
    
    /// Whether avatar cropper should be shown
    @Published var showAvatarCropper: Bool = false
    
    /// Whether image too small alert should be shown
    @Published var showImageTooSmallAlert: Bool = false
    
    // MARK: - Private Properties
    
    /// User profile repository for data access
    private let userProfileRepository: UserProfileRepository
    
    /// Auth service for authentication operations
    private let authService: any AuthServiceProtocol
    
    /// Avatar upload service for avatar management
    private let avatarUploadService: AvatarUploadService
    
    /// Progress calculation service
    private let progressService: ProgressCalculationService
    
    /// User profile service (for backward compatibility)
    private weak var userProfileService: UserProfileService?
    
    /// Model context for SwiftData operations
    private let modelContext: ModelContext
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Current user ID
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Initialization
    
    /// Initialize ProfileViewModel
    /// - Parameters:
    ///   - modelContext: Model context for SwiftData (required)
    ///   - userProfileService: User profile service (optional, for backward compatibility)
    ///   - userProfileRepository: User profile repository (defaults to new instance with ServiceContainer dependencies)
    ///   - authService: Auth service (defaults to ServiceContainer.shared.authService)
    ///   - avatarUploadService: Avatar upload service (defaults to new instance)
    ///   - progressService: Progress calculation service (defaults to ProgressCalculationService.shared)
    ///   
    /// Note: If userProfileRepository is not provided, it will be created using:
    /// - modelContext (from parameter)
    /// - databaseService (from ServiceContainer.shared)
    init(
        modelContext: ModelContext,
        userProfileService: UserProfileService? = nil,
        userProfileRepository: UserProfileRepository? = nil,
        authService: AuthServiceProtocol? = nil,
        avatarUploadService: AvatarUploadService = AvatarUploadService(),
        progressService: ProgressCalculationService = ProgressCalculationService.shared
    ) {
        self.modelContext = modelContext
        self.userProfileService = userProfileService
        
        // Get services from ServiceContainer or use provided ones
        let databaseService = ServiceContainer.shared.databaseService
        self.authService = authService ?? ServiceContainer.shared.authService
        self.avatarUploadService = avatarUploadService
        self.progressService = progressService
        
        // Create user profile repository if not provided
        if let repository = userProfileRepository {
            self.userProfileRepository = repository
        } else {
            self.userProfileRepository = UserProfileRepository(
                modelContext: modelContext,
                databaseService: databaseService
            )
        }
        
        // Observe user profile service if available
        setupObservers()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Setup view when it appears
    func onAppear() {
        loadProfile()
        calculateProgress()
    }
    
    /// Cleanup when view disappears
    func onDisappear() {
        // Cleanup if needed
    }
    
    /// Load user profile
    func loadProfile() {
        guard let userId = userId else {
            print("⚠️ ProfileViewModel: No user logged in")
            return
        }
        
        // First, try to get from UserProfileService (if available)
        if let profile = userProfileService?.currentProfile {
            userProfile = profile
            username = profile.username ?? "Modor"
            tempUsername = username
            ensureDefaultAvatarIfNeeded()
            calculateProgress()
            return
        }
        
        isLoading = true
        
        // Try to load from local first (SwiftData)
        if let localProfile = userProfileRepository.fetchLocalProfile(userId: userId) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.userProfile = localProfile
                self.username = localProfile.username ?? "Modor"
                self.tempUsername = self.username
                self.userProfileService?.setProfile(localProfile)
                self.ensureDefaultAvatarIfNeeded()
                self.isLoading = false
                print("✅ ProfileViewModel: Loaded profile from local storage")
            }
            
            // Sync from cloud in background
            syncFromCloud(userId: userId)
        } else {
            // Load from cloud
            syncFromCloud(userId: userId)
        }
    }
    
    /// Update profile
    /// - Parameter profile: Updated user profile
    func updateProfile(_ profile: UserProfile) {
        guard let userId = userId else {
            print("⚠️ ProfileViewModel: No user logged in")
            return
        }
        
        isUpdating = true
        
        // Update local first (SwiftData) - UserProfileRepository handles insert/update
        userProfileRepository.saveLocalProfile(profile)
        
        // Update UserProfileService
        userProfileService?.setProfile(profile)
        
        // Update local state
        userProfile = profile
        username = profile.username ?? "Modor"
        tempUsername = username
        
        // Sync to cloud (Firebase)
        userProfileRepository.saveCloudProfile(profile) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isUpdating = false
                
                switch result {
                case .success:
                    print("✅ ProfileViewModel: Profile updated successfully")
                case .failure(let error):
                    self.errorMessage = "Failed to update profile: \(error.localizedDescription)"
                    print("❌ ProfileViewModel: Failed to update profile - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Update username
    /// - Parameter newUsername: New username
    func updateUsername(_ newUsername: String) {
        guard var profile = userProfile else {
            print("⚠️ ProfileViewModel: No profile to update")
            return
        }
        
        profile.username = newUsername
        updateProfile(profile)
    }
    
    /// Upload avatar image
    /// - Parameter image: Avatar image to upload
    func uploadAvatar(_ image: UIImage) {
        guard let userId = userId else {
            print("⚠️ ProfileViewModel: No user logged in")
            return
        }
        
        isUploadingAvatar = true
        
        avatarUploadService.uploadProfileImage(userId: userId, image: image) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isUploadingAvatar = false
                
                switch result {
                case .success(let imageURLString):
                    // Update profile with new avatar URL
                    if var profile = self.userProfile {
                        profile.profileImageURL = imageURLString
                        self.updateProfile(profile)
                    }
                    print("✅ ProfileViewModel: Avatar uploaded successfully")
                case .failure(let error):
                    self.errorMessage = "Failed to upload avatar: \(error.localizedDescription)"
                    print("❌ ProfileViewModel: Failed to upload avatar - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Set default avatar
    /// - Parameter avatarName: Default avatar name
    func setDefaultAvatar(_ avatarName: String) {
        guard let profile = userProfile else {
            print("⚠️ ProfileViewModel: No profile to update")
            return
        }
        
        profile.avatarName = avatarName
        profile.profileImageURL = nil // Clear custom image URL
        updateProfile(profile)
    }
    
    /// Calculate progress data
    func calculateProgress() {
        guard let profile = userProfile else {
            progressData = (0.0, 0, 0)
            return
        }
        
        // Check if we have minimum data for progress calculation
        guard profile.hasMinimumDataForProgress(),
              let startDate = profile.goalStartDate,
              let targetDays = profile.targetDays else {
            let targetDaysValue = profile.targetDays ?? 0
            progressData = (0.0, 0, targetDaysValue)
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
                // Note: UserProgress update should be handled by the View if needed
                // We don't have direct access to UserProgress here
            }
        }
    }
    
    /// Logout user
    func logout() {
        do {
            try authService.signOut()
            print("✅ ProfileViewModel: User logged out successfully")
        } catch {
            errorMessage = "Failed to logout: \(error.localizedDescription)"
            print("❌ ProfileViewModel: Failed to logout - \(error.localizedDescription)")
        }
    }
    
    /// Show logout confirmation
    func showLogoutConfirmationDialog() {
        showLogoutConfirmation = true
    }
    
    /// Show edit username alert
    func showEditUsernameDialog() {
        tempUsername = username
        showEditUsernameAlert = true
    }
    
    /// Save username from edit dialog
    func saveUsername() {
        guard !tempUsername.isEmpty else {
            errorMessage = "Username cannot be empty"
            return
        }
        
        updateUsername(tempUsername)
        showEditUsernameAlert = false
    }
    
    /// Cancel username edit
    func cancelUsernameEdit() {
        tempUsername = username
        showEditUsernameAlert = false
    }
    
    // MARK: - Computed Properties
    
    /// Display username (with fallback)
    var displayUsername: String {
        if let profile = userProfile, let profileUsername = profile.username, !profileUsername.isEmpty {
            return profileUsername
        }
        return username.isEmpty ? "Modor" : username
    }
    
    /// Days completed text
    var daysCompletedText: String {
        if progressData.targetDays == 0 {
            return "0/0"
        }
        return "\(progressData.completedDays)/\(progressData.targetDays)"
    }
    
    /// Expected calories text
    var expectedCaloriesText: String {
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
    
    /// Avatar name from profile or UserProfileService
    var avatarName: String? {
        userProfile?.avatarName ?? userProfileService?.avatarName
    }
    
    /// Profile image URL from profile or UserProfileService
    var profileImageURL: String? {
        userProfile?.profileImageURL ?? userProfileService?.profileImageURL
    }
    
    /// User email from auth service
    var userEmail: String? {
        authService.currentUser?.email
    }
    
    // MARK: - Private Methods
    
    /// Setup observers
    private func setupObservers() {
        // Observe user profile service if available
        if let userProfileService = userProfileService as? ObservableObject {
            // Note: UserProfileService might not be ObservableObject
            // We'll rely on manual updates for now
        }
        
        // Observe photo picker item
        $photoPickerItem
            .compactMap { $0 }
            .sink { [weak self] item in
                self?.loadPhotoPickerItem(item)
            }
            .store(in: &cancellables)
        
        // Observe day completion changes to recalculate progress
        NotificationCenter.default.publisher(for: .dayCompletionDidChange)
            .sink { [weak self] _ in
                self?.calculateProgress()
            }
            .store(in: &cancellables)
    }
    
    /// Load photo picker item
    private func loadPhotoPickerItem(_ item: PhotosPickerItem) {
        Task { @MainActor in
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    // Downsample for performance and normalize orientation
                    let preview = downsampleAndNormalize(data: data, maxDimension: 2048) ?? (UIImage(data: data) ?? UIImage())
                    pickedUIImage = preview
                    showAvatarCropper = true
                    showAvatarSheet = false // Dismiss action sheet for smoother transition
                }
            } catch {
                errorMessage = "Failed to load image: \(error.localizedDescription)"
                print("❌ ProfileViewModel: Failed to load photo - \(error.localizedDescription)")
            }
        }
    }
    
    /// Downsample and normalize image orientation
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
    
    /// Upload cropped avatar image
    /// - Parameter image: Cropped avatar image
    func uploadCroppedAvatar(_ image: UIImage) async {
        guard let userId = userId else { return }
        
        // Ensure profile exists
        var profile = userProfile
        if profile == nil {
            profile = UserProfile(userId: userId)
            modelContext.insert(profile!)
            do {
                try modelContext.save()
                userProfile = profile
                userProfileService?.setProfile(profile)
                print("✅ ProfileViewModel: Created new profile for avatar upload")
            } catch {
                errorMessage = "Failed to create profile: \(error.localizedDescription)"
                print("❌ ProfileViewModel: Failed to create profile - \(error.localizedDescription)")
                return
            }
        }
        
        guard let profile = profile else { return }
        
        // Enforce minimum resolution 512×512
        if Int(image.size.width) < 512 || Int(image.size.height) < 512 {
            await MainActor.run {
                showImageTooSmallAlert = true
            }
            return
        }
        
        avatarUploadService.uploadProfileImage(userId: userId, image: image) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    let updatedProfile = profile
                    updatedProfile.profileImageURL = url
                    updatedProfile.avatarName = nil
                    updatedProfile.updatedAt = Date()
                    if updatedProfile.username == nil || updatedProfile.username?.isEmpty == true {
                        updatedProfile.username = self.displayUsername
                    }
                    
                    // Update local and sync to cloud
                    self.updateProfile(updatedProfile)
                    self.userProfileService?.setProfile(updatedProfile)
                    print("✅ ProfileViewModel: Avatar uploaded successfully")
                case .failure(let error):
                    self.errorMessage = "Failed to upload avatar: \(error.localizedDescription)"
                    print("❌ ProfileViewModel: Failed to upload avatar - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Apply default avatar
    /// - Parameter name: Default avatar name
    func applyDefaultAvatar(name: String) {
        guard let userId = userId else { return }
        
        // Ensure profile exists
        var profile = userProfile
        if profile == nil {
            profile = UserProfile(userId: userId)
            modelContext.insert(profile!)
            do {
                try modelContext.save()
                userProfile = profile
                userProfileService?.setProfile(profile)
                print("✅ ProfileViewModel: Created new profile for default avatar")
            } catch {
                errorMessage = "Failed to create profile: \(error.localizedDescription)"
                print("❌ ProfileViewModel: Failed to create profile - \(error.localizedDescription)")
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
        
        updateProfile(profile)
        userProfileService?.setProfile(profile)
    }
    
    /// Delete old profile image from Storage
    private func deleteOldProfileImage(userId: String) {
        // Note: This would require Firebase Storage import
        // For now, we'll just clear the URL
        // In a full implementation, you would delete from Storage here
        print("⚠️ ProfileViewModel: Old profile image URL cleared (Storage deletion not implemented)")
    }
    
    /// Ensure default avatar if needed
    func ensureDefaultAvatarIfNeeded() {
        guard let profile = userProfile else { return }
        // If no uploaded photo and no default avatar, assign one
        if (profile.profileImageURL == nil || profile.profileImageURL?.isEmpty == true) &&
            (profile.avatarName == nil || profile.avatarName?.isEmpty == true) {
            if let randomName = DefaultAvatars.random() {
                applyDefaultAvatar(name: randomName)
            }
        }
    }
    
    /// Sync username from UserProfileService
    func syncUsernameFromProfile() {
        if let profile = userProfileService?.currentProfile {
            if let profileUsername = profile.username, !profileUsername.isEmpty {
                if username != profileUsername {
                    username = profileUsername
                    tempUsername = profileUsername
                }
            } else {
                if username != "Modor" {
                    username = "Modor"
                    tempUsername = "Modor"
                }
            }
        }
    }
    
    /// Update profile from UserProfileService
    func updateProfileFromService() {
        if let profile = userProfileService?.currentProfile {
            userProfile = profile
            syncUsernameFromProfile()
        }
    }
    
    /// Sync profile from cloud
    private func syncFromCloud(userId: String) {
        userProfileRepository.syncFromCloud(userId: userId) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let profile):
                    self.userProfile = profile
                    self.username = profile.username ?? "Modor"
                    self.tempUsername = self.username
                    self.userProfileService?.setProfile(profile)
                    self.ensureDefaultAvatarIfNeeded()
                    self.calculateProgress()
                    print("✅ ProfileViewModel: Profile synced from cloud")
                case .failure(let error):
                    self.errorMessage = "Failed to sync profile: \(error.localizedDescription)"
                    print("❌ ProfileViewModel: Failed to sync profile - \(error.localizedDescription)")
                }
            }
        }
    }
}

