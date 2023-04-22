import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import Accelerate

@MainActor
class CameraViewModel: ObservableObject {
    
    struct AccuracyStatus {
        enum Kind {
            case insufficient
            case low
            case good
            case excellent
        }
        
        var value: Float32

        var kind: Kind {
            switch self.value {
            case 0..<2: return .insufficient
            case 2..<4: return .low
            case 4..<7: return .good
            default: return .excellent
            }
        }
    }
    
    // MARK: Controllable properties
    @ObservedObject var camera: Camera
    
    // MARK: Results
    fileprivate(set) var fullPreviewImage: Image?
    fileprivate(set) var measurementAreaImage: Image?
    fileprivate(set) var greenChannelHistory: [(green: Float32, date: Date)] = []
    fileprivate(set) var lastTransform: [(bpm: Float32, intensity: Float32)] = []
    fileprivate(set) var averagedTransform: [(bpm: Float32, intensity: Float32)] = []
    fileprivate(set) var bpmHistory: [(bpm: Float32, date: Date)] = []
    fileprivate(set) var accuracyStatus: AccuracyStatus? = nil
    fileprivate(set) var faceObservation: VNFaceObservation?
    // TODO: General measurement status...
    
    // MARK: Static and constant properties
    static let FFT_SAMPLE_COUNT = 512
    static private let FFT_SAMPLE_COUNT_LOG2: vDSP_Length = 9
    private let fft: vDSP.FFT<DSPSplitComplex>
    private let hannWindow = vDSP.window(ofType: Float32.self, usingSequence: .hanningNormalized, count: FFT_SAMPLE_COUNT, isHalfWindow: false)
    private let sequenceRequestHandler = VNSequenceRequestHandler()
    
    // MARK: Internal variables
    private var samples: [Float32] = []
    private var rawBpmHistory: [(value: Float32, stdDevInverse: Float32)] = []
    private var faceTrackingRequest: VNTrackObjectRequest?
    private var faceDetectionRunning = false
    private var measurementRects: [CGRect] = []
    private var spectrumHistory: [[Float32]] = []
    
