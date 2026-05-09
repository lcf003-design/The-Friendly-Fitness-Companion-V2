import SwiftUI

final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func playLightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    func playHeavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    func playSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func playPR() {
        // A distinct pattern for hitting a Personal Record
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
        }
    }
}
