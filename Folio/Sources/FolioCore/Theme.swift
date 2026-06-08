import SwiftUI

/// Reading themes ported from `Previewer.md/src/index.css`.
/// Token names mirror the CSS custom properties so the two
/// implementations stay easy to diff.
public enum AppTheme: String, CaseIterable, Identifiable {
    case vercel
    case claude
    case claudeDark = "claude-dark"
    case lovable
    case spotify
    case dark
    case highContrast = "hc"

    public static let `default`: AppTheme = .vercel

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .claude: "Claude"
        case .claudeDark: "Claude Dark"
        case .lovable: "Lovable"
        case .vercel: "Vercel"
        case .spotify: "Spotify"
        case .dark: "Dark"
        case .highContrast: "High Contrast"
        }
    }

    /// Typographic voice: warm reading themes set headings in New York
    /// (system serif) for an editorial, book-like feel; tool-like themes
    /// keep tight sans headings.
    public var headingDesign: Font.Design {
        switch self {
        case .claude, .claudeDark, .lovable: .serif
        default: .default
        }
    }

    /// Matches `getThemeColorScheme` in theme-class.ts.
    public var colorScheme: ColorScheme {
        switch self {
        case .dark, .highContrast, .claudeDark, .spotify: .dark
        default: .light
        }
    }

    public var palette: ThemePalette {
        switch self {
        case .dark: .dark
        case .highContrast: .highContrast
        case .claude: .claude
        case .claudeDark: .claudeDark
        case .vercel: .vercel
        case .lovable: .lovable
        case .spotify: .spotify
        }
    }
}

public struct ThemePalette: Equatable {
    public let window: Color
    public let editor: Color
    public let preview: Color
    public let border: Color
    public let textPrimary: Color
    public let textSecondary: Color
    public let textMuted: Color
    public let accent: Color
    public let accentHover: Color
    public let accentFg: Color
    public let header: Color
    public let btnBg: Color
    public let btnHover: Color
    public let codeBlockBg: Color
    public let codeBlockFg: Color
    public let codeBlockBorder: Color
    public let inlineCodeBg: Color
    public let inlineCodeFg: Color
    public let inlineCodeBorder: Color

    public static let dark = ThemePalette(
        window: Color(hex: 0x0F172A),
        editor: Color(hex: 0x1E293B),
        preview: Color(hex: 0x0F172A),
        border: Color(hex: 0x334155),
        textPrimary: Color(hex: 0xF8FAFC),
        textSecondary: Color(hex: 0xCBD5E1),
        textMuted: Color(hex: 0x64748B),
        accent: Color(hex: 0x3B82F6),
        accentHover: Color(hex: 0x60A5FA),
        accentFg: Color(hex: 0xFFFFFF),
        header: Color(hex: 0x1E293B),
        btnBg: Color(hex: 0x0F172A),
        btnHover: Color(hex: 0x1E293B),
        codeBlockBg: Color(hex: 0x111827),
        codeBlockFg: Color(hex: 0xF8FAFC),
        codeBlockBorder: Color(hex: 0x334155),
        inlineCodeBg: Color(hex: 0x1E293B),
        inlineCodeFg: Color(hex: 0xE2E8F0),
        inlineCodeBorder: Color(hex: 0x475569)
    )

    public static let highContrast = ThemePalette(
        window: Color(hex: 0x000000),
        editor: Color(hex: 0x000000),
        preview: Color(hex: 0x000000),
        border: Color(hex: 0xFFFFFF),
        textPrimary: Color(hex: 0xFFFFFF),
        textSecondary: Color(hex: 0xFFFF00),
        textMuted: Color(hex: 0xFFFF00),
        accent: Color(hex: 0x00FFFF),
        accentHover: Color(hex: 0x00CCCC),
        accentFg: Color(hex: 0x000000),
        header: Color(hex: 0x000000),
        btnBg: Color(hex: 0x000000),
        btnHover: Color(hex: 0x333333),
        codeBlockBg: Color(hex: 0x000000),
        codeBlockFg: Color(hex: 0xFFFFFF),
        codeBlockBorder: Color(hex: 0x00FFFF),
        inlineCodeBg: Color(hex: 0x111111),
        inlineCodeFg: Color(hex: 0x00FFFF),
        inlineCodeBorder: Color(hex: 0xFFFFFF)
    )

    public static let claude = ThemePalette(
        window: Color(hex: 0xF5F4ED),
        editor: Color(hex: 0xFAF9F5),
        preview: Color(hex: 0xFAF9F5),
        border: Color(hex: 0xF0EEE6),
        textPrimary: Color(hex: 0x141413),
        textSecondary: Color(hex: 0x5E5D59),
        textMuted: Color(hex: 0x87867F),
        accent: Color(hex: 0xC96442),
        accentHover: Color(hex: 0xD97757),
        accentFg: Color(hex: 0xFAF9F5),
        header: Color(hex: 0xF5F4ED),
        btnBg: Color(hex: 0xE8E6DC),
        btnHover: Color(hex: 0xF0EEE6),
        codeBlockBg: Color(hex: 0x30302E),
        codeBlockFg: Color(hex: 0xFAF9F5),
        codeBlockBorder: Color(hex: 0x30302E),
        inlineCodeBg: Color(hex: 0xE8E6DC),
        inlineCodeFg: Color(hex: 0x3D3D3A),
        inlineCodeBorder: Color(hex: 0xD1CFC5)
    )

