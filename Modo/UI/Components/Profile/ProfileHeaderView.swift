import SwiftUI

struct ProfileHeaderView: View {
    let username: String
    let email: String
    let avatarName: String?
    let profileImageURL: String?
    let onEdit: () -> Void
    let onEditAvatar: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                // Avatar circle background
                Circle()
                    .stroke(Color.black, lineWidth: 2)
                    .frame(width: 96, height: 96)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 10)
                    .background(
                        Circle()
                            .fill(Color(hexString: "F3F4F6"))
                            .padding(4)
                    )

                // Content image
                Group {
                    if let urlString = profileImageURL, let url = URL(string: urlString) {
                        // Use cached image with a neutral placeholder (not the default avatar)
                        // This prevents showing default avatar when user has uploaded a custom image
                        CachedAsyncImage(url: url) {
                            // Use a subtle placeholder that matches the background, not the default avatar
                            // This prevents the flash of default avatar when cached image loads
                            Circle()
                                .fill(Color(hexString: "E5E7EB"))
                                .frame(width: 96, height: 96)
                                .overlay(
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        .foregroundStyle(Color.gray.opacity(0.4))
                                )
                        }
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                    } else if let name = avatarName, !name.isEmpty, UIImage(named: name) != nil {
                        Image(name)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 96)
                            .foregroundStyle(Color.gray.opacity(0.6))
                    }
                }

                // Pencil button
                Button(action: onEditAvatar) {
                    ZStack {
                        Circle().fill(Color.white).frame(width: 28, height: 28)
                        Circle().stroke(Color(hexString: "E5E7EB"), lineWidth: 1).frame(width: 28, height: 28)
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hexString: "6A7282"))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .offset(x: 6, y: 6)
            }
            Button(action: onEdit) {
                HStack(spacing: 4) {
                    Text(username)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.primary)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .id(username)
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hexString: "6A7282"))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .animation(.easeInOut(duration: 0.3), value: username)
            
            Text(email)
                .font(.system(size: 14))
                .foregroundColor(Color(hexString: "6A7282"))
        }
        .frame(maxWidth: .infinity)
    }
}

