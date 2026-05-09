import SwiftUI

struct OneRepMaxCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var weightString: String = ""
    @State private var repsString: String = ""
    
    private var estimated1RM: Double {
        let weight = Double(weightString) ?? 0.0
        let reps = Double(repsString) ?? 0.0
        guard weight > 0 && reps > 0 else { return 0.0 }
        
        // Epley Formula
        return weight * (1.0 + (reps / 30.0))
    }
    
    private let percentages: [Double] = [1.0, 0.95, 0.90, 0.85, 0.80, 0.75, 0.70, 0.60]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Inputs
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("LIFTED WEIGHT")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                
                                TextField("0", text: $weightString)
                                    .keyboardType(.decimalPad)
                                    .font(.title.bold())
                                    .foregroundColor(Theme.warningOrange)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("REPS ACHIEVED")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                
                                TextField("0", text: $repsString)
                                    .keyboardType(.numberPad)
                                    .font(.title.bold())
                                    .foregroundColor(Theme.accent)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        
                        // 1RM Hero Display
                        VStack(spacing: 8) {
                            Text("ESTIMATED 1RM")
                                .font(Theme.Typography.technical(14, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .tracking(2)
                            
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(Int(estimated1RM))")
                                    .font(Theme.Typography.technical(60, weight: .black))
                                    .foregroundColor(Theme.textPrimary)
                                
                                Text("lbs")
                                    .font(.title2.bold())
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding(.vertical, 20)
                        
                        // Percentage Breakdown Table
                        if estimated1RM > 0 {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("LOAD PERCENTAGES")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(2)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 0) {
                                    ForEach(percentages, id: \.self) { pct in
                                        HStack {
                                            Text("\(Int(pct * 100))%")
                                                .font(Theme.Typography.technical(16, weight: .bold))
                                                .foregroundColor(pct == 1.0 ? Theme.warningOrange : Theme.textPrimary)
                                            
                                            Spacer()
                                            
                                            Text("\(Int(estimated1RM * pct)) lbs")
                                                .font(.headline)
                                                .foregroundColor(pct == 1.0 ? Theme.warningOrange : Theme.textSecondary)
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 14)
                                        .background(Theme.surface)
                                        .overlay(
                                            Divider().background(Theme.border.opacity(0.3)),
                                            alignment: .bottom
                                        )
                                    }
                                }
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("1RM Calculator")
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
                }
            }
        }
    }
}

#Preview {
    OneRepMaxCalculatorView()
}
