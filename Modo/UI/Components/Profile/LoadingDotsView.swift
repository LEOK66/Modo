import SwiftUI

/// Reusable loading dots animation component
/// Uses scale effect animation similar to TasksHeader
struct LoadingDotsView: View {
    let dotSize: CGFloat
    let dotColor: Color
    let spacing: CGFloat
    let isAnimating: Bool
    
    @State private var animateDots = false
    
    init(
        dotSize: CGFloat = 12,
        dotColor: Color = Color(hexString: "8B5CF6"),
        spacing: CGFloat = 8,
        isAnimating: Bool = true
    ) {
        self.dotSize = dotSize
        self.dotColor = dotColor
        self.spacing = spacing
        self.isAnimating = isAnimating
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            Circle()
                .fill(dotColor)
                .frame(width: dotSize, height: dotSize)
                .scaleEffect(animateDots ? 1.2 : 0.6)
                .animation(.easeInOut(duration: 0.6).repeatForever(), value: animateDots)
            
            Circle()
                .fill(dotColor)
                .frame(width: dotSize, height: dotSize)
                .scaleEffect(animateDots ? 1.2 : 0.6)
                .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.2), value: animateDots)
            
            Circle()
                .fill(dotColor)
                .frame(width: dotSize, height: dotSize)
                .scaleEffect(animateDots ? 1.2 : 0.6)
                .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.4), value: animateDots)
        }
        .onAppear {
            if isAnimating {
                animateDots = true
            }
        }
        .onDisappear {
            animateDots = false
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                animateDots = true
            } else {
                animateDots = false
            }
        }
    }
}

