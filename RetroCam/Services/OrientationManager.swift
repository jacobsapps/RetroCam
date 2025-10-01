import UIKit
import AVFoundation
import Combine

protocol OrientationManager {
    var orientationPublisher: AnyPublisher<AVCaptureVideoOrientation, Never> { get }
    var currentOrientation: AVCaptureVideoOrientation { get }
    var currentUIOrientation: UIInterfaceOrientation { get }
}

final class OrientationManagerImpl: OrientationManager {
    
    private let orientationSubject = CurrentValueSubject<AVCaptureVideoOrientation, Never>(.portrait)
    
    var orientationPublisher: AnyPublisher<AVCaptureVideoOrientation, Never> {
        orientationSubject.eraseToAnyPublisher()
    }
    
    var currentOrientation: AVCaptureVideoOrientation {
        orientationSubject.value
    }
    
    var currentUIOrientation: UIInterfaceOrientation {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .interfaceOrientation ?? .portrait
    }
    
    init() {
        setupOrientationObserver()
        updateOrientation()
    }
    
    private func setupOrientationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func orientationDidChange() {
        updateOrientation()
    }
    
    private func updateOrientation() {
        let deviceOrientation = UIDevice.current.orientation
        
        let videoOrientation: AVCaptureVideoOrientation
        switch deviceOrientation {
        case .portrait:
            videoOrientation = .portrait
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
        case .landscapeLeft:
            videoOrientation = .landscapeRight
        case .landscapeRight:
            videoOrientation = .landscapeLeft
        default:
            return
        }
        
        orientationSubject.send(videoOrientation)
    }
}
