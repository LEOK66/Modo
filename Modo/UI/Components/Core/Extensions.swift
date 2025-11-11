import SwiftUI
import UIKit

// MARK: - Keyboard Dismissal Extension
extension View {
    /// Dismisses the keyboard when tapping outside of text fields
    /// This modifier adds a tap gesture that will dismiss the keyboard without interfering with other interactions
    func hideKeyboardOnTap() -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        )
    }
    
    /// Dismisses the keyboard programmatically
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// Adds a gesture that dismisses keyboard on tap, without interfering with foreground interactions
    /// This uses simultaneousGesture to allow other interactions to work normally
    func dismissKeyboardOnBackgroundTap() -> some View {
        self.simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
    }
}

// MARK: - Color Extension
extension Color {
    init(hexString: String, alpha: Double = 1.0) {
        var cleaned = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        switch cleaned.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self = Color(red: r, green: g, blue: b).opacity(alpha)
    }
}

// MARK: - UIColor Extension
extension UIColor {
    convenience init(hexString: String, alpha: CGFloat = 1.0) {
        var cleaned = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: CGFloat
        switch cleaned.count {
        case 6:
            r = CGFloat((value >> 16) & 0xFF) / 255.0
            g = CGFloat((value >> 8) & 0xFF) / 255.0
            b = CGFloat(value & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

// MARK: - Input Validation Extension
extension String {
    /// Validates email format
    var isValidEmail: Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }
    
    /// Validates password strength (at least 8 characters, contains letters and numbers)
    var isValidPassword: Bool {
        let passwordRegex = "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d@$!%*#?&]{8,}$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordPredicate.evaluate(with: self)
    }
    
    /// Checks if string is not empty (after trimming whitespace)
    var isNotEmpty: Bool {
        !self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Validates if string is a valid positive number
    var isValidNumber: Bool {
        guard let number = Double(self.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return number > 0
    }
    
    /// Validates height by unit: inches (20-96) or cm (50-250)
    func isValidHeight(unit: String) -> Bool {
        guard let value = Double(self.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        if unit.lowercased() == "cm" {
            return value >= 50 && value <= 250
        }
        return value >= 20 && value <= 96 // default inches
    }
    
    /// Validates weight by unit: lb (44-1100) or kg (20-500)
    func isValidWeight(unit: String) -> Bool {
        guard let value = Double(self.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        if unit.lowercased() == "kg" {
            return value >= 20 && value <= 500
        }
        return value >= 44 && value <= 1100 // default lb
    }
    
    /// Validates if string is a valid age (10-120 years)
    var isValidAge: Bool {
        guard let age = Int(self.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return age >= 10 && age <= 120
    }
    
    /// Validates target weight loss by unit: lb (0.5-220) or kg (0.2-100)
    func isValidTargetWeight(unit: String) -> Bool {
        guard let value = Double(self.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        if unit.lowercased() == "kg" {
            return value >= 0.2 && value <= 100
        }
        return value >= 0.5 && value <= 220 // default lb
    }
    
    /// Validates if string is a valid target days (1-365 days)
    var isValidTargetDays: Bool {
        guard let days = Int(self.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return days >= 1 && days <= 365
    }
}

