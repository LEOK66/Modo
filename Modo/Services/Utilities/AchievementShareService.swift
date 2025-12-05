import SwiftUI
import UIKit

// MARK: - Achievement Share Service

/// Service for generating shareable content for achievements
class AchievementShareService {
    
    /// Generate a shareable image of an achievement badge
    static func generateShareImage(
        achievement: Achievement,
        userAchievement: UserAchievement,
        size: CGSize = CGSize(width: 600, height: 800)
    ) -> UIImage? {
        guard Thread.isMainThread else {
            print("⚠️ generateShareImage must be called on main thread")
            return nil
        }
        
        // Create a SwiftUI view for the achievement
        let shareView = AchievementShareView(
            achievement: achievement,
            userAchievement: userAchievement
        )
        .frame(width: size.width, height: size.height)
        
        // Use ImageRenderer for iOS 16+ (more reliable)
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: shareView)
            renderer.scale = UIScreen.main.scale
            
            // Render the image
            let image = renderer.uiImage
            
            // If image is nil or empty, try alternative method
            if let img = image, img.size != .zero {
                return img
            } else {
                print("⚠️ ImageRenderer returned nil or empty image, using fallback method")
                return generateShareImageFallback(
                    achievement: achievement,
                    userAchievement: userAchievement,
                    size: size
                )
            }
        } else {
            // Fallback for iOS 15 and below
            return generateShareImageFallback(
                achievement: achievement,
                userAchievement: userAchievement,
                size: size
            )
        }
    }
    
    /// Fallback method for generating share image (iOS 15 and below, or when ImageRenderer fails)
    private static func generateShareImageFallback(
        achievement: Achievement,
        userAchievement: UserAchievement,
        size: CGSize
    ) -> UIImage? {
        let shareView = AchievementShareView(
            achievement: achievement,
            userAchievement: userAchievement
        )
        .frame(width: size.width, height: size.height)
        
        // Convert SwiftUI view to UIImage
        let hostingController = UIHostingController(rootView: shareView)
        hostingController.view.frame = CGRect(origin: .zero, size: size)
        hostingController.view.backgroundColor = .white
        
        // Add to a temporary window for proper rendering
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = hostingController
        window.isHidden = false
        window.makeKeyAndVisible()
        
        // Force layout
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        // Wait for rendering (give time for images to load)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        
        // Render using drawHierarchy (more reliable than layer.render)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
        }
        
        // Clean up
        window.isHidden = true
        window.rootViewController = nil
        
        return image
    }
    
    /// Generate share text for an achievement
    static func generateShareText(achievement: Achievement) -> String {
        let appName = "Modo"
        return """
        🏆 I just unlocked the "\(achievement.title)" achievement in \(appName)!
        
        \(achievement.description)
        
        #Modo #Achievement #Fitness #Health
        """
    }
    
    /// Generate share items (image + text) for sharing
    static func generateShareItems(
        achievement: Achievement,
        userAchievement: UserAchievement
    ) -> [Any] {
        var items: [Any] = []
        
        // Add share text
        items.append(generateShareText(achievement: achievement))
        
        // Generate share image on main thread
        var shareImage: UIImage?
        if Thread.isMainThread {
            shareImage = generateShareImage(
                achievement: achievement,
                userAchievement: userAchievement
            )
        } else {
            DispatchQueue.main.sync {
                shareImage = generateShareImage(
                    achievement: achievement,
                    userAchievement: userAchievement
                )
            }
        }
        
        if let image = shareImage {
            items.append(image)
        } else {
            print("⚠️ Failed to generate share image for achievement: \(achievement.id)")
        }
        
        return items
    }
}

// MARK: - Achievement Share View

/// SwiftUI view for generating shareable achievement images
private struct AchievementShareView: View {
    let achievement: Achievement
    let userAchievement: UserAchievement
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hexString: "#1A1F3A"),
                    Color(hexString: "#2D3354")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 32) {
                Spacer()
                
                // App logo/name
                Text("MODO")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                
                // Achievement badge
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hexString: achievement.iconColor).opacity(0.4),
                                    Color(hexString: achievement.iconColor).opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 40,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)
                    
                    // Badge container
                    ZStack {
                        // Try to load image, fallback to colored circle if not found
                        if UIImage(named: "achievement_container_unlocked") != nil {
                            Image("achievement_container_unlocked")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 200, height: 200)
                        } else {
                            // Fallback: use a colored circle
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hexString: achievement.iconColor).opacity(0.3),
                                            Color(hexString: achievement.iconColor).opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 200, height: 200)
                                .overlay(
                                    Circle()
                                        .stroke(Color(hexString: achievement.iconColor).opacity(0.5), lineWidth: 4)
                                )
                        }
                        
                        // Achievement icon
                        achievementIcon
                            .frame(width: 80, height: 80)
                    }
                }
                
                // Achievement title
                Text(achievement.title)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Achievement description
                Text(achievement.description)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineLimit(3)
                
                // Unlock date if available
                if let unlockedAt = userAchievement.unlockedAt {
                    Text("Unlocked on \(formatDate(unlockedAt))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 8)
                }
                
                Spacer()
                
                // App branding
                Text("Download Modo to start your journey")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 32)
            }
            .padding(40)
        }
        .background(Color(hexString: "#1A1F3A"))
    }
    
    private var achievementIcon: some View {
        Group {
            if achievement.iconName.starts(with: "system:") {
                Image(systemName: String(achievement.iconName.dropFirst(7)))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(Color(hexString: achievement.iconColor))
            } else {
                Image(achievement.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// Note: Color extension with hexString is already defined in Extensions.swift

