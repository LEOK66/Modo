import SwiftUI

// MARK: - Achievement Unlock View

/// Displays an animated achievement unlock celebration modal
/// Similar to Duolingo's achievement unlock animation
struct AchievementUnlockView: View {
    let achievement: Achievement
    let userAchievement: UserAchievement
    @Binding var isPresented: Bool
    
    var onViewDetails: (() -> Void)?
    
    // Animation states
    @State private var cardScale: CGFloat = 0.3
    @State private var cardOpacity: Double = 0
    @State private var badgeScale: CGFloat = 0.5
    @State private var badgeRotation: Double = -15
    @State private var badgeOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 50
    @State private var buttonOpacity: Double = 0
    @State private var sparkleAnimation: Bool = false
    @State private var sparkleOpacities: [Double] = Array(repeating: 0, count: 8)
    
    // Badge glow effect
    @State private var glowScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background overlay with blur effect
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }
            
            // Main card
            VStack(spacing: 0) {
                // Close button (top right)
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                
                Spacer()
                
                // Content card
                VStack(spacing: 24) {
                    // Badge icon with animation
                    ZStack {
                        // Glow effect
                        if badgeOpacity > 0.5 {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color(hex: achievement.iconColor).opacity(0.3),
                                            Color(hex: achievement.iconColor).opacity(0.0)
                                        ],
                                        center: .center,
                                        startRadius: 20,
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 160, height: 160)
                                .scaleEffect(glowScale)
                                .opacity(badgeOpacity * 0.6)
                        }
                        
                        // Badge container
                        ZStack {
                            // Container background (unlocked style)
                            Image("achievement_container_unlocked")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                            
                            // Achievement icon
                            achievementIcon
                                .frame(width: 48, height: 48)
                        }
                        .scaleEffect(badgeScale)
                        .rotationEffect(.degrees(badgeRotation))
                        .opacity(badgeOpacity)
                        
                        // Sparkle effects
                        ForEach(0..<8, id: \.self) { index in
                            sparkle(at: index)
                                .opacity(sparkleOpacities[index])
                        }
                    }
                    .frame(height: 200)
                    
                    // Text content
                    VStack(spacing: 12) {
                        Text("Achievement Unlocked!")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .opacity(textOpacity)
                        
                        Text(achievement.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "#1A1A1A"))
                            .multilineTextAlignment(.center)
                            .opacity(textOpacity)
                        
                        Text(achievement.description)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .opacity(textOpacity)
                    }
                    .padding(.horizontal, 32)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        // View Details button
                        Button(action: {
                            onViewDetails?()
                            dismiss()
                        }) {
                            Text("View Details")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "#1A1F3A"),
                                            Color(hex: "#2D3354")
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        // Close button
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Close")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 32)
                    .offset(y: buttonOffset)
                    .opacity(buttonOpacity)
                }
                .padding(.vertical, 40)
                .padding(.bottom, 32)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(
                    color: Color.black.opacity(0.15),
                    radius: 20,
                    x: 0,
                    y: 10
                )
                .scaleEffect(cardScale)
                .opacity(cardOpacity)
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    // MARK: - Achievement Icon
    
    private var achievementIcon: some View {
        Group {
            if achievement.iconName.starts(with: "system:") {
                // SF Symbol icon
                Image(systemName: String(achievement.iconName.dropFirst(7)))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(Color(hex: achievement.iconColor))
            } else {
                // Custom PNG icon
                Image(achievement.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
    
    // MARK: - Sparkle Effect
    
    private func sparkle(at index: Int) -> some View {
        let angle = Double(index) * (360.0 / 8.0) * .pi / 180.0
        let radius: CGFloat = 80
        let x = cos(angle) * radius
        let y = sin(angle) * radius
        
        return Image(systemName: "sparkle")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(Color(hex: achievement.iconColor))
            .offset(x: x, y: y)
            .scaleEffect(1.0)
    }
    
    // MARK: - Animation
    
    private func startAnimation() {
        // Stage 1: Card pop up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
        }
        
        // Stage 3: Badge animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                badgeScale = 1.0
                badgeRotation = 0
                badgeOpacity = 1.0
            }
            
            // Glow pulse animation
            withAnimation(
                Animation.easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
            ) {
                glowScale = 1.2
            }
            
            // Sparkle animation
            for i in 0..<8 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.1) {
                    withAnimation(.easeOut(duration: 0.6)) {
                        sparkleOpacities[i] = 1.0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            sparkleOpacities[i] = 0.0
                        }
                    }
                }
            }
        }
        
        // Stage 4: Text fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.4)) {
                textOpacity = 1.0
            }
        }
        
        // Stage 5: Buttons slide up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                buttonOffset = 0
                buttonOpacity = 1.0
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) {
            cardScale = 0.8
            cardOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
}

// MARK: - Preview

#Preview {
    let achievement = Achievement(
        id: "first_step",
        title: "First Step",
        description: "Every journey begins with a single step",
        iconName: "system:star.fill",
        iconColor: "#FF6B6B",
        category: .task,
        unlockCondition: UnlockCondition(type: .totalTasks, targetValue: 1),
        order: 1
    )
    
    let userAchievement = UserAchievement(
        id: "first_step",
        achievementId: "first_step",
        status: .unlocked,
        currentProgress: 1,
        unlockedAt: Date()
    )
    
    return ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        AchievementUnlockView(
            achievement: achievement,
            userAchievement: userAchievement,
            isPresented: .constant(true),
            onViewDetails: {
                print("View details tapped")
            }
        )
    }
}

