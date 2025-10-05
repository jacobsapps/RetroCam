import UIKit
import Combine
import Photos

final class RetroCamViewModel {
    
    private let cameraManager: CameraManager
    private let orientationManager: OrientationManager
    private let depthProcessor: DepthProcessor
    private let shaderRenderer = MetalShaderRenderer(config: .standard)
    private var cancellables = Set<AnyCancellable>()
    private var frameProcessingCancellable: AnyCancellable?
    private var isProcessing = false
    private var latestProcessedImage: UIImage?
    private var currentFilter: FilterType = .eightBit
    
    let didCapturePhoto = PassthroughSubject<Void, Never>()
    let processedFrame = PassthroughSubject<UIImage, Never>()
    
    init(cameraManager: CameraManager, orientationManager: OrientationManager, depthProcessor: DepthProcessor) {
        self.cameraManager = cameraManager
        self.orientationManager = orientationManager
        self.depthProcessor = depthProcessor
        setupFrameProcessing()
    }
    
    private var currentScreenAspect: CGFloat {
        let orientation = orientationManager.currentOrientation
        let screenSize = UIScreen.main.bounds.size
        
        switch orientation {
        case .landscapeLeft, .landscapeRight:
            return max(screenSize.width, screenSize.height) / min(screenSize.width, screenSize.height)
        case .portrait, .portraitUpsideDown:
            return min(screenSize.width, screenSize.height) / max(screenSize.width, screenSize.height)
        @unknown default:
            return screenSize.width / screenSize.height
        }
    }
    
    private func setupFrameProcessing() {
        let throttleInterval = currentFilter == .depth ? 66 : 33
        frameProcessingCancellable = cameraManager.framePublisher
            .throttle(for: .milliseconds(throttleInterval), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] pixelBuffer in
                guard let self = self, !self.isProcessing else { return }
                self.isProcessing = true
                
                if self.currentFilter == .depth {
                    let orientation = self.orientationManager.currentOrientation
                    self.depthProcessor.processFrame(pixelBuffer, orientation: orientation) { image in
                        DispatchQueue.main.async {
                            if let image = image {
                                self.latestProcessedImage = image
                                self.processedFrame.send(image)
                            }
                            self.isProcessing = false
                        }
                    }
                } else {
                    DispatchQueue.global(qos: .userInitiated).async {
                        guard let processedBuffer = self.shaderRenderer?.render(pixelBuffer: pixelBuffer),
                              let image = self.convertToUIImage(pixelBuffer: processedBuffer) else {
                            self.isProcessing = false
                            return
                        }
                        
                        DispatchQueue.main.async {
                            self.latestProcessedImage = image
                            self.processedFrame.send(image)
                            self.isProcessing = false
                        }
                    }
                }
            }
    }
    
    func startCamera() {
        cameraManager.startSession()
    }
    
    func stopCamera() {
        cameraManager.stopSession()
    }
    
    func capturePhoto() {
        guard let image = latestProcessedImage else { return }
        let croppedImage = cropImageToScreenAspect(image)
        let orientedImage = applyCorrectOrientation(to: croppedImage)
        saveToPhotoLibrary(orientedImage)
        didCapturePhoto.send()
    }
    
    private func cropImageToScreenAspect(_ image: UIImage) -> UIImage {
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height
        let screenAspect = currentScreenAspect
        
        let cropRect: CGRect
        if imageAspect > screenAspect {
            let newWidth = imageSize.height * screenAspect
            let xOffset = (imageSize.width - newWidth) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: imageSize.height)
        } else {
            let newHeight = imageSize.width / screenAspect
            let yOffset = (imageSize.height - newHeight) / 2
            cropRect = CGRect(x: 0, y: yOffset, width: imageSize.width, height: newHeight)
        }
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    private func applyCorrectOrientation(to image: UIImage) -> UIImage {
        return image
    }
    
    func setFilter(_ filterType: FilterType) {
        currentFilter = filterType
        shaderRenderer?.filterType = filterType
        setupFrameProcessing()
    }
    
    func toggleCamera() {
        cameraManager.toggleCamera()
    }
    
    private func saveToPhotoLibrary(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        })
    }
    
    private func convertToUIImage(pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }
}
