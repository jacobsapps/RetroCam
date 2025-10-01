import UIKit
import SnapKit
import Combine
import AVFoundation

final class RetroCamViewController: UIViewController {
    
    private let viewModel: RetroCamViewModel
    private let orientationManager: OrientationManager
    private var cancellables = Set<AnyCancellable>()
    
    private lazy var filterControl: UISegmentedControl = {
        let control = UISegmentedControl()
        for (index, filterType) in FilterType.allCases.enumerated() {
            control.insertSegment(with: UIImage(systemName: filterType.sfSymbol), at: index, animated: false)
        }
        control.selectedSegmentIndex = 1
        control.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        return control
    }()
    
    private lazy var previewImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private lazy var captureButton: CaptureButton = {
        let button = CaptureButton()
        button.addTarget(self, action: #selector(captureButtonTapped), for: .touchDown)
        return button
    }()
    
    private lazy var flashView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.alpha = 0
        return view
    }()
    
    init(viewModel: RetroCamViewModel, orientationManager: OrientationManager) {
        self.viewModel = viewModel
        self.orientationManager = orientationManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        setupGestures()
        setupOrientationObserver()
    }
    
    private func setupOrientationObserver() {
        orientationManager.orientationPublisher
            .sink { [weak self] orientation in
                self?.updateCaptureButtonPosition(for: orientation)
            }
            .store(in: &cancellables)
    }
    
    private func updateCaptureButtonPosition(for orientation: AVCaptureVideoOrientation) {
        captureButton.snp.remakeConstraints { make in
            make.size.equalTo(80)
            
            switch orientation {
            case .landscapeLeft, .landscapeRight:
                make.centerY.equalToSuperview()
                make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-40)
            case .portrait, .portraitUpsideDown:
                make.centerX.equalToSuperview()
                make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-40)
            @unknown default:
                make.centerX.equalToSuperview()
                make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-40)
            }
        }
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func setupGestures() {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.startCamera()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopCamera()
    }
    
    private func setupUI() {
        view.addSubview(previewImageView)
        view.addSubview(filterControl)
        view.addSubview(captureButton)
        view.addSubview(flashView)
        
        previewImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        filterControl.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        captureButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-40)
            make.size.equalTo(80)
        }
        
        flashView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func bindViewModel() {
        viewModel.processedFrame
            .sink { [weak self] image in
                self?.previewImageView.image = image
            }
            .store(in: &cancellables)
        
        viewModel.didCapturePhoto
            .sink { [weak self] in
                self?.showFlash()
            }
            .store(in: &cancellables)
    }
    
    @objc private func captureButtonTapped() {
        Haptics.cutoutCapture()
        viewModel.capturePhoto()
    }
    
    @objc private func filterChanged() {
        guard let filterType = FilterType(rawValue: filterControl.selectedSegmentIndex) else { return }
        viewModel.setFilter(filterType)
    }
    
    @objc private func handleDoubleTap() {
        viewModel.toggleCamera()
    }
    
    private func showFlash() {
        UIView.animate(withDuration: 0.1, animations: {
            self.flashView.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.flashView.alpha = 0
            }
        }
    }
}

final class CaptureButton: UIControl {
    
    private let outerCircle = UIView()
    private let innerCircle = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        outerCircle.backgroundColor = .clear
        outerCircle.layer.borderColor = UIColor.white.cgColor
        outerCircle.layer.borderWidth = 4
        outerCircle.isUserInteractionEnabled = false
        
        innerCircle.backgroundColor = .white
        innerCircle.isUserInteractionEnabled = false
        
        addSubview(outerCircle)
        addSubview(innerCircle)
        
        outerCircle.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        innerCircle.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalToSuperview().multipliedBy(0.75)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        outerCircle.layer.cornerRadius = bounds.width / 2
        innerCircle.layer.cornerRadius = (bounds.width * 0.75) / 2
    }
}
