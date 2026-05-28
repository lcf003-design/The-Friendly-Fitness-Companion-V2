import SwiftUI
import SwiftData

struct AnatomicalBodyMap: View {
    enum HeatmapMode {
        case recovery
        case activation
    }
    
    var mode: HeatmapMode = .recovery
    var muscleState: [String: Int]
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
                        // Sci-Fi HUD Wireframe Body Outline
                        BodyOutline(isFront: true)
                        
                        // Head Node (HUD style outline)
                        Circle()
                            .stroke(Theme.border, lineWidth: 2)
                            .background(Circle().fill(Theme.midnightMatte.opacity(0.8)))
                            .frame(width: width * 0.12, height: width * 0.12)
                            .position(x: width * 0.5, y: height * 0.15)
                        
                        // Shoulders
                        GlowingNode(muscleName: "Shoulders", state: muscleState, mode: mode, size: width * 0.12, onNodeTap: onNodeTap)
                            .position(x: width * 0.3, y: height * 0.32)
                        GlowingNode(muscleName: "Shoulders", state: muscleState, mode: mode, size: width * 0.12, onNodeTap: onNodeTap)
                            .position(x: width * 0.7, y: height * 0.32)
                        
                        // Chest (Large Center)
                        GlowingNode(muscleName: "Chest", state: muscleState, mode: mode, size: width * 0.22, onNodeTap: onNodeTap)
                            .position(x: width * 0.5, y: height * 0.38)
                            
                        // Biceps
                        GlowingNode(muscleName: "Biceps", state: muscleState, mode: mode, size: width * 0.1, onNodeTap: onNodeTap)
                            .position(x: width * 0.18, y: height * 0.52)
                        GlowingNode(muscleName: "Biceps", state: muscleState, mode: mode, size: width * 0.1, onNodeTap: onNodeTap)
                            .position(x: width * 0.82, y: height * 0.52)
                        
                        // Abs
                        GlowingNode(muscleName: "Abs", state: muscleState, mode: mode, size: width * 0.15, onNodeTap: onNodeTap)
                            .position(x: width * 0.5, y: height * 0.58)
                            
                        // Quads
                        GlowingNode(muscleName: "Quads", state: muscleState, mode: mode, size: width * 0.16, onNodeTap: onNodeTap)
                            .position(x: width * 0.38, y: height * 0.78)
                        GlowingNode(muscleName: "Quads", state: muscleState, mode: mode, size: width * 0.16, onNodeTap: onNodeTap)
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
                        // Sci-Fi HUD Wireframe Body Outline
                        BodyOutline(isFront: false)
                        
                        // Head Node (HUD style outline)
                        Circle()
                            .stroke(Theme.border, lineWidth: 2)
                            .background(Circle().fill(Theme.midnightMatte.opacity(0.8)))
                            .frame(width: width * 0.12, height: width * 0.12)
                            .position(x: width * 0.5, y: height * 0.15)
                        
                        // Shoulders (Rear Delts)
                        GlowingNode(muscleName: "Shoulders", state: muscleState, mode: mode, size: width * 0.12, onNodeTap: onNodeTap)
                            .position(x: width * 0.3, y: height * 0.32)
                        GlowingNode(muscleName: "Shoulders", state: muscleState, mode: mode, size: width * 0.12, onNodeTap: onNodeTap)
                            .position(x: width * 0.7, y: height * 0.32)
                        
                        // Back (Upper/Mid Back - Large Center)
                        GlowingNode(muscleName: "Back", state: muscleState, mode: mode, size: width * 0.22, onNodeTap: onNodeTap)
                            .position(x: width * 0.5, y: height * 0.38)
                            
                        // Triceps
                        GlowingNode(muscleName: "Triceps", state: muscleState, mode: mode, size: width * 0.1, onNodeTap: onNodeTap)
                            .position(x: width * 0.18, y: height * 0.52)
                        GlowingNode(muscleName: "Triceps", state: muscleState, mode: mode, size: width * 0.1, onNodeTap: onNodeTap)
                            .position(x: width * 0.82, y: height * 0.52)
                        
                        // Glutes
                        GlowingNode(muscleName: "Glutes", state: muscleState, mode: mode, size: width * 0.14, onNodeTap: onNodeTap)
                            .position(x: width * 0.38, y: height * 0.65)
                        GlowingNode(muscleName: "Glutes", state: muscleState, mode: mode, size: width * 0.14, onNodeTap: onNodeTap)
                            .position(x: width * 0.62, y: height * 0.65)
                            
                        // Hamstrings
                        GlowingNode(muscleName: "Hamstrings", state: muscleState, mode: mode, size: width * 0.12, onNodeTap: onNodeTap)
                            .position(x: width * 0.38, y: height * 0.78)
                        GlowingNode(muscleName: "Hamstrings", state: muscleState, mode: mode, size: width * 0.12, onNodeTap: onNodeTap)
                            .position(x: width * 0.62, y: height * 0.78)
                            
                        // Calves
                        GlowingNode(muscleName: "Calves", state: muscleState, mode: mode, size: width * 0.1, onNodeTap: onNodeTap)
                            .position(x: width * 0.38, y: height * 0.90)
                        GlowingNode(muscleName: "Calves", state: muscleState, mode: mode, size: width * 0.1, onNodeTap: onNodeTap)
                            .position(x: width * 0.62, y: height * 0.90)
                    }
                }
            }
        }
        .aspectRatio(1.2, contentMode: .fit)
        .padding(.bottom, 20) // Give space for calves
    }
}

