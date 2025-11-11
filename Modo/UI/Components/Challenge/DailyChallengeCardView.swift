import SwiftUI

struct DailyChallengeCardView: View {
    @StateObject private var challengeService = DailyChallengeService.shared
    @EnvironmentObject var userProfileService: UserProfileService
    @State private var showDetailView = false
    @State private var showCompletionToast = false
    @State private var previousCompletionState = false
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 8) {
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
                        .disabled(challengeService.isGeneratingChallenge || challengeService.isChallengeCompleted || challengeService.isChallengeAddedToTasks)
                        .opacity((challengeService.isGeneratingChallenge || challengeService.isChallengeCompleted || challengeService.isChallengeAddedToTasks) ? 0.5 : 1.0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
            
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
                .padding(.bottom, 6)
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
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
                    )
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
                .cornerRadius(22)
                .transition(.opacity)
            }
            
            // Overlay for locked state
            if !challengeService.hasMinimumUserData {
                VStack(spacing: 10) {
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
                .cornerRadius(22)
                .transition(.opacity)
            }
        }
        .frame(width: 327, height: cardHeight)
        .clipped()
        .animation(.easeInOut(duration: 0.3), value: challengeService.hasMinimumUserData)
        .animation(.easeInOut(duration: 0.3), value: challengeService.isGeneratingChallenge)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: challengeService.currentChallenge?.id)
        .onAppear {
            // Update data availability when view appears
            challengeService.updateUserDataAvailability(profile: userProfileService.currentProfile)
            // Load daily challenge when view appears (like image loading)
            challengeService.loadTodayChallenge()
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
    
    private var cardHeight: CGFloat {
        challengeService.hasMinimumUserData ? 120 : 150
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