    // MARK: Initialisation and deinitialisation
    init() {
        self.fft = vDSP.FFT.init(log2n: Self.FFT_SAMPLE_COUNT_LOG2, radix: .radix2, ofType: DSPSplitComplex.self)!
        self.camera = Camera()
        
        // Sampling task.
        Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { timer in
            Task {
                await self.sampleTask()
            }
        }
        
        // Face detection/tracking task.
        Timer.scheduledTimer(withTimeInterval: 1.0/100.0, repeats: true) { timer in
            Task {
                await self.faceDetectionTask()
                await self.faceTrackingTask()
            }
        }
        
        // FFT task.
        Timer.scheduledTimer(withTimeInterval: 1.0/10.0, repeats: true) { timer in
            Task {
                await self.fftTask()
            }
        }
        
        // BPM task.
        Timer.scheduledTimer(withTimeInterval: 1.0/10.0, repeats: true) { timer in
            Task {
                await self.bpmTask()
            }
            
            Task { @MainActor in
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: Tasks
    private func sampleTask() {
        guard let previewImage = self.camera.latestImage else { return }
        guard let faceTrackingRequest else {
            print("Sampling failed due to face tracking request missing.")
            let finalPreviewImage = previewImage.image
            
            Task { @MainActor in
                self.fullPreviewImage = finalPreviewImage
            }
            return
        }
        
        // Calculate brightness of the green channel in the measurement area.
        Task.detached(priority: .high) {
            // Crop face image.
            let faceCroppingRect = faceTrackingRequest.inputObservation
                .boundingBox.normalize(with: previewImage.extent.size)
            
            // Crop the measurement area.
            let croppingRect = CGRect(center: CGPoint(x: 0.5, y: 0.2), size: CGSize(width: 1.0, height: 0.4))
                .normalize(with: faceCroppingRect.size)
                .offsetBy(dx: faceCroppingRect.minX, dy: faceCroppingRect.minY)
            var measurementRects = await self.measurementRects
            measurementRects.append(croppingRect)
            let finalMeasurementRects = Array(measurementRects.suffix(120))
            
            let averagedCroppingRect = measurementRects.reduce(CGRect.zero, {
                $0.sumCoordinates(with: $1)
            }).divideCoordinates(by: CGFloat(measurementRects.count))
            
            let measurementImage = previewImage.cropped(to: averagedCroppingRect)
            
            // Sample image.
            let sample = await self.calculateBrightness(in: measurementImage)
            
            // Prepare data.
            var samples = await self.samples
            samples.append(sample)
            let trimmedSamples = Array(samples.suffix(Self.FFT_SAMPLE_COUNT))
            
            var greenChannelHistory = await self.greenChannelHistory
            greenChannelHistory.append((sample, .now))
            let trimmedGreenChannelHistory = Array(greenChannelHistory.suffix(Self.FFT_SAMPLE_COUNT))
            
            let finalPreviewImage = previewImage.image
            let finalMeasurementImage = measurementImage.image
            
            // Update data.
            Task { @MainActor in
                self.samples = trimmedSamples
                self.greenChannelHistory = trimmedGreenChannelHistory
                self.fullPreviewImage = finalPreviewImage
                self.measurementAreaImage = finalMeasurementImage
                self.measurementRects = finalMeasurementRects
            }
        }
    }
    
    private func faceDetectionTask() {
        guard self.faceTrackingRequest == nil,
              self.faceDetectionRunning == false,
              let fullImage = self.camera.latestImage else {
            return
        }
        
        // No need to detach: self.detectFace is detached internally.
        Task(priority: .high) {
            if self.faceDetectionRunning == false {
                self.faceDetectionRunning = true
                self.faceTrackingRequest = await self.detectFace(in: fullImage)
                faceDetectionRunning = false
            }
        }
    }
    
    private func faceTrackingTask() {
        guard let previewImage = self.camera.latestImage else { return }
        
        Task {
            await self.trackFace(in: previewImage)
        }
    }
    
    private func fftTask() {
        Task.detached(priority: .medium) {
            // Transform.
            let transform = await self.computeFFT(on: self.samples)
            let fftResult = await self.zipFrequencies(with: transform)
                        
            Task { @MainActor in
                self.lastTransform = fftResult
            }
        }
    }
    
    private func bpmTask() {
        Task.detached(priority: .high) {
            let data = await self.samples
            
            let average = vDSP.sum(data) / Float32(data.count)
            let averageVector = Array(repeating: average, count: data.count)
            
            let dataMinusAverage = vDSP.subtract(data, averageVector)
            
            let invertedStandardDeviation = 1.0 / sqrt(vDSP.sumOfSquares(dataMinusAverage) / Float32(data.count))
            
            let fftResult = await self.lastTransform.map({ point in
                point.intensity
            })
            
            let frequencies = await self.lastTransform.map({ point in
                point.bpm
            })
            
            guard fftResult.count > 0 else { return }
            
            var history = await self.spectrumHistory
            history.append(vDSP.multiply(invertedStandardDeviation, fftResult))
            let trimmedHistory = Array(history.suffix(200))
            
            Task { @MainActor in
                self.spectrumHistory = trimmedHistory
            }
            
            var averageSpectrum = Array(repeating: Float32(0.0), count: fftResult.count)
            for vec in trimmedHistory {
                averageSpectrum = vDSP.add(averageSpectrum, vec)
            }
            
            averageSpectrum = vDSP.multiply(1.0/Float32(history.count), averageSpectrum)
            
            let zippedAverage = averageSpectrum.enumerated().map { spectrumPoint in
                (bpm: frequencies[spectrumPoint.offset], intensity: spectrumPoint.element)
            }
            
            let bpm = zippedAverage.max(by: { a, b in
                a.intensity < b.intensity
            })?.bpm
            
            // Update BPM history atomically.
            var newBpmHistory = await self.bpmHistory
            if let bpm {
                var rawBpmHistory = await self.rawBpmHistory
                rawBpmHistory.append((bpm, invertedStandardDeviation))
                let finalRawBpmHistory = Array(rawBpmHistory.suffix(100))
                
                Task { @MainActor in
                    self.rawBpmHistory = finalRawBpmHistory
                }
                
                let bpmChannel = rawBpmHistory.map { point in
                    point.value
                }
                
                let stdDevChannel = rawBpmHistory.map { point in
                    point.stdDevInverse
                }
                
                let clippedStdDev = vDSP.clip(stdDevChannel, to: 0...5)
                
                let weighedAverageBpm = vDSP.dot(bpmChannel, clippedStdDev) / vDSP.sum(clippedStdDev)
                
                newBpmHistory.append((weighedAverageBpm, Date.now))
                
                Task { @MainActor in
                    if let accuracy = stdDevChannel.last {
                        self.accuracyStatus = AccuracyStatus(value: accuracy)
                    } else {
                        self.accuracyStatus = nil
                    }
                }
            }
            let finalBpmHistory = newBpmHistory.filter({ item in
                item.date.addingTimeInterval(60) > .now
            })
            
            Task { @MainActor in
                self.averagedTransform = zippedAverage
                self.bpmHistory = finalBpmHistory
            }
        }
    }
    
    // MARK: Signal utilities
    private func calculateBrightness(in image: CIImage) async -> Float32 {
        
        await withUnsafeContinuation { continuation in
            Task.detached {
                let width = Int(image.extent.width)
                let height = Int(image.extent.height)
                
                let context = CIContext()
                var bitmap = Data(count: width * height * 4)
                
                bitmap.withUnsafeMutableBytes { bitmapPtr in
                    context.render(image, toBitmap: bitmapPtr.baseAddress!, rowBytes: width * 4, bounds: image.extent, format: .RGBA8, colorSpace: nil)
                }
                
                let array = bitmap.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [UInt8] in
                    let buffer = ptr.bindMemory(to: UInt8.self)
                    return [UInt8](buffer)
                }
                
                let floatArray = [Float32](unsafeUninitializedCapacity: array.count) { buffer, initializedCount in
                    vDSP.convertElements(of: array, to: &buffer)
                    initializedCount = array.count
                }
                
                let decimated = vDSP.downsample(floatArray, decimationFactor: 4, filter: [0.0, 1.0, 0.0, 0.0])
                let average = vDSP.sum(decimated) / Float32(array.count)
                
                continuation.resume(returning: average)
            }
        }
    }
    
    private func computeFFT(on samples: [Float32]) -> [Float32] {
        guard samples.count == Self.FFT_SAMPLE_COUNT else {
            return []
        }
        
        let windowedSamples = vDSP.multiply(samples, self.hannWindow)
        
        let count = Self.FFT_SAMPLE_COUNT / 2
        
        let magnitudes = [Float](unsafeUninitializedCapacity: count + 1) {
            buffer, initializedCount in
            
            var realParts = [Float](repeating: 0, count: count)
            var imagParts = [Float](repeating: 0, count: count)
            realParts.withUnsafeMutableBufferPointer { realPtr in
                imagParts.withUnsafeMutableBufferPointer { imagPtr in
                    var complexSignal = DSPSplitComplex(realp: realPtr.baseAddress!,
                                                        imagp: imagPtr.baseAddress!)
                    
                    windowedSamples.withUnsafeBytes {
                        vDSP.convert(interleavedComplexVector: [DSPComplex]($0.bindMemory(to: DSPComplex.self)),
                                     toSplitComplexVector: &complexSignal)
                    }
                    
                    fft.forward(input: complexSignal,
                                output: &complexSignal)
                    
                    vDSP.squareMagnitudes(complexSignal,
                                          result: &buffer)
                }
            }
            buffer[0] = realParts[0]
            buffer[count] = imagParts[0]
            initializedCount = count + 1
        }
        
        let decibels = vDSP.amplitudeToDecibels(magnitudes, zeroReference: 10)
        
        return decibels
    }
    
    private func zipFrequencies(with values: [Float32], fps: Float32 = 30.0) -> [(bpm: Float32, intensity: Float32)] {
        return [(bpm: Float32, intensity: Float32)](unsafeUninitializedCapacity: values.count) { buffer, initializedCount in
            
            let minimumIndex: Int = 50 * Self.FFT_SAMPLE_COUNT / (Int(fps) * 60)
            let maximumIndex: Int = 100 * Self.FFT_SAMPLE_COUNT / (Int(fps) * 60)
            
            guard values.startIndex <= minimumIndex,
                  values.endIndex >= maximumIndex else {
                      return
                  }
            
            let filteredValues = values[minimumIndex...maximumIndex]
            
            for (transformIndex, intensity) in filteredValues.enumerated() {
                let bpm = Float32(minimumIndex + transformIndex) * fps * 60.0 / Float32(Self.FFT_SAMPLE_COUNT)
                buffer[initializedCount] = (bpm, intensity)
                initializedCount += 1
            }
        }
    }
    
    // MARK: Face detection and tracking
    
    /// This function performs an initial face detection on an image.
    ///
    /// - Parameter image: The image on which detection is performed.
    /// - Returns: A tracking request for the detected face.
    private func detectFace(in image: CIImage) async -> VNTrackObjectRequest? {
        await withUnsafeContinuation { continuation in
            Task.detached(priority: .medium) {
                let faceDetectionRequest = VNDetectFaceRectanglesRequest { request, error in
                    guard error == nil else {
                        continuation.resume(returning: .none)
                        return
                    }
                    
                    guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                          let results = faceDetectionRequest.results,
                          let face = results.first else {
                        
                        continuation.resume(returning: .none)
                        return
                    }
                    
                    continuation.resume(returning: VNTrackObjectRequest(detectedObjectObservation: face))
                }
                
                let imageRequestHandler = VNImageRequestHandler(ciImage: image)
                
                try? imageRequestHandler.perform([faceDetectionRequest])
            }
        }
    }
    
    private func trackFace(in image: CIImage) async {
        guard let faceTrackingRequest else { return }
        
        Task.detached {
            try? self.sequenceRequestHandler.perform([faceTrackingRequest], on: image)
            
            Task { @MainActor in
                guard let result = faceTrackingRequest.results?.first as? VNDetectedObjectObservation else {
                    self.faceTrackingRequest = nil
                    return
                }
                
                if result.confidence > 0.3 {
                    self.faceTrackingRequest?.inputObservation = result
                } else {
                    self.faceTrackingRequest = nil
                }
            }
        }
    }
}

// MARK: Useful CIImage extension
extension CIImage {
    var image: Image? {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(self, from: self.extent) else { return nil }
        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}

// MARK: Useful CGRect extension
extension CGRect {
    init(center: CGPoint, size: CGSize) {
        self = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }
    
    func normalize(with size: CGSize) -> Self {
        return CGRect(
            x: self.minX * size.width,
            y: self.minY * size.height,
            width: self.width * size.width,
            height: self.height * size.height
        )
    }
    
    func sumCoordinates(with other: CGRect) -> CGRect {
        return CGRect(x: self.minX + other.minX,
                      y: self.minY + other.minY,
                      width: self.width + other.width,
                      height: self.height + other.height)
    }
    
    func divideCoordinates(by divider: CGFloat) -> CGRect {
        return CGRect(x: self.minX / divider,
                      y: self.minY / divider,
                      width: self.width / divider,
                      height: self.height / divider)
    }
}

class FakeCameraViewModel: CameraViewModel {
    override init() {
        super.init()
        
        self.camera = FakeCamera()
    }
}