struct BodySilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Neck L
        path.move(to: CGPoint(x: w * 0.45, y: h * 0.26))
        
        // Shoulder L
        path.addLine(to: CGPoint(x: w * 0.30, y: h * 0.30))
        path.addLine(to: CGPoint(x: w * 0.24, y: h * 0.34))
        
        // Arm L outer
        path.addLine(to: CGPoint(x: w * 0.20, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 0.16, y: h * 0.62))
        
        // Hand L bottom
        path.addLine(to: CGPoint(x: w * 0.20, y: h * 0.62))
        
        // Arm L inner
        path.addLine(to: CGPoint(x: w * 0.24, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 0.31, y: h * 0.36))
        
        // Torso L
        path.addLine(to: CGPoint(x: w * 0.34, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 0.38, y: h * 0.65))
        
        // Leg L outer
        path.addLine(to: CGPoint(x: w * 0.34, y: h * 0.78))
        path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.90))
        path.addLine(to: CGPoint(x: w * 0.41, y: h * 0.92))
        
        // Leg L inner
        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.78))
        path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.68))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.68))
        
        // Leg R inner
        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.68))
        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.78))
        path.addLine(to: CGPoint(x: w * 0.59, y: h * 0.92))
        
        // Leg R outer
        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.90))
        path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.78))
        path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.65))
        
        // Torso R
        path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 0.69, y: h * 0.36))
        
        // Arm R inner
        path.addLine(to: CGPoint(x: w * 0.76, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.62))
        
        // Hand R bottom
        path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.62))
        
        // Arm R outer
        path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 0.76, y: h * 0.34))
        
        // Shoulder R
        path.addLine(to: CGPoint(x: w * 0.70, y: h * 0.30))
        path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.26))
        
        path.closeSubpath()
        
        return path
    }
}

struct BodyOutline: View {
    let isFront: Bool
    
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            
            ZStack {
                // Filled solid body silhouette
                BodySilhouette()
                    .fill(Theme.border.opacity(0.35))
                
                // Fine elegant stroke outline
                BodySilhouette()
                    .stroke(Theme.border, lineWidth: 1.5)
                
                // Interior details
                Path { path in
                    if isFront {
                        // Chest outline
                        path.move(to: CGPoint(x: w * 0.36, y: h * 0.35))
                        path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.38))
                        path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.45))
                        
                        path.move(to: CGPoint(x: w * 0.64, y: h * 0.35))
                        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.38))
                        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.45))
                        
                        // Abs line
                        path.move(to: CGPoint(x: w * 0.44, y: h * 0.51))
                        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.51))
                        
                        path.move(to: CGPoint(x: w * 0.43, y: h * 0.58))
                        path.addLine(to: CGPoint(x: w * 0.57, y: h * 0.58))
                        
                        path.move(to: CGPoint(x: w * 0.44, y: h * 0.64))
                        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.64))
                    } else {
                        // Spine center
                        path.move(to: CGPoint(x: w * 0.5, y: h * 0.26))
                        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.65))
                        
                        // Lats / Shoulders
                        path.move(to: CGPoint(x: w * 0.34, y: h * 0.36))
                        path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.44))
                        
                        path.move(to: CGPoint(x: w * 0.66, y: h * 0.36))
                        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.44))
                        
                        // Glutes divider
                        path.move(to: CGPoint(x: w * 0.5, y: h * 0.66))
                        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.74))
                    }
                }
                .stroke(Theme.border.opacity(0.65), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

struct GlowingNode: View {
    let muscleName: String
    let state: [String: Int]
    let mode: AnatomicalBodyMap.HeatmapMode
    let size: CGFloat
    var onNodeTap: ((String) -> Void)?
    
    @Query private var userSettings: [UserSettings]
    
    var body: some View {
        let value = state[muscleName]
        let soreness = userSettings.first?.muscleSorenessMap[muscleName]
        let color = colorForState(value: value, soreness: soreness)
        
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.35), radius: 6, x: 0, y: 3)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 1.5)
            )
            .onTapGesture {
                onNodeTap?(muscleName)
            }
    }
    
    private func colorForState(value: Int?, soreness: Int?) -> Color {
        switch mode {
        case .recovery:
            if let soreness = soreness {
                switch soreness {
                case 0: return Theme.apexGreen
                case 1: return Theme.warningOrange
                case 2: return Theme.dangerRed
                default: break
                }
            }
            guard let val = value else {
                return Theme.apexGreen // Fresh
            }
            if val < 2 { return Theme.dangerRed } // Exhausted
            if val < 4 { return Theme.warningOrange } // Recovering
            return Theme.apexGreen // Fully Recovered
        case .activation:
            guard let val = value else {
                return Theme.border.opacity(0.5) // Untrained / inactive
            }
            if val < 4 { return Theme.border.opacity(0.5) }
            if val < 10 { return Theme.warningOrange }
            return Theme.apexGreen
        }
    }
}

#Preview {
    AnatomicalBodyMap(mode: .recovery, muscleState: [
        "Chest": 1,
        "Abs": 3,
        "Quads": 5,
        "Biceps": 0
    ])
    .padding()
    .background(Theme.midnightMatte)
}
