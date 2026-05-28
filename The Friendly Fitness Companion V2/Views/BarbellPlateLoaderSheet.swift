import SwiftUI

struct BarbellPlateLoaderSheet: View {
    let weight: Double
    let unit: String
    let plates: [(plate: Double, count: Int)]
    let barbellName: String
    let barbellWeight: Double
    
    var onApplyWeight: ((Double) -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header Target Weight card
                    VStack(spacing: 12) {
                        Text("Target Weight")
                            .font(Theme.Typography.technical(14, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("\(weight, specifier: "%g") \(unit.uppercased())")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        
                        Text("Barbell: \(barbellName) (\(barbellWeight, specifier: "%g") \(unit))")
                            .font(Theme.Typography.technical(12))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Theme.surface)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Visual Sleeve Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Load on Each Side")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 24)
                        
                        ZStack {
                            Theme.surface
                            
                            BarbellVisualizerView(plates: plates, unit: unit)
                                .padding(.horizontal)
                        }
                        .frame(height: 160)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                    
                    // List of plates needed
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Plate Inventory List")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal)
                        
                        ScrollView {
                            VStack(spacing: 10) {
                                if plates.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "dumbbell.fill")
                                            .font(.largeTitle)
                                            .foregroundColor(Theme.border)
                                        Text("No plates needed. Lift the bar only.")
                                            .font(Theme.Typography.technical(14))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.border, lineWidth: 1)
                                    )
                                } else {
                                    ForEach(plates, id: \.plate) { item in
                                        HStack(spacing: 16) {
                                            Circle()
                                                .fill(plateColor(for: item.plate))
                                                .frame(width: 24, height: 24)
                                                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                                            
                                            Text("\(item.plate, specifier: "%g") \(unit.uppercased()) Plate")
                                                .font(Theme.Typography.technical(14, weight: .bold))
                                                .foregroundColor(Theme.textPrimary)
                                            
                                            Spacer()
                                            
                                            Text("QTY: \(item.count)")
                                                .font(Theme.Typography.technical(14, weight: .black))
                                                .foregroundColor(Theme.accent)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Theme.accent.opacity(0.1))
                                                .cornerRadius(8)
                                        }
                                        .padding()
                                        .background(Theme.surface)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Theme.border, lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    if let onApply = onApplyWeight {
                        Button(action: {
                            HapticManager.shared.playSuccess()
                            onApply(weight)
                            dismiss()
                        }) {
                            Text("Apply Weight to Set")
                                .font(Theme.Typography.technical(16, weight: .bold))
                                .foregroundColor(Theme.midnightMatte)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.accent)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Plate Loading Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func plateColor(for weight: Double) -> Color {
        let isKg = unit.lowercased() == "kg"
        if isKg {
            switch weight {
            case 25.0: return Color.red
            case 20.0: return Color.blue
            case 15.0: return Color.yellow
            case 10.0: return Color.green
            case 5.0: return Color.white
            case 2.5: return Color.black
            default: return Color.gray
            }
        } else {
            switch weight {
            case 45.0: return Color.red
            case 35.0: return Color.blue
            case 25.0: return Color.yellow
            case 10.0: return Color.green
            case 5.0: return Color.white
            case 2.5: return Color.black
            default: return Color.gray
            }
        }
    }
}
