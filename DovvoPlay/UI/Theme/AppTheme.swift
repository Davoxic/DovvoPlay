import Foundation
import SwiftUI

public enum AppTheme {
    public static var current: VisualTheme {
        return ThemeService.shared.currentTheme
    }

    public static var background: Color { current.background }
    public static var surface: Color { current.surface }
    public static var surfaceLight: Color { current.surfaceLight }
    public static var surfaceCard: Color { current.surfaceCard }
    public static var primary: Color { current.primary }
    public static var secondary: Color { current.secondary }
    public static var accent: Color { current.accent }
    public static var goldBorder: Color { current.goldBorder }
    public static var goldGlow: Color { current.goldGlow }
    public static var textPrimary: Color { current.textPrimary }
    public static var textSecondary: Color { current.textSecondary }
    public static var textMuted: Color { current.textMuted }

    public static var primaryGradient: LinearGradient { current.primaryGradient }
    public static var surfaceGradient: LinearGradient { current.surfaceGradient }
    public static var darkGradient: LinearGradient { current.darkGradient }

    public static var goldSurfaceGradient: LinearGradient { current.surfaceGradient }
}

extension Color {
    public init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255.0,
            green: Double((hex >> 08) & 0xff) / 255.0,
            blue: Double((hex >> 00) & 0xff) / 255.0,
            opacity: alpha
        )
    }
}
