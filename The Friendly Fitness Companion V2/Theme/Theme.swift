import SwiftUI

enum Theme {
    static let midnightMatte = Color(red: 0.05, green: 0.05, blue: 0.08)
    static let surface = Color(red: 0.1, green: 0.1, blue: 0.13)
    static let border = Color(red: 0.18, green: 0.18, blue: 0.22)
    
    static let apexGreen = Color(red: 0.13, green: 0.77, blue: 0.36) // Fully recovered
    static let warningOrange = Color(red: 0.98, green: 0.45, blue: 0.09) // Plateau / < 4 days
    static let dangerRed = Color(red: 0.94, green: 0.27, blue: 0.27) // Failure / < 2 days
    
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.6)
    
    static let accent = Color(red: 0.23, green: 0.51, blue: 0.96) // Blue accent from prototype
    
    struct Typography {
        static func technical(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return .system(size: size, weight: weight, design: .default) // Placeholder for SF Pro Display tight tracking
        }
    }
}
