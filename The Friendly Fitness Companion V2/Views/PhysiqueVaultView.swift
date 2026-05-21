import SwiftUI
import SwiftData
import PhotosUI

struct PhysiqueVaultView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PhysiquePhoto.timestamp, order: .reverse) private var photos: [PhysiquePhoto]
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isProcessingPhoto = false
    
    enum VaultTab: Int {
        case gallery = 0
        case compare = 1
        case timelapse = 2
    }
    @State private var selectedTab = VaultTab.gallery
    @State private var photoOne: PhysiquePhoto? = nil
    @State private var photoTwo: PhysiquePhoto? = nil
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if !photos.isEmpty {
                        Picker("Vault Mode", selection: $selectedTab) {
                            Text("GALLERY").tag(VaultTab.gallery)
                            Text("COMPARE").tag(VaultTab.compare)
                            Text("TIMELAPSE").tag(VaultTab.timelapse)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    }
                    
                    if photos.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 64))
                                .foregroundColor(Theme.textSecondary)
                            Text("VAULT EMPTY")
                                .font(Theme.Typography.technical(16, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                            Text("Log your first physique photo to start tracking visual progression.")
                                .font(Theme.Typography.technical(14))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        Spacer()
                    } else {
                        switch selectedTab {
                        case .gallery:
                            ScrollView {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(photos) { photo in
                                        vaultPhotoCell(photo)
                                    }
                                }
                                .padding()
                            }
                        case .compare:
                            compareView
                        case .timelapse:
                            ScrollView {
                                TransformationTimelineView(photos: photos)
                                    .padding()
                            }
                        }
                    }
                }
                
                if isProcessingPhoto {
                    ZStack {
                        Color.black.opacity(0.6).ignoresSafeArea()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(Theme.accent)
                    }
                }
            }
            .navigationTitle("Physique Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(Theme.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == .gallery {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                            Image(systemName: "plus")
                                .font(.headline)
                                .foregroundColor(Theme.accent)
                        }
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let newItem = newItem {
                        isProcessingPhoto = true
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                            let photo = PhysiquePhoto(
                                timestamp: Date(),
                                imageData: data,
                                weightAtTime: 0, // In a real app we'd fetch current UserSettings, but ProfileView handles primary ingestion
                                phaseAtTime: "N/A"
                            )
                            modelContext.insert(photo)
                            try? modelContext.save()
                        }
                        selectedPhotoItem = nil
                        isProcessingPhoto = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Subcomponents
    
    private func vaultPhotoCell(_ photo: PhysiquePhoto) -> some View {
        Button(action: {
            if selectedTab == .compare {
                // Ignore taps in compare mode if we are building the selection grid,
                // but actually, we could let them select from here.
            } else {
                // Maybe open a full screen detail view
            }
        }) {
            ZStack(alignment: .bottomLeading) {
                if let data = photo.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Theme.surface)
                        .aspectRatio(1, contentMode: .fit)
                }
                
                // Overlay gradient for text readability
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(photo.timestamp.formatted(date: .numeric, time: .omitted))
                        .font(Theme.Typography.technical(10, weight: .bold))
                        .foregroundColor(.white)
                    if photo.weightAtTime > 0 {
                        Text("\(String(format: "%.1f", photo.weightAtTime)) lb")
                            .font(Theme.Typography.technical(10, weight: .regular))
                            .foregroundColor(Theme.accent)
                    }
                }
                .padding(8)
            }
            .cornerRadius(8)
            .contextMenu {
                Button(role: .destructive) {
                    modelContext.delete(photo)
                    try? modelContext.save()
                } label: {
                    Label("Delete Photo", systemImage: "trash")
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var compareView: some View {
        VStack {
            if photoOne == nil || photoTwo == nil {
                Text("Select two photos to compare")
                    .font(Theme.Typography.technical(14, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .padding()
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(photos) { photo in
                            Button(action: {
                                if photoOne == nil {
                                    photoOne = photo
                                } else if photoTwo == nil && photo.id != photoOne?.id {
                                    photoTwo = photo
                                }
                            }) {
                                vaultPhotoCell(photo)
                                    .opacity(photo.id == photoOne?.id ? 0.3 : 1.0)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(photo.id == photoOne?.id ? Theme.accent : Color.clear, lineWidth: 3)
                                    )
                            }
                        }
                    }
                    .padding()
                }
            } else {
                // Curtain Slider View
                if let p1 = photoOne, let p2 = photoTwo {
                    let sorted = [p1, p2].sorted(by: { $0.timestamp < $1.timestamp })
                    BeforeAfterSliderView(photoBefore: sorted[0], photoAfter: sorted[1])
                        .padding()
                }
                
                Spacer()
                
                Button(action: {
                    photoOne = nil
                    photoTwo = nil
                }) {
                    Text("SELECT NEW PHOTOS")
                        .font(Theme.Typography.technical(14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.accent)
                        .cornerRadius(12)
                }
                .padding()
            }
        }
    }
    
    private func compareImageCell(_ photo: PhysiquePhoto, label: String) -> some View {
        VStack {
            Text(label)
                .font(Theme.Typography.technical(14, weight: .bold))
                .foregroundColor(Theme.textSecondary)
            
            if let data = photo.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            VStack(spacing: 4) {
                Text(photo.timestamp.formatted(date: .abbreviated, time: .omitted))
                    .font(Theme.Typography.technical(12, weight: .bold))
                    .foregroundColor(.white)
                
                if photo.weightAtTime > 0 {
                    Text("\(String(format: "%.1f", photo.weightAtTime)) lb")
                        .font(Theme.Typography.technical(14, weight: .black))
                        .foregroundColor(Theme.accent)
                }
                
                if photo.phaseAtTime != "N/A" {
                    Text(photo.phaseAtTime.uppercased())
                        .font(Theme.Typography.technical(10, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }
}
