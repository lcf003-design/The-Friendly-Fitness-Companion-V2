import SwiftUI
import SwiftData

struct PRRecordBookView: View {
    let allSessions: [WorkoutSession]
    @State private var selectedSubTab = 0 // 0 = Heavyweight, 1 = Tonnage, 2 = Intensity
    
    // MARK: - Computations
    
    // Personal best absolute weight per exercise
    private var absoluteWeightPRs: [(exerciseName: String, weight: Double, date: Date)] {
        var prs: [String: (weight: Double, date: Date)] = [:]
        for session in allSessions {
            for wex in session.exercises {
                let name = wex.exerciseRef?.name ?? "Unknown Exercise"
                for set in wex.sets {
                    if set.isCompleted {
                        if let current = prs[name] {
                            if set.weight > current.weight {
                                prs[name] = (set.weight, session.timestamp)
                            }
                        } else {
                            prs[name] = (set.weight, session.timestamp)
                        }
                    }
                }
            }
        }
        return prs.map { (key, value) in
            (exerciseName: key, weight: value.weight, date: value.date)
        }.sorted(by: { $0.weight > $1.weight })
    }
    
    // Single-set tonnage: weight * reps per set
    private var singleSetTonnagePRs: [(exerciseName: String, tonnage: Double, weight: Double, reps: Int, date: Date)] {
        var prs: [String: (tonnage: Double, weight: Double, reps: Int, date: Date)] = [:]
        for session in allSessions {
            for wex in session.exercises {
                let name = wex.exerciseRef?.name ?? "Unknown Exercise"
                for set in wex.sets {
                    if set.isCompleted {
                        let tonnage = set.weight * Double(set.reps)
                        if let current = prs[name] {
                            if tonnage > current.tonnage {
                                prs[name] = (tonnage, set.weight, set.reps, session.timestamp)
                            }
                        } else {
                            prs[name] = (tonnage, set.weight, set.reps, session.timestamp)
                        }
                    }
                }
            }
        }
        return prs.map { (key, value) in
            (exerciseName: key, tonnage: value.tonnage, weight: value.weight, reps: value.reps, date: value.date)
        }.sorted(by: { $0.tonnage > $1.tonnage })
    }
    
    // Highest single-session total tonnage
    private var highestSessionTonnage: (sessionName: String, tonnage: Double, date: Date)? {
        var record: (sessionName: String, tonnage: Double, date: Date)? = nil
        for session in allSessions {
            var totalTonnage = 0.0
            for wex in session.exercises {
                for set in wex.sets {
                    if set.isCompleted {
                        totalTonnage += set.weight * Double(set.reps)
                    }
                }
            }
            if let current = record {
                if totalTonnage > current.tonnage {
                    record = (session.name, totalTonnage, session.timestamp)
                }
            } else if totalTonnage > 0 {
                record = (session.name, totalTonnage, session.timestamp)
            }
        }
        return record
    }
    
