import SwiftUI

struct BarbellVisualizerView: View {
    let plates: [(plate: Double, count: Int)]
    let unit: String
    
    // Maps plate weight to standard color and visual height multiplier
    private func plateProperties(for weight: Double) -> (color: Color, heightMultiplier: CGFloat, width: CGFloat) {
        let isKg = unit.lowercased() == "kg"
        if isKg {
            switch weight {
            case 20.0...:
                return (Color.red, 1.0, 18)
            case 15.0:
                return (Color.blue, 0.9, 18)
            case 10.0:
                return (Color.yellow, 0.8, 16)
            case 5.0:
                return (Color.green, 0.7, 14)
            case 2.5:
                return (Color.white, 0.58, 10)
            default: // 1.25 or smaller
                return (Color.gray, 0.46, 8)
            }
        } else {
            // lbs
            switch weight {
            case 45.0...:
                return (Color.red, 1.0, 18)
            case 35.0:
                return (Color.blue, 0.9, 18)
            case 25.0:
                return (Color.yellow, 0.8, 16)
            case 10.0:
                return (Color.green, 0.7, 14)
            case 5.0:
                return (Color.white, 0.58, 10)
            default: // 2.5 or smaller
                return (Color.gray, 0.46, 8)
            }
        }
    }
    
    // Flat array of all plates to render sequentially
    private var flatPlates: [Double] {
        var result: [Double] = []
        for item in plates {
            for _ in 0..<item.count {
                result.append(item.plate)
            }
        }
        return result
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .leading) {
                // 1. The Steel Barbell Bar (Sleeve extends to the right)
                HStack(spacing: 0) {
                    // Inner bar shaft (left)
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color.gray.opacity(0.8), Color.white, Color.gray],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 30, height: 18)
                    
                    // Stopper/Collar (Tall vertical block)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(
                            colors: [Color.gray, Color.white.opacity(0.8), Color.black],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 14, height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.black.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Barbell Sleeve (Where plates sit)
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color.gray.opacity(0.6), Color.white.opacity(0.8), Color.gray],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(maxWidth: .infinity, maxHeight: 26) // Extends rightward
                        .frame(height: 26)
                        .overlay(
                            Rectangle()
                                .stroke(Color.black.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // 2. The Stacked Plates
                HStack(spacing: 2) {
                    Spacer().frame(width: 44) // Offset past shaft & collar
                    
                    ForEach(0..<flatPlates.count, id: \.self) { index in
                        let weight = flatPlates[index]
                        let props = plateProperties(for: weight)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(props.color)
                            .frame(width: props.width, height: 110 * props.heightMultiplier)
                            .overlay(
                                VStack {
                                    Text("\(weight, specifier: "%g")")
                                        .font(.system(size: 8, weight: .black, design: .monospaced))
                                        .foregroundColor(props.color == .white ? .black : .white)
                                }
                            )
                            .shadow(color: Color.black.opacity(0.4), radius: 2, x: 1, y: 1)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .frame(height: 120)
            .padding(.vertical, 16)
        }
    }
}
