import Foundation
import SwiftUI

public struct VisualTheme: Identifiable, Equatable {
    public static func == (lhs: VisualTheme, rhs: VisualTheme) -> Bool {
        return lhs.id == rhs.id
    }

    public let id: String
    public let name: String
    public let description: String
    public let isGradient: Bool
    public let background: Color
    public let surface: Color
    public let surfaceLight: Color
    public let surfaceCard: Color
    public let primary: Color
    public let secondary: Color
    public let accent: Color
    public let goldBorder: Color
    public let goldGlow: Color
    public let textPrimary: Color
    public let textSecondary: Color
    public let textMuted: Color
    public let primaryGradient: LinearGradient
    public let surfaceGradient: LinearGradient
    public let darkGradient: LinearGradient

    public init(
        id: String,
        name: String,
        description: String,
        isGradient: Bool = false,
        background: Color,
        surface: Color,
        surfaceLight: Color,
        surfaceCard: Color,
        primary: Color,
        secondary: Color,
        accent: Color,
        goldBorder: Color,
        goldGlow: Color,
        textPrimary: Color = Color.white,
        textSecondary: Color = Color(red: 0.75, green: 0.72, blue: 0.64),
        textMuted: Color = Color(red: 0.46, green: 0.44, blue: 0.38),
        primaryGradient: LinearGradient,
        surfaceGradient: LinearGradient,
        darkGradient: LinearGradient
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isGradient = isGradient
        self.background = background
        self.surface = surface
        self.surfaceLight = surfaceLight
        self.surfaceCard = surfaceCard
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.goldBorder = goldBorder
        self.goldGlow = goldGlow
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.textMuted = textMuted
        self.primaryGradient = primaryGradient
        self.surfaceGradient = surfaceGradient
        self.darkGradient = darkGradient
    }
}

public class ThemeService: ObservableObject {
    public static let shared = ThemeService()

    private let prefKey = "dovvoplay_selected_theme_id_v3"

