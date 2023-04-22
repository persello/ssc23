import Foundation
import SwiftUI
import AVFoundation

class Camera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private var captureSession: AVCaptureSession
    private var sessionQueue: DispatchQueue!
    
    fileprivate(set) var latestImage: CIImage?
    
    var running: Bool {
        return captureSession.isRunning
    }
    
    override init() {
        
        // Create the session queue.
        self.sessionQueue = DispatchQueue(label: "com.persello.Pulse.sessionQueue", qos: .background)
        
        // Create a capture session.
        self.captureSession = AVCaptureSession()
        self.captureSession.sessionPreset = .high
        
        super.init()
        
        // Discover a front camera for video capture.
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Cannot get a capture device.")
            return
        }
        
        try! frontCamera.lockForConfiguration()
        
        frontCamera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
        frontCamera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        
        frontCamera.unlockForConfiguration()
        
        // Attach camera to capture session input.
        let input = try! AVCaptureDeviceInput(device: frontCamera)
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
            print("Added input to capture device.")
        } else {
            print("Cannot add input to capture device.")
        }
        
        // Create and configure video data output.
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        let videoQueue = DispatchQueue(label: "com.persello.pulse.videoQueue", qos: .background)
        videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            print("Added output to capture device.")
        } else {
            print("Cannot add output to capture device.")
        }
        
        if let captureConnection = videoDataOutput.connection(with: .video) {
#if os(iOS)
            if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
                captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
                print("Intrinsic matrix delivery enabled.")
            } else {
                print("Intrinsic matrix delivery not supported.")
            }
#endif
            
            //            if captureConnection.isVideoMirroringSupported {
            //                captureConnection.automaticallyAdjustsVideoMirroring = false
            //                captureConnection.isVideoMirrored = true
            //            }
            captureConnection.isEnabled = true
        }
        
        captureSession.commitConfiguration()
    }
    
    func start() {
        Task {
            let authorized = await checkAuthorization()
            guard authorized else {
                print("Camera access was not authorized.")
                return
            }
            
            if !captureSession.isRunning {
                sessionQueue.async { [self] in
                    self.captureSession.startRunning()
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    private func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("Camera access authorized.")
            return true
        case .notDetermined:
            print("Camera access not determined.")
            sessionQueue.suspend()
            let status = await AVCaptureDevice.requestAccess(for: .video)
            sessionQueue.resume()
            return status
        case .denied:
            print("Camera access denied.")
            return false
        case .restricted:
            print("Camera library access restricted.")
            return false
        @unknown default:
            return false
        }
    }
    
    func stop() {
        if captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.stopRunning()
                self.objectWillChange.send()
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        
#if os(iOS)
        Task { @MainActor in
            
            if let interfaceOrientation = UIApplication.shared.keyWindow?.windowScene?.interfaceOrientation {
                
                switch interfaceOrientation {
                case .portrait:
                    connection.videoOrientation = .portrait
                    
                case .portraitUpsideDown:
                    connection.videoOrientation = .portraitUpsideDown
                    
                case .landscapeLeft:
                    connection.videoOrientation = .landscapeLeft
                    
                case .landscapeRight:
                    connection.videoOrientation = .landscapeRight
                    
                default:
                    break
                }
            }
        }
#endif
        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        DispatchQueue.main.async {
            self.latestImage = ciImage
        }
    }
}

#if os(iOS)
extension UIApplication {
    var keyWindow: UIWindow? {
        // Get connected scenes
        return UIApplication.shared.connectedScenes
        // Keep only active scenes, onscreen and visible to the user
            .filter { $0.activationState == .foregroundActive }
        // Keep only the first `UIWindowScene`
            .first(where: { $0 is UIWindowScene })
        // Get its associated windows
            .flatMap({ $0 as? UIWindowScene })?.windows
        // Finally, keep only the key window
            .first(where: \.isKeyWindow)
    }
}
#endif

class FakeCamera: Camera {
    private var ciImage: CIImage!
    
    override init() {
        super.init()
        
        let image = #imageLiteral(resourceName: "eddy_cue")
#if os(macOS)
        var rect = CGRect(origin: .zero, size: image.size)
        let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
#else
        let cgImage = image.cgImage
#endif
        
        self.ciImage = CIImage(cgImage: cgImage!)
    }
    
    override var running: Bool {
        return true
    }
    
    override func start() {
        Timer.scheduledTimer(withTimeInterval: 1.0/200.0, repeats: true) { timer in
            Task { @MainActor in
                self.latestImage = self.ciImage
            }
        }
    }
    
    override func stop() { }
}
