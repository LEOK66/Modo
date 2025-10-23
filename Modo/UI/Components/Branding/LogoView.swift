import SwiftUI

// MARK: - Logo Component
struct LogoView: View {
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black)
                .frame(width: 80, height: 80)
                .overlay(
                    Text("M")
                        .font(.system(size: 24, weight: .medium, design: .default))
                        .foregroundColor(.white)
                )
            
            Text("MODO")
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(Color(hexString: "101828"))
                .padding(.top, 8)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(Color(hexString: "101828"))
                    .padding(.top, 8)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Preview
#Preview {
    LogoView(title: "MODO", subtitle: "Login")
}

