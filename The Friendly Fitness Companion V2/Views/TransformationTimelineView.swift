import SwiftUI
import Combine

struct TransformationTimelineView: View {
    let photos: [PhysiquePhoto]
    
    // Sort photos chronologically for the timelapse
    private var chronologicalPhotos: [PhysiquePhoto] {
        photos.sorted(by: { $0.timestamp < $1.timestamp })
    }
    
    @State private var currentIndex = 0
    @State private var isPlaying = false
    @State private var playbackSpeed: Double = 1.0 // seconds per slide
    @State private var timerSubscription: Cancellable? = nil
    
    private let speeds = [0.5, 1.0, 1.5, 2.0]
    
    var body: some View {
        VStack(spacing: 16) {
            if chronologicalPhotos.isEmpty {
                Text("NO PHOTOS AVAILABLE")
                    .font(Theme.Typography.technical(14))
                    .foregroundColor(Theme.textSecondary)
            } else {
                let currentPhoto = chronologicalPhotos[currentIndex]
                
                // Photo Viewer Container
                ZStack(alignment: .bottomLeading) {
                    if let data = currentPhoto.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.border.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        Rectangle()
                            .fill(Theme.surface)
                            .frame(height: 380)
                            .cornerRadius(12)
                    }
                    
                    // Metadata overlay
                    LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                        .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentPhoto.timestamp.formatted(date: .long, time: .omitted))
                            .font(Theme.Typography.technical(14, weight: .black))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            if currentPhoto.weightAtTime > 0 {
                                Text("\(String(format: "%.1f", currentPhoto.weightAtTime)) LB")
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .foregroundColor(Theme.accent)
                            }
                            
                            if currentPhoto.phaseAtTime != "N/A" {
                                Text(currentPhoto.phaseAtTime.uppercased())
                                    .font(Theme.Typography.technical(10, weight: .bold))
                                    .foregroundColor(Theme.warningOrange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.warningOrange.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            
                            // Delta from initial photo
                            if currentIndex > 0 {
                                let initialWeight = chronologicalPhotos[0].weightAtTime
                                if initialWeight > 0 && currentPhoto.weightAtTime > 0 {
                                    let delta = currentPhoto.weightAtTime - initialWeight
                                    Text(delta >= 0 ? "+\(String(format: "%.1f", delta)) LB" : "\(String(format: "%.1f", delta)) LB")
                                        .font(Theme.Typography.technical(10, weight: .black))
                                        .foregroundColor(delta >= 0 ? Theme.apexGreen : Theme.dangerRed)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                
                // Playback status bar / frame indicator
                HStack {
                    Text("FRAME \(currentIndex + 1) / \(chronologicalPhotos.count)")
                        .font(Theme.Typography.technical(10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                    
                    Spacer()
                    
                    Text("SPEED: \(String(format: "%.1fs", playbackSpeed))")
                        .font(Theme.Typography.technical(10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.horizontal, 4)
                
                // Scrubbing Slider
                Slider(value: Binding(
                    get: { Double(currentIndex) },
                    set: { currentIndex = Int($0) }
                ), in: 0...Double(chronologicalPhotos.count - 1), step: 1.0)
                .accentColor(Theme.accent)
                .padding(.horizontal, 4)
                
                // Controller Bar
                HStack(spacing: 24) {
                    // Backward step
                    Button(action: {
                        stopPlayback()
                        currentIndex = (currentIndex - 1 + chronologicalPhotos.count) % chronologicalPhotos.count
                    }) {
                        Image(systemName: "backward.frame.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    // Play / Pause Button
                    Button(action: {
                        if isPlaying {
                            stopPlayback()
                        } else {
                            startPlayback()
                        }
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 46))
                            .foregroundColor(Theme.accent)
                    }
                    
                    // Forward step
                    Button(action: {
                        stopPlayback()
                        currentIndex = (currentIndex + 1) % chronologicalPhotos.count
                    }) {
                        Image(systemName: "forward.frame.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    Spacer()
                    
                    // Speed Toggles
                    Picker("Speed", selection: $playbackSpeed) {
                        ForEach(speeds, id: \.self) { speed in
                            Text("\(String(format: "%g", speed))s").tag(speed)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                    .onChange(of: playbackSpeed) { _, _ in
                        if isPlaying {
                            stopPlayback()
                            startPlayback()
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border.opacity(0.2), lineWidth: 1)
        )
        .onDisappear {
            stopPlayback()
        }
    }
    
    private func startPlayback() {
        isPlaying = true
        timerSubscription = Timer.publish(every: playbackSpeed, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                currentIndex = (currentIndex + 1) % chronologicalPhotos.count
            }
    }
    
    private func stopPlayback() {
        isPlaying = false
        timerSubscription?.cancel()
        timerSubscription = nil
    }
}
