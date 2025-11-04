import SwiftUI

struct InsightsPageView: View {
    @Binding var selectedTab: Tab
    @State private var inputText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Text("Insights")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hexString: "101828"))

                Spacer()

                // Placeholder to balance layout
                Color.clear.frame(width: 36).padding(.trailing, 16)
            }
            .frame(height: 44)
            .padding(.top, 12)
            .background(Color.white)
            Spacer() // Blank middle content

            // MARK: - Input Field + Buttons
            HStack(spacing: 12) {
                Button(action: {}) {
                    Image(systemName: "plus")
                        .foregroundColor(.black)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(hexString: "E5E7EB"), lineWidth: 1))
                }

                CustomInputField(
                    placeholder: "Ask questions or add photos...",
                    text: $inputText
                )

                Button(action: {}) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.purple.opacity(0.7))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            // MARK: - Bottom Navigation Bar
            BottomBar(selectedTab: $selectedTab)
        }
        .background(
            Color.white
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height
                    
                    // Only handle horizontal swipes (ignore vertical)
                    // Swipe from left to right: go back to todos tab (main page)
                    if abs(horizontalAmount) > abs(verticalAmount) && horizontalAmount > 0 {
                        // Swipe from left to right: go back to todos tab
                        withAnimation {
                            selectedTab = .todos
                        }
                    }
                }
        )
    }
}

// MARK: - Preview
#Preview {
    StatefulPreviewWrapper(Tab.insights) { selection in
        InsightsPageView(selectedTab: selection)
    }
}
