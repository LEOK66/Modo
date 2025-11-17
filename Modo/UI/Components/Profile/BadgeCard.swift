import SwiftUI

// MARK: - Badge Card Component
struct BadgeCard: View {
    let achievement: Achievement
    @State private var showDetail = false
    
    var body: some View {
        Button {
            showDetail = true
        } label: {
            VStack(spacing: 0) {
                // Badge container
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hexString: "EDF0F4"))
                        .frame(width: 110, height: 145)
                    
                    VStack(spacing: 8) {
                        // Icon container with hexagon shape
                        ZStack {
                            // Outer hexagon
                            HexagonShape()
                                .fill(
                                    achievement.isUnlocked ?
                                    LinearGradient(
                                        colors: [
                                            Color(hexString: "FAFAFA"),
                                            Color(hexString: "C2C4CD")
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [
                                            Color(hexString: "E0E0E0"),
                                            Color(hexString: "F5F5F5")
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 74)
                            
                            // Inner hexagon
                            HexagonShape()
                                .fill(
                                    achievement.isUnlocked ?
                                    LinearGradient(
                                        colors: [
                                            Color(hexString: "CDCFD6"),
                                            Color(hexString: "EFEFF1")
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [
                                            Color(hexString: "F0F0F0"),
                                            Color(hexString: "E0E0E0")
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 54, height: 62)
                            
                            // Icon
                            Image(systemName: achievement.iconName)
                                .font(.system(size: 28))
                                .foregroundColor(
                                    achievement.isUnlocked ?
                                    Color(hexString: achievement.color) :
                                    Color(hexString: "99A1AF").opacity(0.6)
                                )
                            
                            // Lock indicator for locked badges
                            if !achievement.isUnlocked {
                                VStack {
                                    HStack {
                                        Spacer()
                                        ZStack {
                                            Circle()
                                                .fill(Color(hexString: "4A5565"))
                                                .frame(width: 16, height: 16)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: 1)
                                                )
                                            
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 8))
                                                .foregroundColor(.white)
                                        }
                                        .offset(x: 10, y: -10)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .padding(.top, 16)
                        
                        // Status badge
                        HStack(spacing: 0) {
                            // Ribbon base
                            ZStack {
                                // Ribbon shape simulation
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(achievement.isUnlocked ?
                                          LinearGradient(
                                            colors: [Color(hexString: "CCDCF3"), Color(hexString: "C6D5EC")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                          ) :
                                          LinearGradient(
                                            colors: [Color(hexString: "E0E0E0"), Color(hexString: "D0D0D0")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                          )
                                    )
                                    .frame(width: 84, height: 21)
                                
                                Text(achievement.isUnlocked ? "UNLOCKED" : "LOCKED")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(achievement.isUnlocked ?
                                                     Color(hexString: "6B7A95") :
                                                     Color(hexString: "99A1AF"))
                                    .tracking(0.12)
                            }
                        }
                        .padding(.top, 4)
                        
                        Spacer()
                    }
                    .frame(width: 110, height: 145)
                }
                
                // Achievement name
                Text(achievement.name)
                    .font(.system(size: 10))
                    .foregroundColor(
                        achievement.isUnlocked ?
                        Color(hexString: "4F4F4F") :
                        Color(hexString: "99A1AF")
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 22)
                    .padding(.top, 8)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 110, height: 167)
        .sheet(isPresented: $showDetail) {
            BadgeDetailSheet(achievement: achievement)
        }
    }
}

// MARK: - Preview (use PreviewProvider to avoid #Preview macro recursion)
struct BadgeCard_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 12) {
            BadgeCard(achievement: Achievement.allAchievements[0])
            BadgeCard(achievement: Achievement.allAchievements[6])
        }
        .padding()
        .background(Color(hexString: "F9FAFB"))
        .previewLayout(.sizeThatFits)
    }
}
