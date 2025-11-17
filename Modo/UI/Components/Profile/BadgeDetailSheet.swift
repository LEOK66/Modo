import SwiftUI

// MARK: - Badge Detail Sheet
struct BadgeDetailSheet: View {
    let achievement: Achievement
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color(hexString: "F9FAFB")
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hexString: "99A1AF"))
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 24)
                }
                
                // Large badge icon
                ZStack {
                    // Hexagon background
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
                        .frame(width: 120, height: 138)
                    
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
                        .frame(width: 100, height: 115)
                    
                    // Icon
                    Image(systemName: achievement.iconName)
                        .font(.system(size: 48))
                        .foregroundColor(
                            achievement.isUnlocked ?
                            Color(hexString: achievement.color) :
                            Color(hexString: "99A1AF").opacity(0.6)
                        )
                    
                    // Lock indicator
                    if !achievement.isUnlocked {
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(Color(hexString: "4A5565"))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                    
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                                .offset(x: 20, y: -20)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.top, 24)
                
                // Badge name
                Text(achievement.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(
                        achievement.isUnlocked ?
                        Color(hexString: "101828") :
                        Color(hexString: "99A1AF")
                    )
                
                // Status
                HStack(spacing: 8) {
                    Image(systemName: achievement.isUnlocked ? "checkmark.circle.fill" : "lock.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(
                            achievement.isUnlocked ?
                            Color(hexString: "00A63E") :
                            Color(hexString: "99A1AF")
                        )
                    
                    Text(achievement.isUnlocked ? "Unlocked" : "Locked")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(
                            achievement.isUnlocked ?
                            Color(hexString: "00A63E") :
                            Color(hexString: "99A1AF")
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            achievement.isUnlocked ?
                            Color(hexString: "00A63E").opacity(0.1) :
                            Color(hexString: "E5E7EB")
                        )
                )
                
                // Description and How to Unlock
                VStack(spacing: 16) {
                    // Description Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hexString: "4361EE"))
                            
                            Text("Description")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(hexString: "364153"))
                        }
                        
                        Text(achievement.description)
                            .font(.system(size: 16))
                            .foregroundColor(Color(hexString: "6B7A95"))
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    
                    // How to Unlock Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: achievement.isUnlocked ? "checkmark.seal.fill" : "lock.shield.fill")
                                .font(.system(size: 16))
                                .foregroundColor(
                                    achievement.isUnlocked ?
                                    Color(hexString: "00A63E") :
                                    Color(hexString: "FDC700")
                                )
                            
                            Text(achievement.isUnlocked ? "Unlocked By" : "How to Unlock")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(hexString: "364153"))
                        }
                        
                        Text(achievement.howToUnlock)
                            .font(.system(size: 16))
                            .foregroundColor(Color(hexString: "6B7A95"))
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                achievement.isUnlocked ?
                                Color(hexString: "00A63E").opacity(0.05) :
                                Color(hexString: "FFF4E6")
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        achievement.isUnlocked ?
                                        Color(hexString: "00A63E").opacity(0.2) :
                                        Color(hexString: "FDC700").opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Close button
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hexString: "000000"))
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    BadgeDetailSheet(achievement: Achievement.allAchievements[0])
}

