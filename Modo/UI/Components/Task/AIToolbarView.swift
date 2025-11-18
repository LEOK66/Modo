import SwiftUI

/// AI Toolbar component for AddTaskView
/// Displays "Ask AI" and "AI Generate" buttons
struct AIToolbarView: View {
    let isAIGenerating: Bool
    let onAskAITapped: () -> Void
    let onAIGenerateTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onAskAITapped) {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.white)
                    Text("Ask AI")
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .font(.system(size: 14, weight: .medium))
                .frame(height: 32)
                .padding(.horizontal, 10)
                .background(Color(hexString: "9810FA"))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Spacer()
            Button(action: onAIGenerateTapped) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.white)
                    Text(isAIGenerating ? "..." : "AI Generate")
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .font(.system(size: 14, weight: .medium))
                .frame(height: 32)
                .padding(.horizontal, 10)
                .background(isAIGenerating ? Color.gray : Color.black)
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






