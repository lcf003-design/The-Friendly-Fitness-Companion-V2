import SwiftUI

struct BeforeAfterSliderView: View {
    let photoBefore: PhysiquePhoto
    let photoAfter: PhysiquePhoto
    
    @State private var dragPercentage: CGFloat = 0.5
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            
            ZStack(alignment: .leading) {
                // Before Photo (Background)
                if let data1 = photoBefore.imageData, let img1 = UIImage(data: data1) {
                    Image(uiImage: img1)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Theme.surface)
                        .frame(width: size.width, height: size.height)
                }
                
                // After Photo (Foreground, masked/clipped by drag percentage)
                if let data2 = photoAfter.imageData, let img2 = UIImage(data: data2) {
                    Image(uiImage: img2)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .mask(
                            HStack(spacing: 0) {
                                Rectangle()
                                    .frame(width: size.width * dragPercentage)
                                Spacer(minLength: 0)
                            }
                        )
                }
                
                // Split Curtain Handle Line
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 2)
                    .overlay(
                        ZStack {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 44, height: 44)
                                .shadow(color: Theme.accent.opacity(0.4), radius: 8)
                            
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    )
                    .position(x: size.width * dragPercentage, y: size.height / 2)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let locationX = value.location.x
                        dragPercentage = max(0, min(1, locationX / size.width))
                    }
            )
            .overlay(
                // Header indicators
                VStack(spacing: 0) {
                    HStack {
                        // BEFORE Label
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Before")
                                .font(Theme.Typography.technical(10, weight: .black))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.warningOrange)
                                .cornerRadius(4)
                            
                            Text(photoBefore.timestamp.formatted(date: .abbreviated, time: .omitted))
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.8), radius: 4)
                            
                            if photoBefore.weightAtTime > 0 {
                                Text("\(String(format: "%.1f", photoBefore.weightAtTime)) lb")
                                    .font(Theme.Typography.technical(14, weight: .black))
                                    .foregroundColor(Theme.accent)
                                    .shadow(color: .black.opacity(0.8), radius: 4)
                            }
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(8)
                        
                        Spacer()
                        
                        // AFTER Label
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("After")
                                .font(Theme.Typography.technical(10, weight: .black))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.accent)
                                .cornerRadius(4)
                            
                            Text(photoAfter.timestamp.formatted(date: .abbreviated, time: .omitted))
                                .font(Theme.Typography.technical(12, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.8), radius: 4)
                            
                            if photoAfter.weightAtTime > 0 {
                                Text("\(String(format: "%.1f", photoAfter.weightAtTime)) lb")
                                    .font(Theme.Typography.technical(14, weight: .black))
                                    .foregroundColor(Theme.accent)
                                    .shadow(color: .black.opacity(0.8), radius: 4)
                            }
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(8)
                    }
                    .padding()
                    Spacer()
                }
            )
        }
        .aspectRatio(0.75, contentMode: .fit) // Keep standard 3:4 aspect ratio for physique pictures
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border.opacity(0.3), lineWidth: 1)
        )
    }
}
