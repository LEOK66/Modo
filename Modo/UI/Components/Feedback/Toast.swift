import SwiftUI

// MARK: - Toast Type
enum ToastType {
    case success
    case error
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        }
    }
}

// MARK: - Toast Component
struct Toast: View {
    let message: String
    let type: ToastType
    let isPresented: Bool
    let topInset: CGFloat
    
    var body: some View {
        VStack {
            if isPresented {
                VStack(spacing: 8) {
                    Image(systemName: type.icon)
                        .font(.system(size: 24))
                        .foregroundColor(type.color)
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hexString: "101828"))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, topInset)
            }
            Spacer()
        }
        .animation(.easeInOut(duration: 0.3), value: isPresented)
    }
}

// MARK: - Legacy Support 
typealias ErrorToast = LegacyErrorToast
typealias SuccessToast = LegacySuccessToast

struct LegacyErrorToast: View {
    let message: String
    let isPresented: Bool
    var topInset: CGFloat = 10
    
    var body: some View {
        Toast(message: message, type: .error, isPresented: isPresented, topInset: topInset)
    }
}

struct LegacySuccessToast: View {
    let message: String
    let isPresented: Bool
    var topInset: CGFloat = 10
    
    var body: some View {
        Toast(message: message, type: .success, isPresented: isPresented, topInset: topInset)
    }
}

// MARK: - Preview
#Preview("Success Toast") {
    Toast(message: "Successfully saved!", type: .success, isPresented: true, topInset: 30)
}

#Preview("Error Toast") {
    Toast(message: "Something went wrong!", type: .error, isPresented: true, topInset: 30)
}

