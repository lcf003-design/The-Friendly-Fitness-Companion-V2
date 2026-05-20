import SwiftUI
import SwiftData

struct AnatomicalBodyMap: View {
    var muscleRecoveryState: [String: Int]
    var onNodeTap: ((String) -> Void)?
    
    var body: some View {
        HStack(spacing: 20) {
            // FRONT
            VStack {
                Text("FRONT")
                    .font(Theme.Typography.technical(10, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    ZStack {
                        // Head
                        Circle().fill(Theme.border).frame(width: width * 0.12, height: width * 0.12).position(x: width * 0.5, y: height * 0.15)
                        
                        // Shoulders
                        GlowingNode(muscleName: "Shoulders", state: muscleRecoveryState, size: width * 0.12, onNodeTap: onNodeTap)
                            .position(x: width * 0.3, y: height * 0.32)
                        GlowingNode(muscleName: "Shoulders", state: muscleRecoveryState, size: width * 0.12, onNodeTap: onNodeTap)
                            .position(x: width * 0.7, y: height * 0.32)
                        
                        // Chest (Large Center)
                        GlowingNode(muscleName: "Chest", state: muscleRecoveryState, size: width * 0.22, onNodeTap: onNodeTap)
                            .position(x: width * 0.5, y: height * 0.38)
                            
                        // Arms
                        GlowingNode(muscleName: "Arms", state: muscleRecoveryState, size: width * 0.1, onNodeTap: onNodeTap)
                            .position(x: width * 0.18, y: height * 0.52)
                        GlowingNode(muscleName: "Arms", state: muscleRecoveryState, size: width * 0.1, onNodeTap: onNodeTap)
                            .position(x: width * 0.82, y: height * 0.52)
                        
                        // Abs
                        GlowingNode(muscleName: "Abs", state: muscleRecoveryState, size: width * 0.15, onNodeTap: onNodeTap)
                            .position(x: width * 0.5, y: height * 0.58)
                            
                        // Quads
                        GlowingNode(muscleName: "Quads", state: muscleRecoveryState, size: width * 0.16, onNodeTap: onNodeTap)
                            .position(x: width * 0.38, y: height * 0.78)
                        GlowingNode(muscleName: "Quads", state: muscleRecoveryState, size: width * 0.16, onNodeTap: onNodeTap)
                            .position(x: width * 0.62, y: height * 0.78)
                    }
                }
            }
            
            // BACK
            VStack {
                Text("BACK")
                    .font(Theme.Typography.technical(10, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    ZStack {
                        // Head
                        Circle().fill(Theme.border).frame(width: width * 0.12, height: width * 0.12).position(x: width * 0.5, y: height * 0.15)
                        
                        // Shoulders (Rear Delts)
                        GlowingNode(muscleName: "Shoulders", state: muscleRecoveryState, size: width * 0.12, onNodeTap: onNodeTap)
                            .position(x: width * 0.3, y: height * 0.32)
                        GlowingNode(muscleName: "Shoulders", state: muscleRecoveryState, size: width * 0.12, onNodeTap: onNodeTap)
                            .position(x: width * 0.7, y: height * 0.32)
                        
                        // Back (Upper/Mid Back - Large Center)
                        GlowingNode(muscleName: "Back", state: muscleRecoveryState, size: width * 0.22, onNodeTap: onNodeTap)
                            .position(x: width * 0.5, y: height * 0.38)
                            
                        // Triceps
                        GlowingNode(muscleName: "Triceps", state: muscleRecoveryState, size: width * 0.1, onNodeTap: onNodeTap)
                            .position(x: width * 0.18, y: height * 0.52)
                        GlowingNode(muscleName: "Triceps", state: muscleRecoveryState, size: width * 0.1, onNodeTap: onNodeTap)
                            .position(x: width * 0.82, y: height * 0.52)
                        
                        // Lats (Combined into Back for this view)
                            
                        // Glutes
                        GlowingNode(muscleName: "Glutes", state: muscleRecoveryState, size: width * 0.14, onNodeTap: onNodeTap)
                            .position(x: width * 0.38, y: height * 0.65)
                        GlowingNode(muscleName: "Glutes", state: muscleRecoveryState, size: width * 0.14, onNodeTap: onNodeTap)
                            .position(x: width * 0.62, y: height * 0.65)
                            
                        // Hamstrings
                        GlowingNode(muscleName: "Hamstrings", state: muscleRecoveryState, size: width * 0.12, onNodeTap: onNodeTap)
                            .position(x: width * 0.38, y: height * 0.78)
                        GlowingNode(muscleName: "Hamstrings", state: muscleRecoveryState, size: width * 0.12, onNodeTap: onNodeTap)
                            .position(x: width * 0.62, y: height * 0.78)
                            
                        // Calves
                        GlowingNode(muscleName: "Calves", state: muscleRecoveryState, size: width * 0.1, onNodeTap: onNodeTap)
                            .position(x: width * 0.38, y: height * 0.90)
                        GlowingNode(muscleName: "Calves", state: muscleRecoveryState, size: width * 0.1, onNodeTap: onNodeTap)
                            .position(x: width * 0.62, y: height * 0.90)
                    }
                }
            }
        }
        .aspectRatio(1.2, contentMode: .fit)
        .padding(.bottom, 20) // Give space for calves
    }
}

struct GlowingNode: View {
    let muscleName: String
    let state: [String: Int]
    let size: CGFloat
    var onNodeTap: ((String) -> Void)?
    
    var body: some View {
        let color = colorForRecovery(days: state[muscleName])
        
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.6), radius: 10, x: 0, y: 0) // The "Glow"
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            // Add a subtle pulse animation if recovering/danger
            .opacity(color == Theme.apexGreen ? 0.8 : 1.0)
            .onTapGesture {
                onNodeTap?(muscleName)
            }
    }
    
    private func colorForRecovery(days: Int?) -> Color {
        guard let days = days else { return Theme.apexGreen } // Untrained = Fresh
        if days < 2 { return Theme.dangerRed } // Exhausted
        if days < 4 { return Theme.warningOrange } // Recovering
        return Theme.apexGreen // Fully Recovered
    }
}

#Preview {
    AnatomicalBodyMap(muscleRecoveryState: [
        "Chest": 1,
        "Abs": 3,
        "Quads": 5,
        "Arms": 0
    ])
    .padding()
    .background(Theme.midnightMatte)
}
