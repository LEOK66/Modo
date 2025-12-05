import SwiftUI

// MARK: - Achievement Badge View

/// Displays a single achievement badge with icon, status, and title
struct AchievementBadgeView: View {
    let achievement: Achievement
    let userAchievement: UserAchievement
    
    // Share functionality
    @State private var showShareSheet = false
    
    // Container properties
    private let containerSize: CGFloat = 100
    private let iconSize: CGFloat = 32
    
    var body: some View {
        VStack(spacing: 12) {
            // Badge container (hexagon shape with icon)
            ZStack {
                badgeContainer
                
                // Share button overlay (only for unlocked achievements)
                if userAchievement.isUnlocked {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                showShareSheet = true
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        Circle()
                                            .fill(Color(hexString: "#1A1F3A").opacity(0.8))
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                            .offset(x: 8, y: -8)
                        }
                        Spacer()
                    }
                    .frame(width: containerSize, height: containerSize)
                }
            }
            
            // Status ribbon
            statusRibbon
            
            // Title (hide for locked mystery achievements)
            if achievement.category == .mystery && !userAchievement.isUnlocked {
                Text("???")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .frame(height: 34, alignment: .top)
            } else {
                Text(achievement.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 34, alignment: .top)
            }
        }
        .frame(width: containerSize + 20)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(
                items: AchievementShareService.generateShareItems(
                    achievement: achievement,
                    userAchievement: userAchievement
                )
            )
        }
    }
    
    // MARK: - Badge Container
    
    private var badgeContainer: some View {
        ZStack {
            // Layer 1: Container background (different for locked/unlocked)
            Image(userAchievement.isUnlocked ? "achievement_container_unlocked" : "achievement_container_locked")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: containerSize, height: containerSize)
            
            // Layer 2: Achievement icon (SF Symbol or custom image)
            achievementIcon
            
            // Lock overlay for locked achievements
            if !userAchievement.isUnlocked {
                lockOverlay
            }
        }
        .grayscale(userAchievement.isUnlocked ? 0.0 : 0.6)
        .saturation(userAchievement.isUnlocked ? 1.0 : 0.3)
    }
    
    // MARK: - Achievement Icon
    
    private var achievementIcon: some View {
        Group {
            // For mystery achievements that are locked, show question mark
            if achievement.category == .mystery && !userAchievement.isUnlocked {
                // Show question mark for locked mystery achievements
                Image(systemName: "questionmark.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(Color(hex: "#C0C0C0"))
            } else if achievement.iconName.starts(with: "system:") {
                // SF Symbol icon
                Image(systemName: String(achievement.iconName.dropFirst(7)))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(
                        userAchievement.isUnlocked
                            ? Color(hex: achievement.iconColor)
                            : Color(hex: "#C0C0C0")
                    )
            } else {
                // Custom PNG icon
                Image(achievement.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .opacity(userAchievement.isUnlocked ? 1.0 : 0.5)
            }
        }
    }
    
    // MARK: - System Icon Container (Fallback for SF Symbols)
    
    private var systemIconContainer: some View {
        ZStack {
            // Hexagon background
            HexagonShape()
                .fill(
                    LinearGradient(
                        colors: userAchievement.isUnlocked
                            ? [Color(hex: "#F5F5F5"), Color(hex: "#E8E8E8")]
                            : [Color(hex: "#F8F8F8"), Color(hex: "#EFEFEF")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: containerSize, height: containerSize)
                .shadow(
                    color: Color.black.opacity(0.08),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            
            // Inner hexagon border
            HexagonShape()
                .stroke(
                    Color(hex: "#D0D0D0"),
                    lineWidth: 2
                )
                .frame(width: containerSize - 10, height: containerSize - 10)
            
            // SF Symbol icon
            Image(systemName: String(achievement.iconName.dropFirst(7)))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(
                    userAchievement.isUnlocked
                        ? Color(hex: achievement.iconColor)
                        : Color(hex: "#C0C0C0")
                )
        }
        .grayscale(userAchievement.isUnlocked ? 0.0 : 0.6)
        .saturation(userAchievement.isUnlocked ? 1.0 : 0.3)
    }
    
    // MARK: - Lock Overlay
    
    private var lockOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .offset(x: 8, y: -8)
            }
            Spacer()
        }
        .frame(width: containerSize, height: containerSize)
    }
    
    // MARK: - Status Ribbon
    
    private var statusRibbon: some View {
        // Use designer's status PNG
        Image(userAchievement.isUnlocked ? "achievement_status_unlocked" : "achievement_status_locked")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 90, height: 24)
    }
}

// MARK: - Hexagon Shape

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let centerX = width / 2
        let centerY = height / 2
        let radius = min(width, height) / 2
        
        // Calculate hexagon points (flat-top hexagon)
        let angles: [Double] = [0, 60, 120, 180, 240, 300].map { $0 * .pi / 180 }
        let points = angles.map { angle in
            CGPoint(
                x: centerX + radius * cos(angle - .pi / 2),
                y: centerY + radius * sin(angle - .pi / 2)
            )
        }
        
        // Draw hexagon
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Ribbon Shape

struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let notchWidth: CGFloat = 6
        let notchHeight: CGFloat = 4
        
        // Start from top-left
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Top edge
        path.addLine(to: CGPoint(x: width, y: 0))
        
        // Right edge
        path.addLine(to: CGPoint(x: width, y: height))
        
        // Right notch (inverted V)
        path.addLine(to: CGPoint(x: width - notchWidth, y: height - notchHeight))
        path.addLine(to: CGPoint(x: width - notchWidth * 2, y: height))
        
        // Bottom edge
        path.addLine(to: CGPoint(x: notchWidth * 2, y: height))
        
        // Left notch (inverted V)
        path.addLine(to: CGPoint(x: notchWidth, y: height - notchHeight))
        path.addLine(to: CGPoint(x: 0, y: height))
        
        // Left edge
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    let unlockedAchievement = Achievement(
        id: "first_step",
        title: "First Step",
        description: "Complete your first day",
        iconName: "system:star.fill",
        iconColor: "#FF6B6B",
        category: .streak,
        unlockCondition: UnlockCondition(type: .streak, targetValue: 1)
    )
    
    let unlockedUserAchievement = UserAchievement(
        id: "first_step",
        achievementId: "first_step",
        status: .unlocked,
        currentProgress: 1,
        unlockedAt: Date()
    )
    
    let lockedAchievement = Achievement(
        id: "century_club",
        title: "Century Club",
        description: "Complete 100 consecutive days",
        iconName: "system:crown.fill",
        iconColor: "#E67E22",
        category: .streak,
        unlockCondition: UnlockCondition(type: .streak, targetValue: 100)
    )
    
    let lockedUserAchievement = UserAchievement(
        id: "century_club",
        achievementId: "century_club",
        status: .locked,
        currentProgress: 0
    )
    
    return HStack(spacing: 20) {
        AchievementBadgeView(
            achievement: unlockedAchievement,
            userAchievement: unlockedUserAchievement
        )
        
        AchievementBadgeView(
            achievement: lockedAchievement,
            userAchievement: lockedUserAchievement
        )
    }
    .padding()
}