    // Intensity Records
    private var intensityRecords: (
        maxRestPauses: (exerciseName: String, count: Int, date: Date)?,
        maxNegatives: (exerciseName: String, count: Int, date: Date)?,
        maxForcedReps: (exerciseName: String, count: Int, date: Date)?
    ) {
        var maxRP: (exerciseName: String, count: Int, date: Date)? = nil
        var maxNeg: (exerciseName: String, count: Int, date: Date)? = nil
        var maxForced: (exerciseName: String, count: Int, date: Date)? = nil
        
        for session in allSessions {
            for wex in session.exercises {
                let name = wex.exerciseRef?.name ?? "Unknown Exercise"
                for set in wex.sets {
                    if set.isCompleted {
                        let rpCount = set.restPauses.count
                        if rpCount > (maxRP?.count ?? 0) {
                            maxRP = (name, rpCount, session.timestamp)
                        }
                        if set.negatives > (maxNeg?.count ?? 0) {
                            maxNeg = (name, set.negatives, session.timestamp)
                        }
                        if set.forcedReps > (maxForced?.count ?? 0) {
                            maxForced = (name, set.forcedReps, session.timestamp)
                        }
                    }
                }
            }
        }
        return (maxRestPauses: maxRP, maxNegatives: maxNeg, maxForcedReps: maxForced)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("PR Category", selection: $selectedSubTab) {
                Text("HEAVYWEIGHT").tag(0)
                Text("TONNAGE").tag(1)
                Text("INTENSITY").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            if allSessions.isEmpty {
                Spacer()
                Text("NO RECORD DATA FOUND")
                    .font(Theme.Typography.technical(14, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedSubTab {
                        case 0:
                            heavyweightSection
                        case 1:
                            tonnageSection
                        default:
                            intensitySection
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Theme.midnightMatte)
    }
    
    // MARK: - Category Views
    
    private var heavyweightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Horizontal highlight of the overall top 3 lifts
            Text("HALL OF STRENGTH")
                .font(Theme.Typography.technical(12, weight: .black))
                .foregroundColor(Theme.textSecondary)
                .tracking(2)
            
            let topLifts = absoluteWeightPRs.prefix(3)
            if topLifts.isEmpty {
                Text("Log completed sets with weight to see records.")
                    .font(Theme.Typography.technical(12))
                    .foregroundColor(Theme.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<topLifts.count, id: \.self) { index in
                            let pr = topLifts[index]
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "trophy.fill")
                                        .foregroundColor(index == 0 ? .yellow : (index == 1 ? .white : Theme.warningOrange))
                                        .font(.subheadline)
                                    Spacer()
                                    Text("#\(index + 1)")
                                        .font(Theme.Typography.technical(10, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                
                                Text(pr.exerciseName.uppercased())
                                    .font(Theme.Typography.technical(12, weight: .black))
                                    .foregroundColor(Theme.textPrimary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text("\(pr.weight, specifier: "%g") LB")
                                    .font(Theme.Typography.technical(22, weight: .black))
                                    .foregroundColor(Theme.accent)
                                
                                Text(pr.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(Theme.Typography.technical(9))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .frame(width: 140, height: 110)
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.border.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            
            Divider().background(Theme.border.opacity(0.3))
            
            Text("ALL PERSONAL BESTS")
                .font(Theme.Typography.technical(12, weight: .black))
                .foregroundColor(Theme.textSecondary)
                .tracking(2)
            
            ForEach(absoluteWeightPRs, id: \.exerciseName) { pr in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pr.exerciseName.uppercased())
                            .font(Theme.Typography.technical(14, weight: .black))
                            .foregroundColor(Theme.textPrimary)
                        Text("RECORDED: \(pr.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(Theme.Typography.technical(10))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Text("\(pr.weight, specifier: "%g") LB")
                        .font(Theme.Typography.technical(16, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
                .padding()
                .background(Theme.surface)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.border.opacity(0.1), lineWidth: 1)
                )
            }
        }
    }
    
    private var tonnageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Highest Session Tonnage Card
            Text("SESSION VOLUME RECORD")
                .font(Theme.Typography.technical(12, weight: .black))
                .foregroundColor(Theme.textSecondary)
                .tracking(2)
            
            if let bestSession = highestSessionTonnage {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "scalemass.fill")
                            .foregroundColor(Theme.warningOrange)
                            .font(.title3)
                        Spacer()
                        Text("PEAK SESSION")
                            .font(Theme.Typography.technical(10, weight: .bold))
                            .foregroundColor(Theme.warningOrange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.warningOrange.opacity(0.15))
                            .cornerRadius(4)
                    }
                    
                    Text(bestSession.sessionName.uppercased())
                        .font(Theme.Typography.technical(16, weight: .black))
                        .foregroundColor(Theme.textPrimary)
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(bestSession.tonnage, specifier: "%,.0f")")
                            .font(Theme.Typography.technical(36, weight: .black))
                            .foregroundColor(Theme.warningOrange)
                        Text("LB TOTAL VOLUME")
                            .font(Theme.Typography.technical(12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Text("LOCKED IN ON \(bestSession.date.formatted(date: .long, time: .omitted))")
                        .font(Theme.Typography.technical(10))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding()
                .background(Theme.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.border.opacity(0.2), lineWidth: 1)
                )
            } else {
                Text("No session records calculated yet.")
                    .font(Theme.Typography.technical(12))
                    .foregroundColor(Theme.textSecondary)
            }
            
            Divider().background(Theme.border.opacity(0.3))
            
            Text("SINGLE-SET VOLUME BESTS")
                .font(Theme.Typography.technical(12, weight: .black))
                .foregroundColor(Theme.textSecondary)
                .tracking(2)
            
            ForEach(singleSetTonnagePRs, id: \.exerciseName) { pr in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pr.exerciseName.uppercased())
                            .font(Theme.Typography.technical(14, weight: .black))
                            .foregroundColor(Theme.textPrimary)
                        Text("\(pr.weight, specifier: "%g") LB × \(pr.reps) REPS")
                            .font(Theme.Typography.technical(11))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(pr.tonnage, specifier: "%g") LB")
                            .font(Theme.Typography.technical(16, weight: .bold))
                            .foregroundColor(Theme.warningOrange)
                        Text(pr.date.formatted(date: .abbreviated, time: .omitted))
                            .font(Theme.Typography.technical(9))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding()
                .background(Theme.surface)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.border.opacity(0.1), lineWidth: 1)
                )
            }
        }
    }
    
    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("HIGH INTENSITY BREAKTHROUGHS")
                .font(Theme.Typography.technical(12, weight: .black))
                .foregroundColor(Theme.textSecondary)
                .tracking(2)
            
            let records = intensityRecords
            
            // Rest-Pause Card
            if let rp = records.maxRestPauses {
                intensityCard(
                    title: "MOST REST-PAUSES IN A SET",
                    value: "\(rp.count) INTERRUPTIONS",
                    exercise: rp.exerciseName,
                    date: rp.date,
                    color: Theme.accent,
                    icon: "playpause.fill"
                )
            }
            
            // Negatives Card
            if let neg = records.maxNegatives {
                intensityCard(
                    title: "MOST NEGATIVES IN A SET",
                    value: "\(neg.count) ECCENTRICS",
                    exercise: neg.exerciseName,
                    date: neg.date,
                    color: Theme.dangerRed,
                    icon: "arrow.down.forward.and.arrow.up.backward"
                )
            }
            
            // Forced Reps Card
            if let forced = records.maxForcedReps {
                intensityCard(
                    title: "MOST ASSISTED / FORCED REPS",
                    value: "\(forced.count) FORCED",
                    exercise: forced.exerciseName,
                    date: forced.date,
                    color: Theme.apexGreen,
                    icon: "hands.sparkles.fill"
                )
            }
            
            if records.maxRestPauses == nil && records.maxNegatives == nil && records.maxForcedReps == nil {
                Text("No intensity techniques logged yet.")
                    .font(Theme.Typography.technical(12))
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
    
    private func intensityCard(title: String, value: String, exercise: String, date: Date, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(Theme.Typography.technical(10, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            
            Text(exercise.uppercased())
                .font(Theme.Typography.technical(16, weight: .black))
                .foregroundColor(Theme.textPrimary)
            
            Text(value)
                .font(Theme.Typography.technical(22, weight: .black))
                .foregroundColor(color)
            
            Text("SET RECORDED ON \(date.formatted(date: .long, time: .omitted))")
                .font(Theme.Typography.technical(10))
                .foregroundColor(Theme.textSecondary)
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border.opacity(0.2), lineWidth: 1)
        )
    }
}
