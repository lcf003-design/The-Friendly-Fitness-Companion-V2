import SwiftUI
import AVFoundation
import SwiftData
import Combine

struct CameraCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Past photos to feed into the ghost overlay
    let previousPhoto: PhysiquePhoto?
    let currentWeight: Double
    let currentPhase: String
    
    @StateObject private var model = CameraModel()
    
    @State private var showGrid = true
    @State private var showGhost = false
    @State private var ghostOpacity: Double = 0.4
    @State private var showOutline = false
    
    var body: some View {
        ZStack {
            Theme.midnightMatte.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Technical Header HUD
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Physique Camera")
                            .font(Theme.Typography.technical(12, weight: .black))
                            .foregroundColor(Theme.textPrimary)
                            .tracking(1.0)
                        Text("Align with previous outlines to track progress")
                            .font(Theme.Typography.technical(9, weight: .bold))
                            .foregroundColor(Theme.accent)
                            .tracking(0.5)
                    }
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.4))
                
                // Viewfinder Area
                ZStack {
                    if model.permissionGranted {
                        CameraPreview(session: model.session)
                            .aspectRatio(0.75, contentMode: .fit) // Standard 3:4 aspect ratio
                    } else {
                        // Diagnostic pattern / fallback for previews and simulator
                        ZStack {
                            Rectangle()
                                .fill(Color.black)
                            
                            // Technical Grid Lines
                            Path { path in
                                for i in 1..<5 {
                                    let offset = CGFloat(i) * 0.2
                                    path.move(to: CGPoint(x: 0, y: 380 * offset))
                                    path.addLine(to: CGPoint(x: 300, y: 380 * offset))
                                    
                                    path.move(to: CGPoint(x: 300 * offset, y: 0))
                                    path.addLine(to: CGPoint(x: 300 * offset, y: 380))
                                }
                            }
                            .stroke(Theme.border.opacity(0.15), lineWidth: 1)
                            
                            VStack(spacing: 12) {
                                Image(systemName: "camera.metering.matrix")
                                    .font(.system(size: 40))
                                    .foregroundColor(Theme.accent)
                                
                                Text(model.errorMessage)
                                    .font(Theme.Typography.technical(12, weight: .black))
                                    .foregroundColor(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                if !model.errorMessage.isEmpty && model.errorMessage != "Simulator Mode" {
                                    Button("Open Settings") {
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                    .font(Theme.Typography.technical(12, weight: .bold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Theme.accent)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .aspectRatio(0.75, contentMode: .fit)
                    }
                    
                    // Viewfinder Grid Overlay
                    if showGrid {
                        GeometryReader { geo in
                            Path { path in
                                // Thirds horizontal grid lines
                                path.move(to: CGPoint(x: 0, y: geo.size.height * 0.33))
                                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.33))
                                path.move(to: CGPoint(x: 0, y: geo.size.height * 0.66))
                                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.66))
                                
                                // Thirds vertical grid lines
                                path.move(to: CGPoint(x: geo.size.width * 0.33, y: 0))
                                path.addLine(to: CGPoint(x: geo.size.width * 0.33, y: geo.size.height))
                                path.move(to: CGPoint(x: geo.size.width * 0.66, y: 0))
                                path.addLine(to: CGPoint(x: geo.size.width * 0.66, y: geo.size.height))
                            }
                            .stroke(Theme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                        .aspectRatio(0.75, contentMode: .fit)
                    }
                    
                    // Translucent Joint Outline
                    if showOutline {
                        BodyOutline(isFront: true)
                            .opacity(0.4)
                            .padding(40)
                            .aspectRatio(0.75, contentMode: .fit)
                            .allowsHitTesting(false)
                    }
                    
                    // Ghost Image Overlay
                    if showGhost, let ghost = previousPhoto, let data = ghost.imageData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .opacity(ghostOpacity)
                            .allowsHitTesting(false)
                            .aspectRatio(0.75, contentMode: .fit)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Theme.border.opacity(0.5), lineWidth: 2)
                )
                .background(Color.black)
                .clipped()
                
                // Opacity Slider for Ghost Overlay
                if showGhost && previousPhoto != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Ghost Opacity")
                                .font(Theme.Typography.technical(9, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("\(Int(ghostOpacity * 100))%")
                                .font(Theme.Typography.technical(10, weight: .black))
                                .foregroundColor(Theme.accent)
                        }
                        .padding(.horizontal)
                        
                        Slider(value: $ghostOpacity, in: 0.05...0.95)
                            .accentColor(Theme.accent)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.2))
                }
                
                // Alignment Viewfinder Controls
                HStack(spacing: 24) {
                    // Grid Toggle
                    Button(action: {
                        HapticManager.shared.playSelection()
                        showGrid.toggle()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: showGrid ? "grid" : "grid.circle")
                                .font(.title3)
                            Text("Grid")
                                .font(Theme.Typography.technical(8, weight: .bold))
                        }
                        .foregroundColor(showGrid ? Theme.accent : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Body Outline Toggle
                    Button(action: {
                        HapticManager.shared.playSelection()
                        showOutline.toggle()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: showOutline ? "figure.arms.open" : "figure.stand")
                                .font(.title3)
                            Text("Outline")
                                .font(Theme.Typography.technical(8, weight: .bold))
                        }
                        .foregroundColor(showOutline ? Theme.accent : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Ghost Toggle
                    Button(action: {
                        HapticManager.shared.playSelection()
                        showGhost.toggle()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: showGhost ? "ghost.fill" : "ghost")
                                .font(.title3)
                        Text("Ghost")
                            .font(Theme.Typography.technical(8, weight: .bold))
                        }
                        .foregroundColor(showGhost ? Theme.accent : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .disabled(previousPhoto == nil)
                        .opacity(previousPhoto == nil ? 0.3 : 1.0)
                    }
                }
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.3))
                
                Spacer()
                
                // Capture Button Area
                HStack {
                    Spacer()
                    
                    Button(action: {
                        model.capturePhoto { data in
                            let photo = PhysiquePhoto(
                                timestamp: Date(),
                                imageData: data,
                                weightAtTime: currentWeight,
                                phaseAtTime: currentPhase
                            )
                            modelContext.insert(photo)
                            try? modelContext.save()
                            
                            HapticManager.shared.playSuccess()
                            dismiss()
                        }
                    }) {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle()
                                    .stroke(Theme.accent, lineWidth: 4)
                                    .padding(4)
                            )
                            .shadow(color: Theme.accent.opacity(0.4), radius: 10)
                    }
                    .disabled(model.isCapturing)
                    
                    Spacer()
                }
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            model.startSession()
        }
        .onDisappear {
            model.stopSession()
        }
    }
}

