import SwiftUI

/// Top header view with calendar and profile buttons
struct TopHeaderView: View {
    @Binding var isShowingCalendar: Bool
    @Binding var isShowingProfile: Bool
    let selectedDate: Date
    @EnvironmentObject var userProfileService: UserProfileService
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarButton(
                avatarName: userProfileService.avatarName,
                profileImageURL: userProfileService.profileImageURL,
                size: 40
            ) {
                withAnimation {
                    isShowingProfile = true
                }
            }

            Spacer()

            // Centered date display
            Text(selectedDate.headerDisplayString())
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            Spacer()

            // Calendar
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    isShowingCalendar = true
                }
            } label: {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary)
                    .frame(width: 40, height: 40)
                    .overlay(
                        CalendarIcon(strokeColor: Color(.systemBackground), size: 20)
                    )
            }
        }
    }
}

