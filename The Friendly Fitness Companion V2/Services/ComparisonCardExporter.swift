import SwiftUI
import Photos

@MainActor
final class ComparisonCardExporter {
    static let shared = ComparisonCardExporter()
    
    private init() {}
    
    func exportBeforeAfterCard(photoBefore: PhysiquePhoto, photoAfter: PhysiquePhoto, completion: @escaping (Bool, String?) -> Void) {
        // Request Photo Library permissions for adding assets
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            self.generateAndSaveImage(photoBefore: photoBefore, photoAfter: photoAfter, completion: completion)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self.generateAndSaveImage(photoBefore: photoBefore, photoAfter: photoAfter, completion: completion)
                    } else {
                        completion(false, "Photo Library access denied.")
                    }
                }
            }
        default:
            completion(false, "Photo access is restricted. Please enable Photo Library permissions in iOS Settings.")
        }
    }
    
    private func generateAndSaveImage(photoBefore: PhysiquePhoto, photoAfter: PhysiquePhoto, completion: @escaping (Bool, String?) -> Void) {
        // Render target size (1200x1200px square card is standard for sharing)
        let cardView = ComparisonCardView(photoBefore: photoBefore, photoAfter: photoAfter)
            .frame(width: 1200, height: 1200)
            
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 1.0 // Render at 1:1 pixel scale
        
        guard let uiImage = renderer.uiImage else {
            completion(false, "Unable to compile the progress card visual layout.")
            return
        }
        
        // Save using performChanges
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(true, nil)
                } else {
                    completion(false, error?.localizedDescription ?? "Could not save to Apple Photos library.")
                }
            }
        }
    }
}

// Custom export card layout matching the modern premium theme
struct ComparisonCardView: View {
    let photoBefore: PhysiquePhoto
    let photoAfter: PhysiquePhoto
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("The Friendly Fitness Companion")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("Physique Progress Card")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.accent)
                }
                Spacer()
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundColor(Theme.accent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .background(Theme.midnightMatte)
            
            // Side-by-Side Images Container
            HStack(spacing: 2) {
                // Before Column
                ZStack(alignment: .topLeading) {
                    if let data = photoBefore.imageData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 599, height: 960)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Theme.surface)
                            .frame(width: 599, height: 960)
                    }
                    
                    // Metadata overlay
                    LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 200)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Before")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.warningOrange)
                            .cornerRadius(8)
                        
                        Text(photoBefore.timestamp.formatted(date: .long, time: .omitted))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.8), radius: 4)
                        
                        if photoBefore.weightAtTime > 0 {
                            Text(String(format: "%.1f lb", photoBefore.weightAtTime))
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(Theme.accent)
                                .shadow(color: .black.opacity(0.8), radius: 4)
                        }
                    }
                    .padding(24)
                }
                
                // After Column
                ZStack(alignment: .topTrailing) {
                    if let data = photoAfter.imageData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 599, height: 960)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Theme.surface)
                            .frame(width: 599, height: 960)
                    }
                    
                    // Metadata overlay
                    LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 200)
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("After")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.accent)
                            .cornerRadius(8)
                        
                        Text(photoAfter.timestamp.formatted(date: .long, time: .omitted))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.8), radius: 4)
                        
                        if photoAfter.weightAtTime > 0 {
                            Text(String(format: "%.1f lb", photoAfter.weightAtTime))
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(Theme.accent)
                                .shadow(color: .black.opacity(0.8), radius: 4)
                        }
                    }
                    .padding(24)
                }
            }
            .frame(height: 960)
            
            // Footer Metrics Banner
            HStack {
                let initial = photoBefore.weightAtTime
                let final = photoAfter.weightAtTime
                if initial > 0 && final > 0 {
                    let delta = final - initial
                    let deltaStr = delta >= 0 ? "+\(String(format: "%.1f", delta)) lb" : "\(String(format: "%.1f", delta)) lb"
                    let deltaColor = delta >= 0 ? Theme.apexGreen : Theme.dangerRed
                    
                    Text("Total Weight Change: \(deltaStr)")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(deltaColor)
                } else {
                    Text("Progress Logged")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("The Friendly Fitness Companion")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .background(Theme.midnightMatte)
        }
        .frame(width: 1200, height: 1200)
        .background(Theme.midnightMatte)
    }
}
