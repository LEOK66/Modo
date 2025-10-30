import SwiftUI

public struct TaskCard: View {
    let emoji: String
    let title: String
    let subtitle: String
    let time: String
    let meta: String
    @Binding var isDone: Bool
    let emphasis: Color

    public init(emoji: String, title: String, subtitle: String, time: String, meta: String, isDone: Binding<Bool>, emphasis: Color) {
        self.emoji = emoji
        self.title = title
        self.subtitle = subtitle
        self.time = time
        self.meta = meta
        self._isDone = isDone
        self.emphasis = emphasis
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isDone ? emphasis : Color.white)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle().stroke(Color(hexString: "E5E7EB"), lineWidth: isDone ? 0 : 1)
                    )
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(emoji)
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isDone ? emphasis : Color(hexString: "101828"))
                }
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hexString: "6A7282"))
                HStack(spacing: 12) {
                    Label(time, systemImage: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "364153"))
                    Text(meta)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "364153"))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isDone ? emphasis.opacity(0.25) : Color(hexString: "E5E7EB"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                isDone.toggle()
            }
        }
    }
}
