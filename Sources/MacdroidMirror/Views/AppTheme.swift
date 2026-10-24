import SwiftUI

/// Design tokens and semantic styling matching Macdroid Mirror design specifications:
/// Deep navy and graphite foundation with restrained electric-blue accents.
public struct AppTheme {
    // MARK: - Foundation Colors
    public static let navyBackground = Color(red: 10/255, green: 14/255, blue: 24/255)
    public static let graphiteSurface = Color(red: 20/255, green: 26/255, blue: 38/255)
    public static let elevatedSurface = Color(red: 28/255, green: 36/255, blue: 52/255)

    // MARK: - Accent Colors
    public static let electricBlue = Color(red: 14/255, green: 122/255, blue: 254/255)
    public static let electricBlueGlow = Color(red: 14/255, green: 122/255, blue: 254/255, opacity: 0.25)
    public static let electricBlueHover = Color(red: 45/255, green: 140/255, blue: 255/255)

    // MARK: - Status Semantic Colors
    public static let statusAuthorized = Color(red: 46/255, green: 204/255, blue: 113/255)
    public static let statusUnauthorized = Color(red: 243/255, green: 156/255, blue: 18/255)
    public static let statusOffline = Color(red: 149/255, green: 165/255, blue: 166/255)
    public static let statusError = Color(red: 231/255, green: 76/255, blue: 60/255)

    // MARK: - Borders & Dividers
    public static let subtleBorder = Color.white.opacity(0.08)
    public static let activeBorder = Color(red: 14/255, green: 122/255, blue: 254/255, opacity: 0.5)

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
                    .fill(AppTheme.graphiteSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(isSelected ? AppTheme.activeBorder : AppTheme.subtleBorder, lineWidth: 1)
            )
    }
}

public extension View {
    func cardStyled(isSelected: Bool = false) -> some View {
        self.modifier(CardBackgroundModifier(isSelected: isSelected))
    }
}
