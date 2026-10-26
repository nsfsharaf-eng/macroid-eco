import SwiftUI
import AppKit

/// Adaptive design tokens and semantic styling matching native macOS HIG specifications.
/// Dynamically adjusts between Light Mode and Dark Mode with high contrast and restrained electric-blue accents.
public struct AppTheme {
    // MARK: - Foundation Semantic Colors (Adaptive Light & Dark)
    
    /// Main window content canvas background
    public static var windowBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    /// Card, table, and container surface background
    public static var surfaceBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    /// Secondary elevated card background
    public static var elevatedSurface: Color {
        if #available(macOS 14.0, *) {
            return Color(nsColor: .secondarySystemFill)
        } else {
            return Color(nsColor: .controlBackgroundColor).opacity(0.8)
        }
    }

    /// Grouped content section background
    public static var groupedBackground: Color {
        Color(nsColor: .underPageBackgroundColor)
    }

    // MARK: - Brand & Accent Colors
    public static let electricBlue = Color(red: 14/255, green: 122/255, blue: 254/255)
    public static let electricBlueHover = Color(red: 45/255, green: 140/255, blue: 255/255)

    // MARK: - Status Semantic Colors
    public static let statusAuthorized = Color.green
    public static let statusUnauthorized = Color.orange
    public static let statusOffline = Color.secondary
    public static let statusError = Color.red

    // MARK: - Borders & Dividers
    public static var subtleBorder: Color {
        Color(nsColor: .separatorColor)
    }

    public static let activeBorder = Color(red: 14/255, green: 122/255, blue: 254/255, opacity: 0.6)

    // MARK: - Corner Radii
    public static let cornerRadiusSmall: CGFloat = 6
    public static let cornerRadiusMedium: CGFloat = 10
    public static let cornerRadiusLarge: CGFloat = 14
}

// MARK: - Custom View Modifiers

public struct CardBackgroundModifier: ViewModifier {
    var isSelected: Bool = false

    public func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .fill(AppTheme.surfaceBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(isSelected ? AppTheme.activeBorder : AppTheme.subtleBorder, lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

public extension View {
    func cardStyled(isSelected: Bool = false) -> some View {
        self.modifier(CardBackgroundModifier(isSelected: isSelected))
    }
}
