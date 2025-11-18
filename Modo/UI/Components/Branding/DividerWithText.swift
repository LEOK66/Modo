import SwiftUI

// MARK: - Divider with Text Component
struct DividerWithText: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Rectangle()
                .fill(Color(.separator)) // Adapts to light/dark mode
                .frame(height: 1)
                .opacity(1.0)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary) // Adapts to light/dark mode
                .textCase(.uppercase)
            
            Rectangle()
                .fill(Color(.separator)) // Adapts to light/dark mode
                .frame(height: 1)
                .opacity(1.0)
        }
        .frame(maxWidth: LayoutConstants.inputFieldMaxWidth, idealHeight: 16)
    }
}

// MARK: - Preview
#Preview {
    DividerWithText(text: "or")
        .padding()
}

