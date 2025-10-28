import SwiftUI

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
    
    /// Validates if string is a valid height (20-96 inches, ~1.5-8 feet)
    var isValidHeight: Bool {
        guard let height = Double(self.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return height >= 20 && height <= 96
    }
    
    /// Validates if string is a valid weight (44-1100 lbs, ~20-500 kg)
    var isValidWeight: Bool {
        guard let weight = Double(self.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return weight >= 44 && weight <= 1100
    }
    
    /// Validates if string is a valid age (10-120 years)
    var isValidAge: Bool {
        guard let age = Int(self.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return age >= 10 && age <= 120
    }
    
    /// Validates if string is a valid target weight loss (0.5-100 lbs/kg)
    var isValidTargetWeight: Bool {
        guard let target = Double(self.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return target >= 0.5 && target <= 100
    }
    
    /// Validates if string is a valid target days (1-365 days)
    var isValidTargetDays: Bool {
        guard let days = Int(self.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return days >= 1 && days <= 365
    }
}

