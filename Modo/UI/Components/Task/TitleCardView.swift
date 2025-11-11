import SwiftUI

/// Title card component for task form
struct TitleCardView: View {
    @Binding var titleText: String
    @FocusState.Binding var titleFocused: Bool
    let isTitleGenerating: Bool
    let onGenerateTapped: () -> Void
    
    var body: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    label("Task Title")
                    Spacer()
                    Button(action: onGenerateTapped) {
                        Group {
                            if isTitleGenerating {
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
                    .disabled(isTitleGenerating)
                }
                HStack(spacing: 8) {
                    TextField("e.g., Morning Run", text: $titleText)
                        .textInputAutocapitalization(.words)
                        .focused($titleFocused)
                        .onChange(of: titleText) { _, newValue in
                            if newValue.count > 40 { titleText = String(newValue.prefix(40)) }
                        }
                        .textFieldStyle(.plain)
                    if !titleText.isEmpty {
                        Button(action: { titleText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(hexString: "9CA3AF"))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color(hexString: "F9FAFB"))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                if titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Required")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "9CA3AF"))
                }
            }
        }
    }
    
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(Color(hexString: "4A5565"))
    }
    
    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var titleText = "Morning Run"
        @FocusState private var titleFocused: Bool
        
        var body: some View {
            TitleCardView(
                titleText: $titleText,
                titleFocused: $titleFocused,
                isTitleGenerating: false,
                onGenerateTapped: {}
            )
            .padding()
        }
    }
    
    return PreviewWrapper()
}