    public static let claudeDark = ThemePalette(
        window: Color(hex: 0x1A1512),
        editor: Color(hex: 0x211B18),
        preview: Color(hex: 0x211B18),
        border: Color(hex: 0x43312A),
        textPrimary: Color(hex: 0xF6EDE6),
        textSecondary: Color(hex: 0xD6C3B5),
        textMuted: Color(hex: 0xA58D80),
        accent: Color(hex: 0xC96442),
        accentHover: Color(hex: 0xD97757),
        accentFg: Color(hex: 0xFFF8F4),
        header: Color(hex: 0x1A1512),
        btnBg: Color(hex: 0x2A221E),
        btnHover: Color(hex: 0x352A25),
        codeBlockBg: Color(hex: 0x14100E),
        codeBlockFg: Color(hex: 0xF6EDE6),
        codeBlockBorder: Color(hex: 0x4D3830),
        inlineCodeBg: Color(hex: 0x2F2622),
        inlineCodeFg: Color(hex: 0xF2D8CA),
        inlineCodeBorder: Color(hex: 0x4D3830)
    )

    public static let vercel = ThemePalette(
        window: Color(hex: 0xFFFFFF),
        editor: Color(hex: 0xFFFFFF),
        preview: Color(hex: 0xFFFFFF),
        border: Color(hex: 0xEBEBEB),
        textPrimary: Color(hex: 0x171717),
        textSecondary: Color(hex: 0x4D4D4D),
        textMuted: Color(hex: 0x808080),
        accent: Color(hex: 0x0072F5),
        accentHover: Color(hex: 0x0A72EF),
        accentFg: Color(hex: 0xFFFFFF),
        header: Color(hex: 0xFFFFFF),
        btnBg: Color(hex: 0xFFFFFF),
        btnHover: Color(hex: 0xFAFAFA),
        codeBlockBg: Color(hex: 0x111111),
        codeBlockFg: Color(hex: 0xFAFAFA),
        codeBlockBorder: Color(hex: 0x2A2A2A),
        inlineCodeBg: Color(hex: 0xFAFAFA),
        inlineCodeFg: Color(hex: 0x171717),
        inlineCodeBorder: Color(hex: 0xEBEBEB)
    )

    public static let lovable = ThemePalette(
        window: Color(hex: 0xF7F4ED),
        editor: Color(hex: 0xFCFBF8),
        preview: Color(hex: 0xFCFBF8),
        border: Color(hex: 0xECEAE4),
        textPrimary: Color(hex: 0x1C1C1C),
        textSecondary: Color(hex: 0x1C1C1C, alpha: 0.82),
        textMuted: Color(hex: 0x5F5F5D),
        accent: Color(hex: 0x1C1C1C),
        accentHover: Color(hex: 0x111111),
        accentFg: Color(hex: 0xFCFBF8),
        header: Color(hex: 0xF7F4ED),
        btnBg: Color(hex: 0xF7F4ED),
        btnHover: Color(hex: 0x1C1C1C, alpha: 0.04),
        codeBlockBg: Color(hex: 0x1C1C1C),
        codeBlockFg: Color(hex: 0xFCFBF8),
        codeBlockBorder: Color(hex: 0xFFFFFF, alpha: 0.12),
        inlineCodeBg: Color(hex: 0x1C1C1C, alpha: 0.04),
        inlineCodeFg: Color(hex: 0x1C1C1C),
        inlineCodeBorder: Color(hex: 0x1C1C1C, alpha: 0.12)
    )

    public static let spotify = ThemePalette(
        window: Color(hex: 0x121212),
        editor: Color(hex: 0x181818),
        preview: Color(hex: 0x181818),
        border: Color(hex: 0x4D4D4D),
        textPrimary: Color(hex: 0xFFFFFF),
        textSecondary: Color(hex: 0xB3B3B3),
        textMuted: Color(hex: 0x7C7C7C),
        accent: Color(hex: 0x1ED760),
        accentHover: Color(hex: 0x3BE477),
        accentFg: Color(hex: 0x000000),
        header: Color(hex: 0x121212),
        btnBg: Color(hex: 0x1F1F1F),
        btnHover: Color(hex: 0x272727),
        codeBlockBg: Color(hex: 0x0F0F0F),
        codeBlockFg: Color(hex: 0xFDFDFD),
        codeBlockBorder: Color(hex: 0x272727),
        inlineCodeBg: Color(hex: 0x1F1F1F),
        inlineCodeFg: Color(hex: 0xFFFFFF),
        inlineCodeBorder: Color(hex: 0x4D4D4D)
    )
}

extension Color {
    public init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
