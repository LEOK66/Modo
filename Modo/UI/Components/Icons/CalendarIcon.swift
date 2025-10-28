import SwiftUI

// MARK: - Calendar Icon Component
public struct CalendarIcon: View {
    public var strokeColor: Color
    public var size: CGFloat

    public init(strokeColor: Color = .white, size: CGFloat = 20) {
        self.strokeColor = strokeColor
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Vector 1
            Path { path in
                path.move(to: CGPoint(x: size * 0.3333, y: size * 0.0833))
                path.addLine(to: CGPoint(x: size * 0.6667, y: size * 0.0833))
            }
            .stroke(strokeColor, lineWidth: size * (1.67/20))
            
            // Vector 2
            Path { path in
                path.move(to: CGPoint(x: size * 0.6667, y: size * 0.0833))
                path.addLine(to: CGPoint(x: size * 0.3333, y: size * 0.0833))
            }
            .stroke(strokeColor, lineWidth: size * (1.67/20))
            
            // Vector 3
            Path { path in
                path.addRect(CGRect(
                    x: size * 0.125,
                    y: size * 0.1667,
                    width: size * (1 - 0.125 * 2),
                    height: size * (1 - 0.1667 - 0.0833)
                ))
            }
            .stroke(strokeColor, lineWidth: size * (1.67/20))
            
            // Vector 4
            Path { path in
                path.addRect(CGRect(
                    x: size * 0.125,
                    y: size * 0.4167,
                    width: size * (1 - 0.125 * 2),
                    height: size * (1 - 0.4167 - 0.5833)
                ))
            }
            .stroke(strokeColor, lineWidth: size * (1.67/20))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Calendar icon")
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        CalendarIcon(strokeColor: .black, size: 24)
        CalendarIcon(strokeColor: .white, size: 20)
            .background(Color.black)
    }
    .padding()
}

