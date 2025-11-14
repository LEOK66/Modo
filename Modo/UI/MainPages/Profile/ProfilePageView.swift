import SwiftUI
import SwiftData
import FirebaseAuth
import PhotosUI

struct ProfilePageView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userProgress: UserProgress
    @EnvironmentObject var dailyCaloriesService: DailyCaloriesService
    @EnvironmentObject var userProfileService: UserProfileService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ProfilePageContentView(
            isPresented: $isPresented,
            modelContext: modelContext,
            userProfileService: userProfileService,
            dailyCaloriesService: dailyCaloriesService
        )
    }
}

// Internal view that manages ViewModel lifecycle
private struct ProfilePageContentView: View {
    @Binding var isPresented: Bool
    let modelContext: ModelContext
    let userProfileService: UserProfileService
    let dailyCaloriesService: DailyCaloriesService
    @EnvironmentObject var userProgress: UserProgress
    
    @StateObject private var viewModel: ProfileViewModel
    @StateObject private var challengeViewModel = DailyChallengeViewModel(
        challengeService: ServiceContainer.shared.challengeService,
        taskRepository: nil
    )
    @Environment(\.dismiss) private var dismiss
    
    init(
        isPresented: Binding<Bool>,
        modelContext: ModelContext,
        userProfileService: UserProfileService,
        dailyCaloriesService: DailyCaloriesService
    ) {
        self._isPresented = isPresented
        self.modelContext = modelContext
        self.userProfileService = userProfileService
        self.dailyCaloriesService = dailyCaloriesService
        
        // Create ViewModel directly with default parameters
        // Repository and services will be created automatically using ServiceContainer
        self._viewModel = StateObject(wrappedValue: ProfileViewModel(
            modelContext: modelContext,
            userProfileService: userProfileService
        ))
    }
    
    var body: some View {
        let content = baseView
            .navigationBarBackButtonHidden(true)
            .onAppear {
                viewModel.onAppear()
                viewModel.updateProfileFromService()
                // Check for date change before loading challenge
                challengeViewModel.checkAndResetForNewDay()
                challengeViewModel.onAppear()
            }
            .onChange(of: userProfileService.currentProfile) { _, newValue in
                if newValue != nil {
                    viewModel.updateProfileFromService()
                    challengeViewModel.updateUserDataAvailability(profile: newValue)
                }
            }
            .onChange(of: viewModel.progressData.percent) { _, newValue in
                // Update UserProgress when progress changes
                userProgress.progressPercent = newValue
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Check for date change when app returns from background
                challengeViewModel.checkAndResetForNewDay()
            }
        
        return content
            .modifier(logoutAlertModifier)
            .modifier(usernameAlertModifier)
            .sheet(isPresented: $viewModel.showAvatarSheet) {
                AvatarActionSheet(
                    onChooseDefault: { viewModel.showDefaultAvatarPicker = true },
                    photoPickerItem: $viewModel.photoPickerItem,
                    onClose: { viewModel.showAvatarSheet = false }
                )
            }
            .sheet(isPresented: $viewModel.showDefaultAvatarPicker) {
                DefaultAvatarGrid(onSelect: { name in
                    viewModel.applyDefaultAvatar(name: name)
                    viewModel.showDefaultAvatarPicker = false
                })
            }
            .sheet(isPresented: $viewModel.showAvatarCropper) {
                if let uiImage = viewModel.pickedUIImage {
                    AvatarCropView(
                        sourceImage: uiImage,
                        onCancel: { viewModel.showAvatarCropper = false },
                        onConfirm: { cropped in
                            viewModel.showAvatarCropper = false
                            Task { await viewModel.uploadCroppedAvatar(cropped) }
                        }
                    )
                }
            }
            .alert("Image too small", isPresented: $viewModel.showImageTooSmallAlert) {
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
        let background = Color(.systemBackground)
        let scrollBackground = Color(.systemBackground)
        
        ZStack(alignment: .top) {
            background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    BackButton {
                        // Handle back button - works for both swipe navigation and button tap
                        if isPresented {
                            withAnimation {
                                isPresented = false
                            }
                        } else {
                            dismiss()
                        }
                    }
                    
                    Spacer()
                    
                    Text("Profile")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.top, 12)
                .padding(.horizontal, 24)
                
                Spacer().frame(height: 12)
                
                ProfileContent(
                    username: viewModel.displayUsername,
                    email: viewModel.userEmail ?? "email@example.com",
                    progressPercent: viewModel.progressData.percent,
                    daysCompletedText: viewModel.daysCompletedText,
                    expectedCaloriesText: viewModel.expectedCaloriesText,
                    currentlyCaloriesText: currentlyCaloriesText,
                    avatarName: viewModel.avatarName,
                    profileImageURL: viewModel.profileImageURL,
                    onEditUsername: {
                        viewModel.showEditUsernameDialog()
                    },
                    onLogoutTap: {
                        viewModel.showLogoutConfirmationDialog()
                    },
                    onEditAvatar: { viewModel.showAvatarSheet = true },
                    challengeViewModel: challengeViewModel
                )
                .background(scrollBackground)
            }
        }
    }
    
    private var logoutAlertModifier: some ViewModifier {
        LogoutAlertModifier(
            isPresented: $viewModel.showLogoutConfirmation,
            onLogout: {
                viewModel.logout()
            }
        )
    }
    
    private var usernameAlertModifier: some ViewModifier {
        UsernameAlertModifier(
            isPresented: $viewModel.showEditUsernameAlert,
            username: $viewModel.tempUsername,
            onSave: {
                viewModel.saveUsername()
            }
        )
    }
    
    // Computed property for current calories
    private var currentlyCaloriesText: String {
        let calories: Int = dailyCaloriesService.todayCalories
        if calories > 0 {
            return String(calories)
        } else {
            return "-"
        }
    }
}

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
