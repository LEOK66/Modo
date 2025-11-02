 import SwiftUI
import FirebaseAuth

struct ProfilePageView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userProgress: UserProgress
    @State private var showLogoutConfirmation = false
    @State private var username: String = "Modor"
    @State private var showEditUsernameAlert = false
    @State private var tempUsername: String = "Modor"
    
    private let databaseService = DatabaseService.shared
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hexString: "F9FAFB").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                PageHeader(title: "Profile")
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                
                Spacer().frame(height: 12)
                
                // Scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Profile header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                                    .frame(width: 96, height: 96)
                                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 10)
                                    .background(
                                        Circle()
                                            .fill(Color(hexString: "F3F4F6"))
                                            .padding(4)
                                    )
                                
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 96, height: 96)
                                    .foregroundStyle(Color.gray.opacity(0.6))
                            }
                            Button(action: {
                                tempUsername = username
                                showEditUsernameAlert = true
                            }) {
                                HStack(spacing: 4) {
                                    Text(username)
                                        .font(.system(size: 24, weight: .regular))
                                        .foregroundColor(Color(hexString: "0A0A0A"))
                                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                        .id(username)  // Force view refresh when username changes
                                    Image(systemName: "pencil")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(hexString: "6A7282"))
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .animation(.easeInOut(duration: 0.3), value: username)
                            
                            Text(authService.currentUser?.email ?? "email@example.com")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hexString: "6A7282"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                        // MARK: - Stats row
                        NavigationLink(destination: ProgressView()) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Progress")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color(hexString: "101828"))
                                    Text("15/30 days")
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
                                        .trim(from: 0, to: userProgress.progressPercent)
                                        .stroke(Color(hexString: "22C55E"), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                        .frame(width: 56, height: 56)
                                    Text("\(Int(userProgress.progressPercent * 100))%")
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
                                            Text("Intake")
                                                .font(.system(size: 11))
                                                .foregroundColor(Color(hexString: "6A7282"))
                                                .multilineTextAlignment(.center)
                                            Text("1850")
                                                .font(.system(size: 22, weight: .semibold))
                                                .foregroundColor(Color(hexString: "101828"))
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(width: 65)
                                        Divider().frame(width: 1, height: 22).padding(.horizontal, 6)
                                        VStack(alignment: .center, spacing: 2) {
                                            Text("Output")
                                                .font(.system(size: 11))
                                                .foregroundColor(Color(hexString: "6A7282"))
                                                .multilineTextAlignment(.center)
                                            Text("450")
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
                        .buttonStyle(PlainButtonStyle())

                        
                        // MARK: - Performance & Achievements section
                        VStack(spacing: 12) {
                            NavigationRow(icon: "rosette", title: "Achievements", subtitle: "Unlock badges", destination: AnyView(AchievementsView()))
                             NavigationRow(icon: "gearshape", title: "Settings", subtitle: "App preferences", destination: AnyView(SettingsView()))
                            NavigationRow(icon: "questionmark.circle", title: "Help & Support", subtitle: "Get assistance", destination: AnyView(HelpSupportView()))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                      // MARK: - Logout
                        Button {
                            showLogoutConfirmation = true
                        } label: {
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
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 24)
                        .alert("Logout", isPresented: $showLogoutConfirmation) {
                            Button("Cancel", role: .cancel) { }
                            Button("Logout", role: .destructive) {
                                performLogout()
                            }
                        } message: {
                            Text("Are you sure you want to logout?")
                        }
                        .alert("Edit Username", isPresented: $showEditUsernameAlert) {
                            TextField("Username", text: $tempUsername)
                            Button("Cancel", role: .cancel) { }
                            Button("Save") {
                                saveUsername()
                            }
                        } message: {
                            Text("Enter your username")
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(hexString: "F3F4F6"))
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            loadUserProfile()
        }
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
    
    private func performLogout() {
        do {
            try authService.signOut()
            // ModoApp will automatically navigate to LoginView
        } catch {
            print("Logout error: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack {
        ProfilePageView()
            .environmentObject(AuthService.shared)
            .environmentObject(UserProgress())
    }
}
