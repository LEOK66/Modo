import SwiftUI

/// Avatar button component for displaying user avatar
/// Supports both network image (profileImageURL) and default avatar (avatarName)
struct AvatarButton: View {
    let avatarName: String?
    let profileImageURL: String?
    let size: CGFloat
    let onTap: () -> Void
    
    init(
        avatarName: String?,
        profileImageURL: String? = nil,
        size: CGFloat = 40,
        onTap: @escaping () -> Void
    ) {
        self.avatarName = avatarName
        self.profileImageURL = profileImageURL
        self.size = size
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background circle with border
                Circle()
                    .fill(Color.white)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle().stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
                    )
                
                // Avatar image
                avatarImage
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var avatarImage: some View {
        // Priority: profileImageURL > avatarName
        if let urlString = profileImageURL,
           !urlString.isEmpty,
           urlString.hasPrefix("http") || urlString.hasPrefix("https"),
           let url = URL(string: urlString) {
            // Network image with default avatar as placeholder
            CachedAsyncImage(url: url) {
                if let avatarName = avatarName {
                    Image(avatarName)
                        .resizable()
                        .scaledToFill()
                }
            }
        } else if let avatarName = avatarName {
            // Default avatar
            Image(avatarName)
                .resizable()
                .scaledToFill()
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        AvatarButton(
            avatarName: "profile_1",
            profileImageURL: nil,
            size: 40
        ) {
            print("Tapped")
        }
        
        AvatarButton(
            avatarName: "profile_2",
            profileImageURL: "https://example.com/avatar.jpg",
            size: 60
        ) {
            print("Tapped")
        }
    }
    .padding()
}

