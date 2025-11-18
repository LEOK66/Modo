import Foundation
import Combine
import SwiftUI
import UIKit

// MARK: - Theme Manager
/// Manages the app's theme preferences (light/dark mode)
final class ThemeManager: ObservableObject {
    private var hasUserManuallySet: Bool {
        get {
            UserDefaults.standard.bool(forKey: "hasUserManuallySetTheme")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hasUserManuallySetTheme")
        }
    }
    
    private var userManualSetting: Bool? {
        get {
            if UserDefaults.standard.object(forKey: "userManualThemeSetting") == nil {
                return nil
            }
            return UserDefaults.standard.bool(forKey: "userManualThemeSetting")
        }
        set {
            if let value = newValue {
                UserDefaults.standard.set(value, forKey: "userManualThemeSetting")
            } else {
                UserDefaults.standard.removeObject(forKey: "userManualThemeSetting")
            }
        }
    }
    
    @Published var isDarkMode: Bool = false {
        didSet {
            // Only mark as manual if this change is from user interaction
            // (not from system update)
            if !isUpdatingFromSystem {
                hasUserManuallySet = true
                userManualSetting = isDarkMode
            }
            applyColorScheme()
        }
    }
    
    private var isUpdatingFromSystem: Bool = false
    
    @Published var colorScheme: ColorScheme? = nil
    
    private var systemColorSchemeObserver: NSObjectProtocol?
    
    init() {
        // Check if user has manually set theme
        if hasUserManuallySet, let manualSetting = userManualSetting {
            // Use user's manual setting
            isUpdatingFromSystem = false
            self.isDarkMode = manualSetting
        } else {
            // Follow system - initialize based on current system appearance
            isUpdatingFromSystem = true
            self.isDarkMode = getSystemIsDarkMode()
            isUpdatingFromSystem = false
        }
        
        applyColorScheme()
        
        // Listen to system color scheme changes
        observeSystemColorScheme()
    }
    
    private func getSystemIsDarkMode() -> Bool {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.traitCollection.userInterfaceStyle == .dark
        }
        return UITraitCollection.current.userInterfaceStyle == .dark
    }
    
    private func observeSystemColorScheme() {
        // Observe system color scheme changes
        systemColorSchemeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // Only update if user hasn't manually set
            if !self.hasUserManuallySet {
                let systemIsDark = self.getSystemIsDarkMode()
                if self.isDarkMode != systemIsDark {
                    self.isUpdatingFromSystem = true
                    self.isDarkMode = systemIsDark
                    self.isUpdatingFromSystem = false
                }
            }
        }
    }
    
    func updateFromSystem(systemColorScheme: ColorScheme) {
        // Only update if user hasn't manually set
        if !hasUserManuallySet {
            let systemIsDark = systemColorScheme == .dark
            if isDarkMode != systemIsDark {
                isUpdatingFromSystem = true
                isDarkMode = systemIsDark
                isUpdatingFromSystem = false
            }
        }
    }
    
    private func applyColorScheme() {
        if hasUserManuallySet {
            // User has manually set - use their preference
            colorScheme = isDarkMode ? .dark : .light
        } else {
            // Follow system - don't force color scheme
            colorScheme = nil
        }
    }
    
    deinit {
        if let observer = systemColorSchemeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

