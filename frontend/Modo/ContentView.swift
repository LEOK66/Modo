// current main page


import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        ZStack {
        
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("This is a simple interface - Zihao")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .multilineTextAlignment(.center)
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
