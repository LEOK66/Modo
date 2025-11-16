import SwiftUI
import SwiftData
import FirebaseAuth

// MARK: - Delete Account View
struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AuthService
    @State private var isDeleting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showConfirmDialog = false
    
    private let accountService = AccountService.shared
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                PageHeader(title: "Delete Account")
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                
                Spacer().frame(height: 24)
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Warning Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.orange)
                                
                                Text("Warning")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            
                            Text("This action cannot be undone. Deleting your account will permanently remove:")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                DeleteAccountRow(icon: "person.circle", text: "Your profile information")
                                DeleteAccountRow(icon: "list.bullet", text: "All your tasks and activities")
                                DeleteAccountRow(icon: "trophy", text: "Your challenges and progress")
                                DeleteAccountRow(icon: "photo", text: "Your uploaded photos")
                                DeleteAccountRow(icon: "chart.line.uptrend.xyaxis", text: "All your data and history")
                            }
                            .padding(.leading, 8)
                            
                            Text("Once deleted, you will be signed out and unable to recover any of this information.")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        .padding(24)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal, 24)
                        
                        // Delete Button
                        Button {
                            showConfirmDialog = true
                        } label: {
                            HStack {
                                if isDeleting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "trash")
                                    Text("Delete My Account")
                                }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.red)
                            .cornerRadius(16)
                        }
                        .disabled(isDeleting)
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("Delete Account", isPresented: $showConfirmDialog) {
            Button("Cancel", role: .cancel) {
                // User cancelled
            }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
        .overlay(
            ErrorToast(
                message: errorMessage,
                isPresented: showError,
                topInset: 20
            )
        )
    }
    
    private func deleteAccount() {
        guard !isDeleting else { return }
        
        isDeleting = true
        
        accountService.deleteAccount { result in
            DispatchQueue.main.async {
                isDeleting = false
                
                switch result {
                case .success:
                    // Account deleted successfully
                    // Delete local SwiftData before signing out
                    deleteLocalData()
                    
                    // User will be automatically signed out by auth state listener
                    // Navigate back to login screen
                    try? authService.signOut()
                    dismiss()
                    
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showError = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Delete Local Data
    /// Deletes all local SwiftData for the current user
    private func deleteLocalData() {
        guard let currentUserId = authService.currentUser?.uid else {
            print("⚠️ [DeleteAccountView] No current user ID, skipping local data deletion")
            return
        }
        
        print("🗑️ [DeleteAccountView] Deleting local data for user: \(currentUserId)")
        
        // Delete UserProfile
        do {
            let profileDescriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate { profile in
                    profile.userId == currentUserId
                }
            )
            let profiles = try modelContext.fetch(profileDescriptor)
            for profile in profiles {
                modelContext.delete(profile)
            }
            print("✅ [DeleteAccountView] Deleted \(profiles.count) UserProfile(s)")
        } catch {
            print("❌ [DeleteAccountView] Error deleting UserProfile: \(error)")
        }
        
        // Delete FirebaseChatMessage
        do {
            let messageDescriptor = FetchDescriptor<FirebaseChatMessage>(
                predicate: #Predicate { message in
                    message.userId == currentUserId
                }
            )
            let messages = try modelContext.fetch(messageDescriptor)
            for message in messages {
                modelContext.delete(message)
            }
            print("✅ [DeleteAccountView] Deleted \(messages.count) FirebaseChatMessage(s)")
        } catch {
            print("❌ [DeleteAccountView] Error deleting FirebaseChatMessage: \(error)")
        }
        
        // Delete DailyCompletion
        do {
            let completionDescriptor = FetchDescriptor<DailyCompletion>(
                predicate: #Predicate { completion in
                    completion.userId == currentUserId
                }
            )
            let completions = try modelContext.fetch(completionDescriptor)
            for completion in completions {
                modelContext.delete(completion)
            }
            print("✅ [DeleteAccountView] Deleted \(completions.count) DailyCompletion(s)")
        } catch {
            print("❌ [DeleteAccountView] Error deleting DailyCompletion: \(error)")
        }
        
        // Save changes
        do {
            try modelContext.save()
            print("✅ [DeleteAccountView] Saved local data deletions")
        } catch {
            print("❌ [DeleteAccountView] Error saving local data deletions: \(error)")
        }
    }
}

// MARK: - Delete Account Row
private struct DeleteAccountRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        DeleteAccountView()
            .environmentObject(AuthService.shared)
    }
}

