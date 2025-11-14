import SwiftUI

/// Description card component for task form
struct DescriptionCardView: View {
    @Binding var descriptionText: String
    @FocusState.Binding var descriptionFocused: Bool
    let isDescriptionGenerating: Bool
    let onGenerateTapped: () -> Void
    
    var body: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    label("Description")
                    Spacer()
                    Button(action: onGenerateTapped) {
                        Group {
                            if isDescriptionGenerating {
                                SwiftUI.ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                    .padding(6)
                            } else {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(6)
                            }
                        }
                        .background(Color(hexString: "9810FA"))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDescriptionGenerating)
                }
                ZStack(alignment: .topTrailing) {
                    TextField("e.g., 5km jog in the park", text: $descriptionText, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                        .focused($descriptionFocused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    if !descriptionText.isEmpty {
                        Button(action: { descriptionText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .padding(.trailing, 12)
                        .padding(.top, 12)
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
            }
        }
    }
    
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.primary.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var descriptionText = "5km jog in the park"
        @FocusState private var descriptionFocused: Bool
        
        var body: some View {
            DescriptionCardView(
                descriptionText: $descriptionText,
                descriptionFocused: $descriptionFocused,
                isDescriptionGenerating: false,
                onGenerateTapped: {}
            )
            .padding()
        }
    }
    
    return PreviewWrapper()
}