// Custom Camera Preview UIViewRepresentable
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// Camera Management Controller
class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var permissionGranted = false
    @Published var isCapturing = false
    @Published var errorMessage = ""
    
    private let output = AVCapturePhotoOutput()
    private var photoCallback: ((Data) -> Void)?
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if !granted {
                        self?.errorMessage = "Camera access denied."
                    }
                }
            }
        default:
            permissionGranted = false
            errorMessage = "Camera access restricted."
        }
    }
    
    func startSession() {
        guard permissionGranted else { return }
        
        // Use background thread to configure session (Apple best practice)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning { return }
            
            self.session.beginConfiguration()
            
            // Clear inputs
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }
            
            // Add back camera input
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                DispatchQueue.main.async {
                    self.errorMessage = "Simulator Mode"
                }
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
                
                self.session.commitConfiguration()
                self.session.startRunning()
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Camera config failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if self?.session.isRunning == true {
                self?.session.stopRunning()
            }
        }
    }
    
    func capturePhoto(completion: @escaping (Data) -> Void) {
        guard permissionGranted else {
            // Simulator dummy capture callback for testing & preview integration
            let dummyImage = UIImage(systemName: "figure.arms.open")!
                .withTintColor(.cyan)
            if let dummyData = dummyImage.pngData() {
                completion(dummyData)
            }
            return
        }
        
        isCapturing = true
        photoCallback = completion
        
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        isCapturing = false
        
        if let error = error {
            print("Capture failed: \(error.localizedDescription)")
            return
        }
        
        guard let data = photo.fileDataRepresentation() else {
            print("Could not retrieve image data representation")
            return
        }
        
        photoCallback?(data)
    }
}
