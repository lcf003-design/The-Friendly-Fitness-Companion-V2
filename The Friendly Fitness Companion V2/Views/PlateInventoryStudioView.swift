import SwiftUI
import SwiftData

struct PlateInventoryStudioView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var settings: UserSettings
    
    // Barbell types
    private var barbellOptions: [(name: String, weightLb: Double, weightKg: Double, desc: String)] {
        [
            ("Olympic Bar", 45.0, 20.0, "Standard 7ft bar for general training & lifts."),
            ("Powerlifting Bar", 55.0, 25.0, "Thicker, stiffer bar optimized for heavy lifts."),
            ("Junior / Women's Bar", 33.0, 15.0, "Shorter bar with narrower grip diameter."),
            ("EZ-Curl Bar", 25.0, 10.0, "Angled shaft to reduce wrist stress during curls.")
        ]
    }
    
    private var isKg: Bool {
        settings.weightUnit == "kg"
    }
    
    private var standardPlates: [Double] {
        isKg ? [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25] : [45.0, 35.0, 25.0, 10.0, 5.0, 2.5]
    }
    
    private var activePlates: [Double] {
        let csv = settings.availablePlatesCSV
        let parsed = csv.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        let intersected = parsed.filter { standardPlates.contains($0) }
        return intersected.isEmpty ? standardPlates : intersected
    }
    
    var body: some View {
        ZStack {
            Theme.midnightMatte.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Barbell & Plates Studio")
                            .font(Theme.Typography.technical(10, weight: .bold))
                            .foregroundColor(Theme.warningOrange)
                            .tracking(2)
                        
                        Text("Configure your active gym layout to customize visual load alerts and plate loaders.")
                            .font(Theme.Typography.technical(12))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // SECTION 1: BARBELL SELECTION
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Active Barbell")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1.5)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(barbellOptions, id: \.name) { bar in
                                let barWeight = isKg ? bar.weightKg : bar.weightLb
                                let isSelected = settings.barbellType == bar.name
                                
                                Button(action: {
                                    HapticManager.shared.playSelection()
                                    settings.barbellType = bar.name
                                    settings.barbellWeight = barWeight
                                    try? modelContext.save()
                                }) {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(isSelected ? Theme.accent.opacity(0.15) : Color.white.opacity(0.03))
                                                .frame(width: 40, height: 40)
                                                .overlay(Circle().stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1.5))
                                            
                                            Image(systemName: "dumbbell.fill")
                                                .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(bar.name)
                                                .font(Theme.Typography.technical(14, weight: .black))
                                                .foregroundColor(isSelected ? .white : Theme.textPrimary)
                                            
                                            Text(bar.desc)
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                                .multilineTextAlignment(.leading)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(barWeight, specifier: "%g") \(settings.weightUnit)")
                                            .font(Theme.Typography.technical(12, weight: .bold))
                                            .foregroundColor(isSelected ? Theme.warningOrange : Theme.textSecondary)
                                    }
                                    .padding()
                                    .background(isSelected ? Theme.surface : Theme.surface.opacity(0.5))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(isSelected ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // SECTION 2: PLATES INVENTORY
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Plate Inventory")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1.5)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            Text("Tap plates to toggle availability in loading calculations.")
                                .font(Theme.Typography.technical(11))
                                .foregroundColor(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 75, maximum: 100))], spacing: 12) {
                                ForEach(standardPlates, id: \.self) { plate in
                                    let isActive = activePlates.contains(plate)
                                    
                                    Button(action: {
                                        HapticManager.shared.playSelection()
                                        togglePlate(plate)
                                    }) {
                                        VStack(spacing: 6) {
                                            Text("\(plate, specifier: "%g")")
                                                .font(.system(size: 20, weight: .black, design: .rounded))
                                                .foregroundColor(isActive ? .black : Theme.textSecondary)
                                            
                                            Text(settings.weightUnit.uppercased())
                                                .font(Theme.Typography.technical(9, weight: .bold))
                                                .foregroundColor(isActive ? .black.opacity(0.7) : Theme.textSecondary.opacity(0.7))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(isActive ? Theme.accent : Theme.surface)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(isActive ? Theme.accent : Theme.border, lineWidth: 1)
                                        )
                                        .shadow(color: isActive ? Theme.accent.opacity(0.3) : .clear, radius: 4)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Theme.surface.opacity(0.3))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                        .padding(.horizontal)
                    }
                    
                    // SECTION 3: GRAPHICAL BARBELL PREVIEW
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Barbell Sleeve Preview")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1.5)
                            .padding(.horizontal)
                        
                        let currentPlates = activePlates.map { (plate: $0, count: 1) }
                        BarbellVisualizerView(plates: currentPlates, unit: settings.weightUnit)
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("Barbell & Plates Studio")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func togglePlate(_ plate: Double) {
        var current = activePlates
        if current.contains(plate) {
            // Keep at least one plate
            if current.count > 1 {
                current.removeAll { $0 == plate }
            }
        } else {
            current.append(plate)
        }
        current.sort(by: >)
        settings.availablePlatesCSV = current.map { String($0) }.joined(separator: ",")
        try? modelContext.save()
    }
}
