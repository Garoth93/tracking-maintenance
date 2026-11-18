import SwiftUI
import UIKit
import UpkeepCore

extension Color {
    init(rgb: RGBColor) {
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }

    init(hex: String) {
        self.init(rgb: RGBColor(hex: hex) ?? RGBColor(red: 0.4, green: 0.31, blue: 0.64))
    }

    /// "#rrggbb" of this color (used by ColorPicker bindings).
    var hexString: String? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return RGBColor(red: Double(r), green: Double(g), blue: Double(b)).hex
    }
}

/// Accent / container / on-container colors for an object or operation.
struct Tones: Sendable {
    let accent: Color
    let container: Color
    let onContainer: Color
}

/// Material 3 color roles generated from the user's seed color.
struct M3Theme: Sendable {
    let dark: Bool
    let primary: Color
    let onPrimary: Color
    let primaryContainer: Color
    let onPrimaryContainer: Color
    let inversePrimary: Color
    let secondaryContainer: Color
    let onSecondaryContainer: Color
    let tertiary: Color
    let tertiaryContainer: Color
    let onTertiaryContainer: Color
    let surface: Color
    let surfaceContainerLowest: Color
    let surfaceContainerLow: Color
    let surfaceContainer: Color
    let surfaceContainerHigh: Color
    let surfaceContainerHighest: Color
    let onSurface: Color
    let onSurfaceVariant: Color
    let outline: Color
    let outlineVariant: Color
    let error: Color
    let errorContainer: Color
    let onErrorContainer: Color
    let warning: Color
    let warningContainer: Color
    let onWarningContainer: Color
    let success: Color
    let successContainer: Color
    let onSuccessContainer: Color

    init(seed: String, dark: Bool) {
        let s = MaterialScheme(seed: seed, dark: dark)
        self.dark = dark
        primary = Color(rgb: s.primary)
        onPrimary = Color(rgb: s.onPrimary)
        primaryContainer = Color(rgb: s.primaryContainer)
        onPrimaryContainer = Color(rgb: s.onPrimaryContainer)
        inversePrimary = Color(rgb: TonalPalette(hex: seed).tone(dark ? 40 : 80))
        secondaryContainer = Color(rgb: s.secondaryContainer)
        onSecondaryContainer = Color(rgb: s.onSecondaryContainer)
        tertiary = Color(rgb: s.tertiary)
        tertiaryContainer = Color(rgb: s.tertiaryContainer)
        onTertiaryContainer = Color(rgb: s.onTertiaryContainer)
        surface = Color(rgb: s.surface)
        surfaceContainerLowest = Color(rgb: s.surfaceContainerLowest)
        surfaceContainerLow = Color(rgb: s.surfaceContainerLow)
        surfaceContainer = Color(rgb: s.surfaceContainer)
        surfaceContainerHigh = Color(rgb: s.surfaceContainerHigh)
        surfaceContainerHighest = Color(rgb: s.surfaceContainerHighest)
        onSurface = Color(rgb: s.onSurface)
        onSurfaceVariant = Color(rgb: s.onSurfaceVariant)
        outline = Color(rgb: s.outline)
        outlineVariant = Color(rgb: s.outlineVariant)
        error = Color(rgb: s.error)
        errorContainer = Color(rgb: s.errorContainer)
        onErrorContainer = Color(rgb: s.onErrorContainer)
        warning = Color(rgb: s.warning)
        warningContainer = Color(rgb: s.warningContainer)
        onWarningContainer = Color(rgb: s.onWarningContainer)
        success = Color(rgb: s.success)
        successContainer = Color(rgb: s.successContainer)
        onSuccessContainer = Color(rgb: s.onSuccessContainer)
    }

    static let fallback = M3Theme(seed: Palette.defaultAccent, dark: false)

    func tones(_ hex: String) -> Tones {
        let t = ItemTones(hex: hex, dark: dark)
        return Tones(accent: Color(rgb: t.accent), container: Color(rgb: t.container), onContainer: Color(rgb: t.onContainer))
    }

    func tones(for status: DueStatus) -> Tones {
        switch status {
        case .ok: return Tones(accent: success, container: successContainer, onContainer: onSuccessContainer)
        case .soon: return Tones(accent: warning, container: warningContainer, onContainer: onWarningContainer)
        case .overdue: return Tones(accent: error, container: errorContainer, onContainer: onErrorContainer)
        }
    }
}

extension EnvironmentValues {
    @Entry var m3: M3Theme = .fallback
}

/// Material 3 type scale, with the rounded system face for an expressive look.
extension Font {
    static let m3DisplaySmall = Font.system(size: 36, weight: .bold, design: .rounded)
    static let m3HeadlineLarge = Font.system(size: 32, weight: .bold, design: .rounded)
    static let m3HeadlineMedium = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let m3HeadlineSmall = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let m3TitleLarge = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let m3TitleMedium = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let m3TitleSmall = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let m3BodyLarge = Font.system(size: 17, weight: .regular)
    static let m3BodyMedium = Font.system(size: 15, weight: .regular)
    static let m3BodySmall = Font.system(size: 13, weight: .regular)
    static let m3LabelLarge = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let m3LabelMedium = Font.system(size: 12, weight: .semibold, design: .rounded)
    static let m3LabelSmall = Font.system(size: 11, weight: .medium, design: .rounded)
}

extension ThemeMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension DayDate {
    /// Binding helper for DatePicker.
    static func binding(_ source: Binding<DayDate>) -> Binding<Date> {
        Binding(
            get: { source.wrappedValue.date() },
            set: { source.wrappedValue = DayDate(date: $0) }
        )
    }
}
