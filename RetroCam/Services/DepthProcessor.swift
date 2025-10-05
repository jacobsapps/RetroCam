import UIKit
import CoreML
import Vision
import AVFoundation

protocol DepthProcessor {
    func processFrame(_ pixelBuffer: CVPixelBuffer, orientation: AVCaptureVideoOrientation, completion: @escaping (UIImage?) -> Void)
}

final class DepthProcessorImpl: DepthProcessor {
    
    private var model: VNCoreMLModel?
    
    init() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let mlModel = try? DepthAnythingV2SmallF16(configuration: MLModelConfiguration()).model,
                  let visionModel = try? VNCoreMLModel(for: mlModel) else {
                return
            }
            self?.model = visionModel
        }
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer, orientation: AVCaptureVideoOrientation, completion: @escaping (UIImage?) -> Void) {
        guard let model = model else {
            completion(nil)
            return
        }
        
        let cgOrientation = orientation.toCGImagePropertyOrientation()
            
        let request = VNCoreMLRequest(model: model) { request, error in
            guard error == nil,
                  let results = request.results as? [VNPixelBufferObservation],
                  let depthMap = results.first?.pixelBuffer else {
                completion(nil)
                return
            }
            
            let image = self.convertToUIImage(pixelBuffer: depthMap, orientation: orientation)
            completion(image)
        }
        
        request.imageCropAndScaleOption = .scaleFill
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: cgOrientation, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
    
    private func convertToUIImage(pixelBuffer: CVPixelBuffer, orientation: AVCaptureVideoOrientation) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        let imageOrientation = orientation.toUIImageOrientation()
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: imageOrientation)
    }
}

extension AVCaptureVideoOrientation {
    func toCGImagePropertyOrientation() -> CGImagePropertyOrientation {
        switch self {
        case .portrait:
            return .right
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .down
        case .landscapeRight:
            return .up
        @unknown default:
            return .right
        }
    }
    
    func toUIImageOrientation() -> UIImage.Orientation {
        switch self {
        case .portrait:
            return .left
        case .portraitUpsideDown:
            return .right
        case .landscapeLeft:
            return .down
        case .landscapeRight:
            return .up
        @unknown default:
            return .left
        }
    }
}
