import SwiftUI

// MARK: - Page Header Component
struct PageHeader: View {
    @Environment(\.dismiss) private var dismiss
    let title: String

    var body: some View {
        HStack {
            BackButton {
                dismiss()
            }

            Spacer()

            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
    }
}

// MARK: - Preview
#Preview {
    PageHeader(title: "Settings")
}

