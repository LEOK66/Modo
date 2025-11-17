import SwiftUI

// MARK: - Hexagon Shape
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Calculate hexagon points
        // Starting from top center, going clockwise
        let points = [
            CGPoint(x: width * 0.5, y: 0),                    // Top center
            CGPoint(x: width * 0.933, y: height * 0.25),      // Top right
            CGPoint(x: width * 0.933, y: height * 0.75),      // Bottom right
            CGPoint(x: width * 0.5, y: height),               // Bottom center
            CGPoint(x: width * 0.067, y: height * 0.75),      // Bottom left
            CGPoint(x: width * 0.067, y: height * 0.25)       // Top left
        ]
        
        path.move(to: points[0])
        for point in points[1...] {
            path.addLine(to: point)
        }
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Preview
#Preview {
    HexagonShape()
        .fill(Color.blue)
        .frame(width: 64, height: 74)
        .padding()
}

