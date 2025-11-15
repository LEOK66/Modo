import SwiftUI

struct DailyChallengeCardView: View {
    @ObservedObject var viewModel: DailyChallengeViewModel
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
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // Add to tasks button
                        Button(action: {
                            if !viewModel.isAddedToTasks {
                                addChallengeToTasks()
                            }
                        }) {
                            Image(systemName: viewModel.isAddedToTasks ? "checkmark" : "plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(viewModel.isAddedToTasks ? Color(hexString: "22C55E") : Color(hexString: "8B5CF6"))
                        }
                        .disabled(viewModel.isAddedToTasks || viewModel.isGenerating || viewModel.isCompleted)
                        .opacity((viewModel.isAddedToTasks || viewModel.isGenerating || viewModel.isCompleted) ? 0.5 : 1.0)
                        
                        // Refresh button
                        Button(action: {
                            viewModel.refreshChallenge(userProfile: userProfileService.currentProfile)
                        }) {
                            Image(systemName: viewModel.isCompleted ? "checkmark.circle.fill" : "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(viewModel.isCompleted ? Color(hexString: "22C55E") : Color(hexString: "8B5CF6"))
                                .rotationEffect(.degrees(viewModel.isGenerating ? 360 : 0))
                                .animation(
                                    viewModel.isGenerating ?
                                    Animation.linear(duration: 1).repeatForever(autoreverses: false) :
                                        .default,
                                    value: viewModel.isGenerating
                                )
                        }
                        .disabled(viewModel.isGenerating || viewModel.isCompleted || viewModel.isAddedToTasks)
                        .opacity((viewModel.isGenerating || viewModel.isCompleted || viewModel.isAddedToTasks) ? 0.5 : 1.0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
            
                // Challenge content with transition
                HStack(spacing: 12) {
                    // Challenge icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.isCompleted ? Color(hexString: "DCFCE7") : Color(hexString: "EDE9FE"))
                            .frame(width: 48, height: 48)
                        
                        if viewModel.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hexString: "22C55E"))
                        } else {
                            Text(viewModel.challenge?.emoji ?? "👟")
                                .font(.system(size: 24))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.challenge?.title ?? "Loading...")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if viewModel.isCompleted {
                            Text("Completed! Great job! 🎉")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hexString: "22C55E"))
                        } else if viewModel.isAddedToTasks {
                            Text("Added to your tasks")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        } else if let subtitle = viewModel.challenge?.subtitle {
                            Text(subtitle)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        } else {
                            Text("Tap + to add to tasks")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Chevron indicator for detail view
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
                .id(viewModel.challenge?.id)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
                .contentShape(Rectangle())
                .onTapGesture {
                    if viewModel.hasMinimumUserData && !viewModel.isGenerating {
                        showDetailView = true
                    }
                }
            }
            .blur(radius: viewModel.hasMinimumUserData ? 0 : 8)
            .opacity(viewModel.isGenerating ? 0.5 : 1.0)
            .disabled(!viewModel.hasMinimumUserData || viewModel.isGenerating)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.primary.opacity(0.04), radius: 2, x: 0, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
            )
            
            // Loading overlay with custom animation
            if viewModel.isGenerating {
                VStack(spacing: 16) {
                    // Custom loading animation
                    LoadingDotsView()
                    
                    Text("Generating your challenge...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hexString: "8B5CF6"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground).opacity(0.95))
                .cornerRadius(22)
                .transition(.opacity)
            }
            
            // Overlay for locked state
            if !viewModel.hasMinimumUserData {
                VStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hexString: "8B5CF6"))
                    
                    Text("Start Your Challenge")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Please add your health data in Progress")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
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
                .background(Color(.systemBackground).opacity(0.95))
                .cornerRadius(22)
                .transition(.opacity)
            }
        }
        .frame(width: 327, height: cardHeight)
        .clipped()
        .animation(.easeInOut(duration: 0.3), value: viewModel.hasMinimumUserData)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isGenerating)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.challenge?.id)
        .onAppear {
            // ✅ No need to update data availability - Service automatically observes profile changes
            // Load daily challenge when view appears (like image loading)
            viewModel.loadTodayChallenge()
        }
        .onChange(of: viewModel.isCompleted) { oldValue, newValue in
            // ✅ Only show toast if challenge just completed AND toast hasn't been shown yet
            if !previousCompletionState && newValue && !viewModel.hasShownCompletionToast {
                showCompletionToast = true
                // Add haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Mark toast as shown so it won't show again
                viewModel.markCompletionToastShown()
                
                // Auto hide toast after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showCompletionToast = false
                }
            }
            previousCompletionState = newValue
        }
        .sheet(isPresented: $showDetailView) {
            DailyChallengeDetailView(viewModel: viewModel, isPresented: $showDetailView)
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
                            Text("Challenge Completed!")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("good for you! 🎉")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.primary.opacity(0.15), radius: 15, x: 0, y: 5)
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
        viewModel.hasMinimumUserData ? 120 : 150
    }
    
    /// Add challenge to task list
    private func addChallengeToTasks() {
        guard let challenge = viewModel.challenge else {
            print("⚠️ No challenge to add")
            return
        }
        
        // Add animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            viewModel.addToTasks { taskId in
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

