import SwiftUI
import SwiftData
import PhotosUI

struct PhysiqueVaultView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PhysiquePhoto.timestamp, order: .reverse) private var photos: [PhysiquePhoto]
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isProcessingPhoto = false
    
    // Comparison State
    @State private var isCompareMode = false
    @State private var photoOne: PhysiquePhoto? = nil
    @State private var photoTwo: PhysiquePhoto? = nil
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.midnightMatte.ignoresSafeArea()
                
                if photos.isEmpty {
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
                } else if isCompareMode {
                    compareView
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(photos) { photo in
                                vaultPhotoCell(photo)
                            }
                        }
                        .padding()
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
            .navigationTitle(isCompareMode ? "Compare Mode" : "Physique Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.midnightMatte, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isCompareMode {
                        Button("Cancel") {
                            isCompareMode = false
                            photoOne = nil
                            photoTwo = nil
                        }
                        .foregroundColor(Theme.textSecondary)
                    } else {
                        Button("Done") {
                            isPresented = false
                        }
                        .foregroundColor(Theme.textSecondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isCompareMode && photos.count > 1 {
                        Button(action: {
                            isCompareMode = true
                        }) {
                            Image(systemName: "rectangle.split.2x1")
                                .foregroundColor(Theme.accent)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isCompareMode {
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
            if isCompareMode {
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
                // Side by Side View
                HStack(spacing: 8) {
                    if let p1 = photoOne {
                        compareImageCell(p1, label: "BEFORE")
                    }
                    if let p2 = photoTwo {
                        compareImageCell(p2, label: "AFTER")
                    }
                }
                .padding()
                
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
