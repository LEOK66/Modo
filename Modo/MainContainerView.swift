import SwiftUI

struct MainContainerView: View {
    @State private var selectedTab: Tab = .todos
    
    var body: some View {
        ZStack {
            switch selectedTab {
            case .todos:
                MainPageView(selectedTab: $selectedTab)
                    .transition(.opacity)
            case .insights:
                InsightsPageView(selectedTab: $selectedTab)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
        .background(Color.white.ignoresSafeArea())
    }
}

#Preview {
    MainContainerView()
}
