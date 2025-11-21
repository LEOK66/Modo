import SwiftUI

/// AI Toolbar component for AddTaskView
/// Displays "Ask AI" and "AI Generate" buttons
struct AIToolbarView: View {
    @Environment(\.colorScheme) var colorScheme
    
    let isAIGenerating: Bool
    let onAskAITapped: () -> Void
    let onAIGenerateTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onAskAITapped) {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(Color(.systemBackground))
                    Text("Ask AI")
                        .foregroundColor(Color(.systemBackground))
                        .lineLimit(1)
                }
                .font(.system(size: 14, weight: .medium))
                .frame(height: 32)
                .padding(.horizontal, 10)
                .background(colorScheme == .dark ? Color(hexString: "B855FF") : Color(hexString: "9810FA"))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Spacer()
            Button(action: onAIGenerateTapped) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(Color(.systemBackground))
                    Text(isAIGenerating ? "..." : "AI Generate")
                        .foregroundColor(Color(.systemBackground))
                        .lineLimit(1)
                }
                .font(.system(size: 14, weight: .medium))
                .frame(height: 32)
                .padding(.horizontal, 10)
                .background(isAIGenerating ? Color(.systemGray4) : (colorScheme == .dark ? Color(.systemGray6) : Color(.label)))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(isAIGenerating)
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    VStack(spacing: 20) {
        AIToolbarView(
            isAIGenerating: false,
            onAskAITapped: {},
            onAIGenerateTapped: {}
        )
        AIToolbarView(
            isAIGenerating: true,
            onAskAITapped: {},
            onAIGenerateTapped: {}
        )
    }
    .padding()
}







