import AVFoundation
import UIKit
import Combine

protocol CameraManager {
    var previewLayer: AVCaptureVideoPreviewLayer { get }
    var framePublisher: PassthroughSubject<CVPixelBuffer, Never> { get }
    func startSession()
    func stopSession()
    func capturePhoto(completion: @escaping (Result<UIImage, Error>) -> Void)
    func toggleCamera()
}

final class CameraManagerImpl: NSObject, CameraManager {
    
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let orientationManager: OrientationManager
    private var photoCaptureCompletion: ((Result<UIImage, Error>) -> Void)?
    private var currentPosition: AVCaptureDevice.Position = .back
    private var cancellables = Set<AnyCancellable>()
    
    let framePublisher = PassthroughSubject<CVPixelBuffer, Never>()
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
    
    init(orientationManager: OrientationManager) {
        self.orientationManager = orientationManager
        super.init()
        setupCamera()
        setupOrientationObserver()
    }
    
    private func setupOrientationObserver() {
        orientationManager.orientationPublisher
            .sink { [weak self] orientation in
                self?.updateVideoOrientation(orientation)
            }
            .store(in: &cancellables)
    }
    
    private func updateVideoOrientation(_ orientation: AVCaptureVideoOrientation) {
        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = orientation
        }
    }
    
    private func setupCamera() {
        session.sessionPreset = .photo
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
            if currentPosition == .front {
                connection.isVideoMirrored = true
            }
        }
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    func capturePhoto(completion: @escaping (Result<UIImage, Error>) -> Void) {
        photoCaptureCompletion = completion
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func toggleCamera() {
        currentPosition = currentPosition == .back ? .front : .back
        
        session.beginConfiguration()
        
        if let currentInput = session.inputs.first as? AVCaptureDeviceInput {
            session.removeInput(currentInput)
        }
        
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
              let newInput = try? AVCaptureDeviceInput(device: newCamera) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(newInput) {
            session.addInput(newInput)
        }
        
        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
            if currentPosition == .front {
                connection.isVideoMirrored = true
            }
        }
        
        session.commitConfiguration()
    }
}

extension CameraManagerImpl: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            photoCaptureCompletion?(.failure(error))
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoCaptureCompletion?(.failure(NSError(domain: "CameraManager", code: -1)))
            return
        }
        
        photoCaptureCompletion?(.success(image))
    }
}

extension CameraManagerImpl: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        framePublisher.send(pixelBuffer)
    }
}
