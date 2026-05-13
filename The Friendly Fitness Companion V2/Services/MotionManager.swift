import Foundation
import CoreMotion
import SwiftUI
import Combine

class MotionManager: ObservableObject {
    static let shared = MotionManager()
    private let motionManager = CMMotionManager()
    
    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0
    
    private init() {
        startTracking()
    }
    
    func startTracking() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            guard let data = data else { return }
            
            // Smooth the values to prevent jitter
            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                self?.pitch = data.attitude.pitch
                self?.roll = data.attitude.roll
            }
        }
    }
    
    func stopTracking() {
        motionManager.stopDeviceMotionUpdates()
    }
}
