import SwiftUI

/// Top header view with calendar and profile buttons
struct TopHeaderView: View {
    @Binding var isShowingCalendar: Bool
    @Binding var isShowingProfile: Bool
    let selectedDate: Date
    @EnvironmentObject var userProfileService: UserProfileService
    
    private var fallbackAvatar: some View {
        Text("A")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color(hexString: "101828"))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Button(action: {
                withAnimation {
                    isShowingProfile = true
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle().stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
                        )
                    
                    // Display user avatar or default
                    Group {
                        if let urlString = userProfileService.profileImageURL, !urlString.isEmpty {
                            if urlString.hasPrefix("http") || urlString.hasPrefix("https") {
                                if let url = URL(string: urlString) {
                                    // Use cached image with placeholder
                                    CachedAsyncImage(url: url) {
                                        // Placeholder: show default avatar or fallback
                                        if let name = userProfileService.avatarName, !name.isEmpty, UIImage(named: name) != nil {
                                            Image(name)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                        } else {
                                            fallbackAvatar
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                        }
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                } else {
                                    fallbackAvatar
                                }
                            } else {
                                fallbackAvatar
                            }
                        } else if let name = userProfileService.avatarName, !name.isEmpty, UIImage(named: name) != nil {
                            Image(name)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            fallbackAvatar
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // Centered date look
            Text(Self.formattedDate(selectedDate: selectedDate))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hexString: "101828"))

            Spacer()

            // Calendar
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    isShowingCalendar = true
                }
            } label: {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 40, height: 40)
                    .overlay(
                        CalendarIcon(strokeColor: .white, size: 20)
                    )
            }
        }
    }

    private static func formattedDate(selectedDate: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selected = calendar.startOfDay(for: selectedDate)
        
        if calendar.isDate(selected, inSameDayAs: today) {
            return "Today"
        }
        
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("MMMM d")
        df.locale = .current
        return df.string(from: selectedDate)
    }
}

