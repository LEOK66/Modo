import SwiftUI

// MARK: - Layout Constants
/// Central place for layout values used across the app.
///
/// Why keep this file?
/// - Consistency: Single source of truth for layout values across 6+ files
/// - Maintainability: Change width in one place instead of updating multiple files
/// - Readability: `LayoutConstants.inputFieldMaxWidth` is more descriptive than hardcoded `273`
/// - Scalability: Easy to add more layout constants as the app grows
struct LayoutConstants {
    /// Maximum width for input fields and buttons (70% of standard iPhone width)
    static let inputFieldMaxWidth: CGFloat = 273
}