    public static let themes: [VisualTheme] = [
        // 1. DEFAULT: NERO & ORO OLED
        VisualTheme(
            id: "oled_gold",
            name: "Oro & Nero OLED (Default)",
            description: "Lusso assoluto con sfondo 100% OLED black e oro metallico 24K",
            isGradient: true,
            background: Color(red: 0.0, green: 0.0, blue: 0.0),
            surface: Color(red: 0.04, green: 0.04, blue: 0.04),
            surfaceLight: Color(red: 0.08, green: 0.07, blue: 0.06),
            surfaceCard: Color(red: 0.07, green: 0.06, blue: 0.05),
            primary: Color(red: 1.0, green: 0.84, blue: 0.0), // #FFD700
            secondary: Color(red: 0.83, green: 0.69, blue: 0.22), // #D4AF37
            accent: Color(red: 1.0, green: 0.90, blue: 0.50),
            goldBorder: Color(red: 0.83, green: 0.69, blue: 0.22, opacity: 0.25),
            goldGlow: Color(red: 1.0, green: 0.84, blue: 0.0, opacity: 0.2),
            textPrimary: Color.white,
            textSecondary: Color(red: 0.75, green: 0.72, blue: 0.64),
            textMuted: Color(red: 0.46, green: 0.44, blue: 0.38),
            primaryGradient: LinearGradient(
                colors: [Color(red: 1.0, green: 0.91, blue: 0.60), Color(red: 0.83, green: 0.69, blue: 0.22), Color(red: 0.67, green: 0.49, blue: 0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            surfaceGradient: LinearGradient(
                colors: [Color(red: 0.11, green: 0.09, blue: 0.05), Color(red: 0.05, green: 0.05, blue: 0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            darkGradient: LinearGradient(
                colors: [Color(red: 0.08, green: 0.07, blue: 0.04), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        ),

        // 2. CYBERPUNK NEON
        VisualTheme(
            id: "cyberpunk_neon",
            name: "Cyberpunk Neon",
            description: "Nero profondo con contrasti ciano elettrico e fucsia fluo",
            isGradient: true,
            background: Color.black,
            surface: Color(red: 0.04, green: 0.03, blue: 0.08),
            surfaceLight: Color(red: 0.07, green: 0.06, blue: 0.14),
            surfaceCard: Color(red: 0.06, green: 0.05, blue: 0.11),
            primary: Color(red: 0.0, green: 0.94, blue: 1.0), // #00F0FF
            secondary: Color(red: 1.0, green: 0.0, blue: 0.5), // #FF007F
            accent: Color(red: 0.54, green: 0.17, blue: 0.89),
            goldBorder: Color(red: 0.0, green: 0.94, blue: 1.0, opacity: 0.25),
            goldGlow: Color(red: 0.0, green: 0.94, blue: 1.0, opacity: 0.2),
            textPrimary: Color.white,
            textSecondary: Color(red: 0.65, green: 0.71, blue: 0.99),
            textMuted: Color(red: 0.39, green: 0.40, blue: 0.95),
            primaryGradient: LinearGradient(colors: [Color(red: 0.0, green: 0.94, blue: 1.0), Color(red: 1.0, green: 0.0, blue: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing),
            surfaceGradient: LinearGradient(colors: [Color(red: 0.08, green: 0.06, blue: 0.16), Color(red: 0.03, green: 0.02, blue: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing),
            darkGradient: LinearGradient(colors: [Color(red: 0.07, green: 0.04, blue: 0.14), Color.black], startPoint: .top, endPoint: .bottom)
        ),

        // 3. MIDNIGHT DIAMOND
        VisualTheme(
            id: "midnight_diamond",
            name: "Midnight & Diamante Glaciale",
            description: "Blu notte abissale con accenti azzurro cristallo puro",
            isGradient: true,
            background: Color.black,
            surface: Color(red: 0.02, green: 0.04, blue: 0.08),
            surfaceLight: Color(red: 0.05, green: 0.09, blue: 0.16),
            surfaceCard: Color(red: 0.03, green: 0.06, blue: 0.12),
            primary: Color(red: 0.22, green: 0.74, blue: 0.97), // #38BDF8
            secondary: Color(red: 0.01, green: 0.52, blue: 0.78),
            accent: Color(red: 0.73, green: 0.90, blue: 0.99),
            goldBorder: Color(red: 0.22, green: 0.74, blue: 0.97, opacity: 0.25),
            goldGlow: Color(red: 0.22, green: 0.74, blue: 0.97, opacity: 0.2),
            textPrimary: Color.white,
            textSecondary: Color(red: 0.58, green: 0.64, blue: 0.72),
            textMuted: Color(red: 0.28, green: 0.33, blue: 0.41),
            primaryGradient: LinearGradient(colors: [Color(red: 0.49, green: 0.83, blue: 0.99), Color(red: 0.01, green: 0.52, blue: 0.78)], startPoint: .topLeading, endPoint: .bottomTrailing),
            surfaceGradient: LinearGradient(colors: [Color(red: 0.05, green: 0.12, blue: 0.22), Color(red: 0.02, green: 0.04, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
            darkGradient: LinearGradient(colors: [Color(red: 0.04, green: 0.09, blue: 0.16), Color.black], startPoint: .top, endPoint: .bottom)
        ),

        // 4. EMERALD LUXURY
        VisualTheme(
            id: "emerald_luxury",
            name: "Smeraldo Reale & Ossidiana",
            description: "Eleganza verde smeraldo brillante e nero grafite",
            isGradient: true,
            background: Color.black,
            surface: Color(red: 0.02, green: 0.07, blue: 0.04),
            surfaceLight: Color(red: 0.04, green: 0.13, blue: 0.08),
            surfaceCard: Color(red: 0.03, green: 0.10, blue: 0.06),
            primary: Color(red: 0.06, green: 0.73, blue: 0.51), // #10B981
            secondary: Color(red: 0.02, green: 0.59, blue: 0.41),
            accent: Color(red: 0.43, green: 0.91, blue: 0.72),
            goldBorder: Color(red: 0.06, green: 0.73, blue: 0.51, opacity: 0.25),
            goldGlow: Color(red: 0.06, green: 0.73, blue: 0.51, opacity: 0.2),
            textPrimary: Color.white,
            textSecondary: Color(red: 0.65, green: 0.95, blue: 0.82),
            textMuted: Color(red: 0.02, green: 0.37, blue: 0.27),
            primaryGradient: LinearGradient(colors: [Color(red: 0.20, green: 0.83, blue: 0.60), Color(red: 0.02, green: 0.59, blue: 0.41)], startPoint: .topLeading, endPoint: .bottomTrailing),
            surfaceGradient: LinearGradient(colors: [Color(red: 0.05, green: 0.17, blue: 0.11), Color(red: 0.02, green: 0.06, blue: 0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
            darkGradient: LinearGradient(colors: [Color(red: 0.03, green: 0.11, blue: 0.07), Color.black], startPoint: .top, endPoint: .bottom)
        ),

        // 5. RUBY CRIMSON
        VisualTheme(
            id: "ruby_crimson",
            name: "Rubino Cremisi & Carbone",
            description: "Rosso rubino pulsante su nero carbone intenso",
            isGradient: true,
            background: Color.black,
            surface: Color(red: 0.08, green: 0.02, blue: 0.03),
            surfaceLight: Color(red: 0.15, green: 0.05, blue: 0.06),
            surfaceCard: Color(red: 0.11, green: 0.04, blue: 0.05),
            primary: Color(red: 0.94, green: 0.27, blue: 0.27), // #EF4444
            secondary: Color(red: 0.86, green: 0.15, blue: 0.15),
            accent: Color(red: 0.99, green: 0.65, blue: 0.65),
            goldBorder: Color(red: 0.94, green: 0.27, blue: 0.27, opacity: 0.25),
            goldGlow: Color(red: 0.94, green: 0.27, blue: 0.27, opacity: 0.2),
            textPrimary: Color.white,
            textSecondary: Color(red: 0.99, green: 0.79, blue: 0.79),
            textMuted: Color(red: 0.60, green: 0.11, blue: 0.11),
            primaryGradient: LinearGradient(colors: [Color(red: 0.97, green: 0.44, blue: 0.44), Color(red: 0.86, green: 0.15, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing),
            surfaceGradient: LinearGradient(colors: [Color(red: 0.17, green: 0.05, blue: 0.07), Color(red: 0.06, green: 0.02, blue: 0.02)], startPoint: .topLeading, endPoint: .bottomTrailing),
            darkGradient: LinearGradient(colors: [Color(red: 0.11, green: 0.03, blue: 0.04), Color.black], startPoint: .top, endPoint: .bottom)
        ),

        // 6. AMETHYST PURPLE
        VisualTheme(
            id: "amethyst_purple",
            name: "Ametista & Velluto Notturno",
            description: "Viola nobiliare vellutato e lilla magnetico",
            isGradient: true,
            background: Color.black,
            surface: Color(red: 0.05, green: 0.02, blue: 0.09),
            surfaceLight: Color(red: 0.10, green: 0.05, blue: 0.17),
            surfaceCard: Color(red: 0.07, green: 0.04, blue: 0.13),
            primary: Color(red: 0.66, green: 0.33, blue: 0.97), // #A855F7
            secondary: Color(red: 0.58, green: 0.20, blue: 0.92),
            accent: Color(red: 0.85, green: 0.71, blue: 1.0),
            goldBorder: Color(red: 0.66, green: 0.33, blue: 0.97, opacity: 0.25),
            goldGlow: Color(red: 0.66, green: 0.33, blue: 0.97, opacity: 0.2),
            textPrimary: Color.white,
            textSecondary: Color(red: 0.91, green: 0.84, blue: 1.0),
            textMuted: Color(red: 0.42, green: 0.13, blue: 0.66),
            primaryGradient: LinearGradient(colors: [Color(red: 0.75, green: 0.52, blue: 0.99), Color(red: 0.58, green: 0.20, blue: 0.92)], startPoint: .topLeading, endPoint: .bottomTrailing),
            surfaceGradient: LinearGradient(colors: [Color(red: 0.14, green: 0.06, blue: 0.23), Color(red: 0.04, green: 0.02, blue: 0.06)], startPoint: .topLeading, endPoint: .bottomTrailing),
            darkGradient: LinearGradient(colors: [Color(red: 0.08, green: 0.04, blue: 0.14), Color.black], startPoint: .top, endPoint: .bottom)
        ),

        // 7. SUNSET ROSE GOLD
        VisualTheme(
            id: "sunset_rosegold",
            name: "Sunset Rose Gold",
            description: "Oro rosa sfumato su tramonto arancio e pesca",
            isGradient: true,
            background: Color.black,
            surface: Color(red: 0.08, green: 0.04, blue: 0.05),
            surfaceLight: Color(red: 0.14, green: 0.07, blue: 0.09),
            surfaceCard: Color(red: 0.11, green: 0.05, blue: 0.07),
            primary: Color(red: 0.98, green: 0.44, blue: 0.52), // #FB7185
            secondary: Color(red: 0.96, green: 0.25, blue: 0.37),
            accent: Color(red: 0.99, green: 0.73, blue: 0.45),
            goldBorder: Color(red: 0.98, green: 0.44, blue: 0.52, opacity: 0.25),
            goldGlow: Color(red: 0.98, green: 0.44, blue: 0.52, opacity: 0.2),
            textPrimary: Color.white,
            textSecondary: Color(red: 1.0, green: 0.89, blue: 0.90),
            textMuted: Color(red: 0.62, green: 0.07, blue: 0.22),
            primaryGradient: LinearGradient(colors: [Color(red: 0.99, green: 0.64, blue: 0.69), Color(red: 0.96, green: 0.25, blue: 0.37)], startPoint: .topLeading, endPoint: .bottomTrailing),
            surfaceGradient: LinearGradient(colors: [Color(red: 0.17, green: 0.08, blue: 0.10), Color(red: 0.06, green: 0.02, blue: 0.03)], startPoint: .topLeading, endPoint: .bottomTrailing),
            darkGradient: LinearGradient(colors: [Color(red: 0.11, green: 0.05, blue: 0.07), Color.black], startPoint: .top, endPoint: .bottom)
        ),

        // 8. SOLAR AMBER
        VisualTheme(
            id: "solar_amber",
            name: "Ambra Solare & Magma",
            description: "Arancione ambra radioso e calore vulcanico",
            isGradient: true,
            background: Color.black,
            surface: Color(red: 0.08, green: 0.04, blue: 0.01),
            surfaceLight: Color(red: 0.14, green: 0.08, blue: 0.03),
            surfaceCard: Color(red: 0.11, green: 0.05, blue: 0.02),
            primary: Color(red: 0.96, green: 0.62, blue: 0.04), // #F59E0B
            secondary: Color(red: 0.85, green: 0.47, blue: 0.02),
            accent: Color(red: 0.99, green: 0.90, blue: 0.54),
            goldBorder: Color(red: 0.96, green: 0.62, blue: 0.04, opacity: 0.25),
            goldGlow: Color(red: 0.96, green: 0.62, blue: 0.04, opacity: 0.2),
            textPrimary: Color.white,
            textSecondary: Color(red: 1.0, green: 0.95, blue: 0.78),
            textMuted: Color(red: 0.57, green: 0.25, blue: 0.05),
            primaryGradient: LinearGradient(colors: [Color(red: 0.98, green: 0.75, blue: 0.14), Color(red: 0.85, green: 0.47, blue: 0.02)], startPoint: .topLeading, endPoint: .bottomTrailing),
            surfaceGradient: LinearGradient(colors: [Color(red: 0.17, green: 0.09, blue: 0.04), Color(red: 0.05, green: 0.03, blue: 0.01)], startPoint: .topLeading, endPoint: .bottomTrailing),
            darkGradient: LinearGradient(colors: [Color(red: 0.11, green: 0.06, blue: 0.02), Color.black], startPoint: .top, endPoint: .bottom)
        ),

        // 9. TITANIUM SILVER
        VisualTheme(
            id: "titanium_silver",
            name: "Titanio & Argento Satinato",
            description: "Finitura metallica fredda in alluminio e titanio spaziale",
            isGradient: false,
            background: Color.black,
            surface: Color(red: 0.07, green: 0.07, blue: 0.08),
            surfaceLight: Color(red: 0.12, green: 0.12, blue: 0.13),
            surfaceCard: Color(red: 0.09, green: 0.09, blue: 0.10),
            primary: Color(red: 0.89, green: 0.91, blue: 0.94), // #E2E8F0
            secondary: Color(red: 0.58, green: 0.64, blue: 0.72),
            accent: Color(red: 0.97, green: 0.98, blue: 0.99),
            goldBorder: Color(red: 0.89, green: 0.91, blue: 0.94, opacity: 0.25),
            goldGlow: Color(red: 0.89, green: 0.91, blue: 0.94, opacity: 0.15),
            textPrimary: Color.white,
            textSecondary: Color(red: 0.79, green: 0.84, blue: 0.88),
            textMuted: Color(red: 0.39, green: 0.45, blue: 0.55),
            primaryGradient: LinearGradient(colors: [Color(red: 0.95, green: 0.96, blue: 0.98), Color(red: 0.58, green: 0.64, blue: 0.72)], startPoint: .topLeading, endPoint: .bottomTrailing),
            surfaceGradient: LinearGradient(colors: [Color(red: 0.12, green: 0.12, blue: 0.14), Color(red: 0.06, green: 0.06, blue: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing),
            darkGradient: LinearGradient(colors: [Color(red: 0.08, green: 0.08, blue: 0.09), Color.black], startPoint: .top, endPoint: .bottom)
        ),

        // 10. MINT MATRIX
        VisualTheme(
            id: "mint_matrix",
            name: "Matrix & Menta Elettrica",
            description: "Verde menta fluorescente ad alto contrasto per OLED",
            isGradient: false,
            background: Color.black,
            surface: Color(red: 0.01, green: 0.08, blue: 0.06),
            surfaceLight: Color(red: 0.03, green: 0.15, blue: 0.12),
            surfaceCard: Color(red: 0.02, green: 0.11, blue: 0.09),
            primary: Color(red: 0.08, green: 0.95, blue: 0.58), // #14F195
            secondary: Color(red: 0.0, green: 0.78, blue: 0.53),
            accent: Color(red: 0.65, green: 0.95, blue: 0.82),
            goldBorder: Color(red: 0.08, green: 0.95, blue: 0.58, opacity: 0.25),
            goldGlow: Color(red: 0.08, green: 0.95, blue: 0.58, opacity: 0.2),
            textPrimary: Color.white,
            textSecondary: Color(red: 0.43, green: 0.91, blue: 0.72),
            textMuted: Color(red: 0.02, green: 0.47, blue: 0.34),
            primaryGradient: LinearGradient(colors: [Color(red: 0.43, green: 0.91, blue: 0.72), Color(red: 0.08, green: 0.95, blue: 0.58)], startPoint: .topLeading, endPoint: .bottomTrailing),
            surfaceGradient: LinearGradient(colors: [Color(red: 0.04, green: 0.18, blue: 0.13), Color(red: 0.01, green: 0.05, blue: 0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
            darkGradient: LinearGradient(colors: [Color(red: 0.03, green: 0.12, blue: 0.09), Color.black], startPoint: .top, endPoint: .bottom)
        ),

        // 11. OCEAN AQUAMARINE
        VisualTheme(
            id: "ocean_aquamarine",
            name: "Oceano Profondo & Acquamarina",
            description: "Verde acqua e blu laguna tropicale",
            isGradient: true,
            background: Color.black,
            surface: Color(red: 0.01, green: 0.07, blue: 0.08),
            surfaceLight: Color(red: 0.03, green: 0.14, blue: 0.16),
            surfaceCard: Color(red: 0.02, green: 0.11, blue: 0.12),
            primary: Color(red: 0.02, green: 0.71, blue: 0.83), // #06B6D4
            secondary: Color(red: 0.03, green: 0.57, blue: 0.70),
            accent: Color(red: 0.40, green: 0.91, blue: 0.98),
            goldBorder: Color(red: 0.02, green: 0.71, blue: 0.83, opacity: 0.25),
            goldGlow: Color(red: 0.02, green: 0.71, blue: 0.83, opacity: 0.2),
            textPrimary: Color.white,
            textSecondary: Color(red: 0.65, green: 0.95, blue: 0.99),
            textMuted: Color(red: 0.08, green: 0.37, blue: 0.46),
            primaryGradient: LinearGradient(colors: [Color(red: 0.13, green: 0.83, blue: 0.93), Color(red: 0.03, green: 0.57, blue: 0.70)], startPoint: .topLeading, endPoint: .bottomTrailing),
            surfaceGradient: LinearGradient(colors: [Color(red: 0.04, green: 0.16, blue: 0.18), Color(red: 0.01, green: 0.05, blue: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
            darkGradient: LinearGradient(colors: [Color(red: 0.03, green: 0.11, blue: 0.12), Color.black], startPoint: .top, endPoint: .bottom)
        ),

        // 12. MONOCHROME PURE OLED
        VisualTheme(
            id: "monochrome_pure",
            name: "Monocromatico Pure Minimal",
            description: "Puro bianco su nero assoluto ad altissimo contrasto",
            isGradient: false,
            background: Color.black,
            surface: Color(red: 0.05, green: 0.05, blue: 0.05),
            surfaceLight: Color(red: 0.10, green: 0.10, blue: 0.10),
            surfaceCard: Color(red: 0.08, green: 0.08, blue: 0.08),
            primary: Color.white,
            secondary: Color(red: 0.80, green: 0.80, blue: 0.80),
            accent: Color(red: 0.93, green: 0.93, blue: 0.93),
            goldBorder: Color.white.opacity(0.25),
            goldGlow: Color.white.opacity(0.15),
            textPrimary: Color.white,
            textSecondary: Color(red: 0.69, green: 0.69, blue: 0.69),
            textMuted: Color(red: 0.40, green: 0.40, blue: 0.40),
            primaryGradient: LinearGradient(colors: [Color.white, Color(red: 0.53, green: 0.53, blue: 0.53)], startPoint: .topLeading, endPoint: .bottomTrailing),
            surfaceGradient: LinearGradient(colors: [Color(red: 0.12, green: 0.12, blue: 0.12), Color(red: 0.04, green: 0.04, blue: 0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
            darkGradient: LinearGradient(colors: [Color(red: 0.08, green: 0.08, blue: 0.08), Color.black], startPoint: .top, endPoint: .bottom)
        )
    ]

    @Published public var currentTheme: VisualTheme

    private init() {
        let savedId = UserDefaults.standard.string(forKey: prefKey) ?? "oled_gold"
        let found = ThemeService.themes.first(where: { $0.id == savedId }) ?? ThemeService.themes[0]
        self.currentTheme = found
    }

    public func setTheme(id: String) {
        if let found = ThemeService.themes.first(where: { $0.id == id }) {
            currentTheme = found
            UserDefaults.standard.set(id, forKey: prefKey)
        }
    }

    public func cycleNextTheme() {
        if let currentIndex = ThemeService.themes.firstIndex(where: { $0.id == currentTheme.id }) {
            let nextIndex = (currentIndex + 1) % ThemeService.themes.count
            setTheme(id: ThemeService.themes[nextIndex].id)
        }
    }
}
