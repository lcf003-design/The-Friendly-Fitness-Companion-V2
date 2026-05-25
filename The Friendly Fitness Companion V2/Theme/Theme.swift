import SwiftUI

extension Color {
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .light ? UIColor(light) : UIColor(dark)
        })
    }
}

enum Theme {
    static let midnightMatte = Color(
        light: Color(red: 0.97, green: 0.97, blue: 0.99), // Soft Off-White
        dark: Color(red: 0.08, green: 0.09, blue: 0.13)   // Deep Slate Blue
    )
    
    static let surface = Color(
        light: Color.white,                               // Pure White
        dark: Color(red: 0.14, green: 0.16, blue: 0.22)   // Sleek Surface Slate
    )
    
    static let border = Color(
        light: Color(red: 0.91, green: 0.92, blue: 0.95), // Light Gray Border
        dark: Color(red: 0.21, green: 0.24, blue: 0.31)   // Dark Slate Border
    )
    
    static let apexGreen = Color(red: 0.15, green: 0.75, blue: 0.42)     // Smooth Emerald Green
    static let warningOrange = Color(red: 0.93, green: 0.55, blue: 0.13)   // Soft Warm Amber
    static let dangerRed = Color(red: 0.91, green: 0.30, blue: 0.30)       // Bright Coral Rose
    
    static let textPrimary = Color(
        light: Color(red: 0.08, green: 0.08, blue: 0.12), // Dark Slate Text
        dark: Color.white
    )
    
    static let textSecondary = Color(
        light: Color(red: 0.45, green: 0.48, blue: 0.55), // Muted Slate Gray
        dark: Color(red: 0.65, green: 0.68, blue: 0.75)   // Muted Slate Silver
    )
    
    static let accent = Color(red: 0.29, green: 0.48, blue: 0.92)         // Premium Cobalt Blue
    
    struct Typography {
        static func technical(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return .system(size: size, weight: weight, design: .rounded)
        }
    }
}
