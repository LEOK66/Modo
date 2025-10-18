import SwiftUI

struct InsightsPageView: View {
    @State private var inputText: String = ""
    @State private var selectedTab: Tab = .insights
    @State private var navigateToMain: Bool = false

    var body: some View {
        NavigationStack {
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
                    .onChange(of: selectedTab) { oldValue, newValue in
                        if newValue == .todos {
                            navigateToMain = true
                        }
                    }
            }
            .background(Color.white.ignoresSafeArea())
            .navigationDestination(isPresented: $navigateToMain) {
                MainPageView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    InsightsPageView()
}
