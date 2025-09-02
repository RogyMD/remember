import SwiftUI
@preconcurrency import AVFoundation

public struct CameraView: UIViewControllerRepresentable {
  // Closure returns the captured (resized) image and the normalized focus point (0...1)
  var onCapture: (UIImage, CGPoint) -> Void
  
  
  public init(onCapture: @escaping (UIImage, CGPoint) -> Void) {
    self.onCapture = onCapture
  }
  
  public func makeUIViewController(context: Context) -> UIViewController {
    let controller = CameraViewController()
    controller.onCapture = onCapture
    return controller
  }
  
  public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    // No update needed.
  }
}

extension DispatchQueue {
  static let video = DispatchQueue(label: "videoQueue")
  static let captureSession = DispatchQueue(label: "captureSessionQueue")
}

final class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate, UIGestureRecognizerDelegate {
  private let zoomLabelContainer: UIView = {
      let view = UIView()
      view.translatesAutoresizingMaskIntoConstraints = false
      view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.6)
      view.layer.cornerRadius = 16
      view.clipsToBounds = true
      view.alpha = 0
      return view
  }()
  private let zoomLabel: UILabel = {
      let label = UILabel()
      label.translatesAutoresizingMaskIntoConstraints = false
      label.textAlignment = .center
      label.textColor = .label
      label.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
      label.backgroundColor = .clear
      return label
  }()
  var session = AVCaptureSession()
  private var sessionDevice: AVCaptureDevice? {
    (session.inputs.first as? AVCaptureDeviceInput)?.device
  }
  var photoOutput = AVCapturePhotoOutput()
  var previewLayer: AVCaptureVideoPreviewLayer?
  private var hasNotifiedZoomError: Bool = false
  lazy var successFeedback = UINotificationFeedbackGenerator(view: self.view)
  lazy var rigidFeedback = UIImpactFeedbackGenerator(style: .rigid, view: view)
  lazy var softFeedback = UIImpactFeedbackGenerator(style: .light, view: view)
  lazy var selectionFeedback = UISelectionFeedbackGenerator(view: self.view)
  private lazy var captureButton: UIButton = {
    let captureButton = CaptureButton(type: .system)
    captureButton.translatesAutoresizingMaskIntoConstraints = false
    captureButton.addTarget(self, action: #selector(capturePhotoButtonTapped), for: .touchUpInside)
    return captureButton
  }()
  private var torchButton: UIButton = {
    var configuration = UIButton.Configuration.filled()
    configuration.cornerStyle = .capsule
    return UIButton(configuration: configuration, primaryAction: nil)
  }()
  private let noResultsView = UIView()
  private let noCameraAccessView = UIView()
  private let activityIndicator: UIActivityIndicatorView = {
    let indicator = UIActivityIndicatorView(style: .large)
    indicator.translatesAutoresizingMaskIntoConstraints = false
    indicator.hidesWhenStopped = true
    return indicator
  }()
  private let activityIndicatorOverlayView: UIView = {
    let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
    let blurView = UIVisualEffectView(effect: blurEffect)
    blurView.translatesAutoresizingMaskIntoConstraints = false
    
    let overlay = UIView()
    overlay.translatesAutoresizingMaskIntoConstraints = false
    overlay.backgroundColor = .clear
    overlay.addSubview(blurView)
    
    NSLayoutConstraint.activate([
      blurView.topAnchor.constraint(equalTo: overlay.topAnchor),
      blurView.bottomAnchor.constraint(equalTo: overlay.bottomAnchor),
      blurView.leadingAnchor.constraint(equalTo: overlay.leadingAnchor),
      blurView.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
    ])
    
    return overlay
  }()
  
  // Closure callback to pass the captured image and focus point back
  var onCapture: ((UIImage, CGPoint) -> Void)?
  
  // Stored tap point used for focusing (from tap gesture)
  private var lastTapPoint: CGPoint = .init(x: 0.5, y: 0.5)
  
  // Stored long press point used for capture (if available)
  private var lastLongPressPoint: CGPoint?
  private var longPressCircle: UIView?
  
  deinit {
    guard session.isRunning else { return }
    DispatchQueue.captureSession.sync { [session] in
      session.stopRunning()
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    prepareFeedbackGenerators()
//    setupActivityIndicatorOverlay()
    if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
      requestCameraAccess()
    } else {
      updateCameraView()
    }
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    previewLayer?.frame = view.bounds
    noCameraAccessView.frame = view.bounds
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    audioVolumeObserver.stopObserving()
    guard session.isRunning else { return }
    DispatchQueue.captureSession.sync { [session] in
      session.stopRunning()
    }
  }
  
  private let audioVolumeObserver = AudioVolumeObserver()
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard session.inputs.isEmpty == false else { return }
    DispatchQueue.captureSession.async { [weak session] in
      session?.startRunning()
    }
    audioVolumeObserver.startObserving { [weak self] in
      DispatchQueue.main.async {
        guard self?.presentedViewController == nil else { return }
        self?.capturePhoto()
      }
    }
  }
  
  private func prepareFeedbackGenerators() {
    successFeedback.prepare()
    selectionFeedback.prepare()
    rigidFeedback.prepare()
    softFeedback.prepare()
  }
  
  private func configureSession() {
    session.sessionPreset = .photo
    guard let device = AVCaptureDevice.default(for: .video) else { return }
    do {
      let input = try AVCaptureDeviceInput(device: device)
      if session.canAddInput(input) { session.addInput(input) }
      if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
      DispatchQueue.captureSession.async { [session] in
        session.startRunning()
      }
    } catch {
      //      reportIssue(error)
    }
  }
  
  private func requestCameraAccess() {
    AVCaptureDevice.requestCameraAccess { [weak self] in
      self?.updateCameraView()
    }
  }
  
  private func updateCameraView() {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    let isNoCameraAccessHidden: Bool
    switch status {
    case .notDetermined:
      isNoCameraAccessHidden = true
    case .restricted:
      isNoCameraAccessHidden = false
    case .denied:
      isNoCameraAccessHidden = false
    case .authorized:
      isNoCameraAccessHidden = true
    @unknown default:
      isNoCameraAccessHidden = false
    }
    DispatchQueue.main.async { [self] in
      if isNoCameraAccessHidden == false {
        setupNoCameraAccess()
      } else if status == .authorized {
        setupCameraAsync()
      }
    }
  }
  
  private func setupActivityIndicatorOverlay() {
    activityIndicatorOverlayView.alpha = 0
    activityIndicatorOverlayView.addSubview(activityIndicator)
    view.addSubview(activityIndicatorOverlayView)
    NSLayoutConstraint.activate([
      activityIndicator.centerXAnchor.constraint(equalTo: activityIndicatorOverlayView.centerXAnchor),
      activityIndicator.centerYAnchor.constraint(equalTo: activityIndicatorOverlayView.centerYAnchor),
      activityIndicatorOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      activityIndicatorOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      activityIndicatorOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
      activityIndicatorOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }
  
  func showsActivitiyIndicator(_ isShowing: Bool) {
    if isShowing {
      activityIndicator.startAnimating()
    } else {
      activityIndicator.stopAnimating()
    }
    activityIndicatorOverlayView.alpha = isShowing ? 1 : 0
  }
  
  private func setupNoCameraAccess() {
    // TODO: Localize
    let imageView = UIImageView(image: UIImage(systemName: "video.slash.fill"))
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.contentMode = .scaleAspectFit
    imageView.addConstraints([
      imageView.widthAnchor.constraint(equalToConstant: 64),
      imageView.heightAnchor.constraint(equalToConstant: 64),
    ])
    let titleLabel = UILabel()
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.numberOfLines = .zero
    titleLabel.textAlignment = .center
    titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
    titleLabel.adjustsFontForContentSizeCategory = true
    titleLabel.maximumContentSizeCategory = .large
    titleLabel.text = NSLocalizedString("No Camera Access", bundle: .main, comment: "")
    let detailLabel = UILabel()
    detailLabel.translatesAutoresizingMaskIntoConstraints = false
    detailLabel.textAlignment = .center
    detailLabel.numberOfLines = .zero
    detailLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
    detailLabel.adjustsFontForContentSizeCategory = true
    detailLabel.maximumContentSizeCategory = .large
    detailLabel.text = NSLocalizedString("Go to Settings and allow Timix to access your camera.", bundle: .main, comment: "")
    let button = UIButton(configuration: .bordered())
    button.translatesAutoresizingMaskIntoConstraints = false
    button.maximumContentSizeCategory = .extraExtraLarge
    button.setTitle(NSLocalizedString("Go to Settings", bundle: .main, comment: ""), for: .normal)
    button.setImage(UIImage(systemName: "gear.fill"), for: .normal)
    button.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
    let stackView = UIStackView(arrangedSubviews: [imageView, titleLabel, detailLabel, button])
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.spacing = UIStackView.spacingUseSystem
    stackView.axis = .vertical
    stackView.alignment = .center
    stackView.setCustomSpacing(24, after: detailLabel)
    noCameraAccessView.addSubview(stackView)
    noCameraAccessView.addConstraints([
      stackView.leadingAnchor.constraint(equalToSystemSpacingAfter: noCameraAccessView.leadingAnchor, multiplier: 1),
      stackView.centerXAnchor.constraint(equalTo: noCameraAccessView.centerXAnchor),
      stackView.centerYAnchor.constraint(equalTo: noCameraAccessView.centerYAnchor)
    ])
    view.addSubview(noCameraAccessView)
  }
  
  @objc
  private func settingsButtonTapped() {
    guard let settingsURL = URL(string: UIApplication.openSettingsURLString),
          UIApplication.shared.canOpenURL(settingsURL) else {
      return
    }
    UIApplication.shared.open(settingsURL)
  }
  
  @objc
  private func torchButtonTouchUp() {
    selectionFeedback.selectionChanged(at: torchButton.center)
    UIView.animate(springDuration: 0.6, bounce: 0.7, initialSpringVelocity: 0.9, options: [.allowUserInteraction]) {
      self.torchButton.transform = .identity
    }
  }
  
  @objc
  private func torchButtonTouchDown() {
    rigidFeedback.impactOccurred(at: torchButton.center)
    UIView.animate(springDuration: 0.6, bounce: 0.7, initialSpringVelocity: 0.9, options: [.allowUserInteraction]) {
      self.torchButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
    }
  }
  
  @objc
  private func toggleTorch() {
    guard let device = sessionDevice, device.hasTorch else { return }
    do {
      try device.lockForConfiguration()
      if device.torchMode == .on {
        device.torchMode = .off
        torchButton.setImage(UIImage(systemName: "flashlight.on.fill"), for: .normal)
        torchButton.configuration?.baseForegroundColor = .white
        torchButton.configuration?.background.backgroundColor = .systemBlue
      } else {
        try device.setTorchModeOn(level: 1.0)
        torchButton.setImage(UIImage(systemName: "flashlight.off.fill"), for: .normal)
        torchButton.configuration?.baseForegroundColor = .systemBlue
        torchButton.configuration?.background.backgroundColor = .white
      }
      device.unlockForConfiguration()
    } catch {
      print("Torch could not be used: \(error)")
    }
  }
  
  private func setupCameraAsync() {
    configureSession()
    addGestureRecognizers()
    showTapFeedback(at: view.center, hapticFeedback: false)
    
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.videoGravity = .resizeAspectFill
    self.view.layer.insertSublayer(previewLayer, at: 0)
    self.previewLayer = previewLayer
    previewLayer.frame = self.view.bounds
    
    setupCameraControls()
    
    audioVolumeObserver.startObserving { [weak self] in
      DispatchQueue.main.async {
        guard self?.presentedViewController == nil else { return }
        self?.capturePhoto()
      }
    }
  }
  
  @objc
  private func capturePhotoButtonTapped() {
      capturePhoto()
  }
  
  private func setupCameraControls() {
    view.addSubview(captureButton)
    zoomLabelContainer.addSubview(zoomLabel)
    view.addSubview(zoomLabelContainer)
    
    NSLayoutConstraint.activate([
        captureButton.widthAnchor.constraint(equalToConstant: 80),
        captureButton.heightAnchor.constraint(equalToConstant: 80),
        
        captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
    ])
    
    NSLayoutConstraint.activate([
        zoomLabelContainer.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor),
        zoomLabelContainer.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -12),
        zoomLabelContainer.heightAnchor.constraint(equalToConstant: 32),

        zoomLabel.leadingAnchor.constraint(equalTo: zoomLabelContainer.leadingAnchor, constant: 12),
        zoomLabel.trailingAnchor.constraint(equalTo: zoomLabelContainer.trailingAnchor, constant: -12),
        zoomLabel.topAnchor.constraint(equalTo: zoomLabelContainer.topAnchor, constant: 6),
        zoomLabel.bottomAnchor.constraint(equalTo: zoomLabelContainer.bottomAnchor, constant: -6)
    ])

    
    NSLayoutConstraint.activate([
      zoomLabelContainer.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor),
      zoomLabelContainer.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -12),
    ])
    
    guard sessionDevice?.hasTorch == true else { return }
    torchButton.setImage(UIImage(systemName: "flashlight.on.fill"), for: .normal)
    torchButton.translatesAutoresizingMaskIntoConstraints = false
    torchButton.addTarget(self, action: #selector(toggleTorch), for: .touchUpInside)
    torchButton.addTarget(self, action: #selector(torchButtonTouchDown), for: .touchDown)
    torchButton.addTarget(self, action: #selector(torchButtonTouchUp), for: .touchUpInside)
    torchButton.addTarget(self, action: #selector(torchButtonTouchUp), for: .touchCancel)
    torchButton.addTarget(self, action: #selector(torchButtonTouchUp), for: .touchUpOutside)
    view.addSubview(torchButton)
    NSLayoutConstraint.activate([
      torchButton.widthAnchor.constraint(equalToConstant: 60),
      torchButton.heightAnchor.constraint(equalToConstant: 60),
      
      torchButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
      torchButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -8),
    ])
  }
  
  private func updateZoomLabel(scale: CGFloat) {
    let isNotScaled = scale <= 1
    let hasHundredths = Int(scale * 100) % 10 != 0
    let textColor = isNotScaled ? UIColor.label : .systemYellow
    let isWholeNumber = (hasHundredths == false && scale.truncatingRemainder(dividingBy: 1) == .zero)
    let text = isWholeNumber ? "\(Int(scale))x" : String(format: "%.2fx", scale)
    self.zoomLabel.text = text
    
    UIView.animate(withDuration: 0.5, delay: .zero, options: [.beginFromCurrentState]) {
      self.zoomLabelContainer.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
      self.zoomLabelContainer.transform = .init(scaleX: 1.2, y: 1.2)
      self.zoomLabelContainer.alpha = 1
      self.zoomLabel.textColor = textColor
    } completion: { _ in
      self.scheduleUnhighlightOrHideZoomLabel(scale: scale)
    }
  }
  private var zoomLabelAppearanceTimer: Timer?
  private func scheduleUnhighlightOrHideZoomLabel(scale: CGFloat) {
    zoomLabelAppearanceTimer?.invalidate()
    zoomLabelAppearanceTimer = nil
    let isNotScaled = scale <= 1
    zoomLabelAppearanceTimer = .scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { [weak self] _ in
      guard let self else { return }
      DispatchQueue.main.async {
        UIView.animate(withDuration: 0.5, delay: .zero, options: [.beginFromCurrentState]) {
          self.zoomLabelContainer.alpha = isNotScaled ? .zero : 1
          self.zoomLabelContainer.transform = .identity
          self.zoomLabelContainer.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.5)
          self.zoomLabel.textColor = .label
        }
      }
    })
  }
  
  lazy var tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
  lazy var longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
  lazy var pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
  
  private func addGestureRecognizers() {
    view.addGestureRecognizer(tapGesture)
    longPress.delegate = self
    view.addGestureRecognizer(longPress)
    view.addGestureRecognizer(pinchGesture)
  }
  
  @objc private func handleTap(_ gesture: UIGestureRecognizer) {
    let tapPoint = gesture.location(in: view)
    lastLongPressPoint = tapPoint
    lastTapPoint = tapPoint
    guard let focusPoint = previewLayer?.captureDevicePointConverted(fromLayerPoint: tapPoint) else {
      return
    }
    focus(at: focusPoint)
    showTapFeedback(at: tapPoint, hapticFeedback: true)
  }
  
  private func focus(at point: CGPoint) {
    guard let device = (session.inputs.first as? AVCaptureDeviceInput)?.device, device.isFocusPointOfInterestSupported else { return }
    do {
      try device.lockForConfiguration()
      device.focusPointOfInterest = point
      device.focusMode = .autoFocus
//      if device.isExposurePointOfInterestSupported {
//        device.exposurePointOfInterest = point
//        device.exposureMode = .continuousAutoExposure
//      }
      device.unlockForConfiguration()
    } catch {
      //      reportIssue(error)
    }
  }
  
  var observer: NSKeyValueObservation?
  @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    if gesture.state == .began {
      handleTap(gesture)
      guard let device = (session.inputs.first as? AVCaptureDeviceInput)?.device else { return }
      observer = device.observe(\.isAdjustingFocus, options: .new) { [weak self] _, change in
        DispatchQueue.main.async {
          guard let self else { return }
          if change.newValue == false {
            self.observer?.invalidate()
            self.observer = nil
            self.capturePhoto()
          }
        }
      }
    }
  }
  
  @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
    guard let device = sessionDevice else { return }
    switch gesture.state {
    case .began:
      gesture.scale = device.videoZoomFactor
    case .changed:
      let newZoomFactor = max(1.0, min(device.activeFormat.videoMaxZoomFactor, gesture.scale))
      do {
        if newZoomFactor != device.videoZoomFactor {
          hasNotifiedZoomError = false
          try device.lockForConfiguration()
          device.videoZoomFactor = newZoomFactor
          device.unlockForConfiguration()
          softFeedback.impactOccurred(at: gesture.location(in: view))
        } else {
          if hasNotifiedZoomError == false {
            hasNotifiedZoomError = true
            successFeedback.notificationOccurred(.error, at: gesture.location(in: view))
          }
        }
        self.updateZoomLabel(scale: newZoomFactor)
      } catch {
        //        reportIssue(error)
      }
    default:
      break
    }
  }
  
  @objc
  private func capturePhoto() {
    let settings = AVCapturePhotoSettings()
    settings.photoQualityPrioritization = .speed
    photoOutput.capturePhoto(with: settings, delegate: self)
    softFeedback.impactOccurred()
  }
  
  private func turnOffTorchIfNeeded() {
    guard let sessionDevice, sessionDevice.torchMode == .on else { return }
    do {
      try sessionDevice.lockForConfiguration()
      sessionDevice.torchMode = .off
      sessionDevice.unlockForConfiguration()
      torchButton.setImage(UIImage(systemName: "flashlight.on.fill"), for: .normal)
    } catch {
      NSLog("Failed to focus. Error: \(error)")
//            reportIssue(error)
    }
  }
  
  private let focusTargetView: UIView = FocusTargetView(frame: CGRect(x: 0, y: 0, width: 45, height: 45))
  private func showTapFeedback(at point: CGPoint, hapticFeedback: Bool) {
    if focusTargetView.superview == nil {
      view.addSubview(focusTargetView)
      focusTargetView.isUserInteractionEnabled = false
      focusTargetView.backgroundColor = UIColor.clear
    }
    
    if hapticFeedback {
      self.selectionFeedback.selectionChanged(at: point)
      
      UIView.animate(springDuration: 0.2, bounce: 0.3) {
        focusTargetView.center = point
        focusTargetView.transform = .identity
      } completion: { finished in
        if finished {
          self.selectionFeedback.selectionChanged(at: point)
          UIView.animate(springDuration: 0.4, bounce: 0.5) {
            self.focusTargetView.transform = CGAffineTransformMakeScale(0.6, 0.6).concatenating(.init(rotationAngle: .pi))
          }
        }
      }
    } else {
      focusTargetView.center = point
      focusTargetView.transform = CGAffineTransformMakeScale(0.6, 0.6).concatenating(.init(rotationAngle: .pi))
    }
  }
  
  private func showLongPressFeedback(at point: CGPoint) {
    view.isUserInteractionEnabled = false
    
    let circleSize: CGFloat = 80
    let circle = UIView(frame: CGRect(x: 0, y: 0, width: circleSize, height: circleSize))
    circle.center = point
    circle.backgroundColor = UIColor.white.withAlphaComponent(0.5)
    circle.layer.cornerRadius = circleSize / 2
    
    // Set initial state for zoom in and fade in animation
    circle.alpha = 0
    circle.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
    
    self.view.addSubview(circle)
    self.longPressCircle = circle
    
    rigidFeedback.impactOccurred(at: point)
    
    // Animate zoom in: alpha from 0 to 1 and scale from 0.1 to identity over 0.5 seconds
    UIView.animate(withDuration: 0.5, animations: {
      circle.alpha = 1.0
      circle.transform = .identity
    }, completion: { _ in
      // Start pulsing animation until picture is taken
      UIView.animate(withDuration: 0.3, delay: 0, options: [.repeat, .autoreverse], animations: {
        circle.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
      }, completion: nil)
    })
  }
  
  // MARK: UIGestureRecognizerDelegate
  
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    if torchButton.bounds.contains(touch.location(in: torchButton)) || captureButton.bounds.contains(touch.location(in: captureButton)) {
      return false
    }
    return true
  }
  
  // MARK: AVCapturePhotoCaptureDelegate
  
  nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                               didFinishProcessingPhoto photo: AVCapturePhoto,
                               error: Error?) {
    guard let data = photo.fileDataRepresentation(),
          let fullImage = UIImage(data: data) else {
      if let error {
        NSLog("Photo output did finish with \(error)")
        //        reportIssue(error)
      }
      return
    }
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.successFeedback.notificationOccurred(.success)
      let point = self.lastLongPressPoint ?? self.view.center
      
      self.lastLongPressPoint = nil
      self.longPressCircle?.removeFromSuperview()
      self.longPressCircle = nil
      
      let normalizedPoint = point.convertPointToImageCoordinates(from: self.view.bounds, to: fullImage.size)
      
      self.onCapture?(fullImage, normalizedPoint)
      self.turnOffTorchIfNeeded()
      self.view.isUserInteractionEnabled = true
    }
  }
}

extension CGPoint {
  /// Converts a screen point (e.g. from a tap) to a normalized point in the full image,
  /// accounting for aspect fill cropping.
  func convertPointToImageCoordinates(from viewBounds: CGRect, to imageSize: CGSize) -> CGPoint {
    let imageAspectRatio = imageSize.width / imageSize.height
    let viewAspectRatio = viewBounds.width / viewBounds.height
    
    var scale: CGFloat
    var xOffset: CGFloat = 0
    var yOffset: CGFloat = 0
    
    if imageAspectRatio < viewAspectRatio {
      // Screen is wider than the image, so sides are cropped
      scale = viewBounds.height / imageSize.height
      let scaledImageWidth = imageSize.width * scale
      xOffset = (viewBounds.width - scaledImageWidth) / 2
    } else {
      // Screen is taller than the image, so top/bottom are cropped
      scale = viewBounds.width / imageSize.width
      let scaledImageHeight = imageSize.height * scale
      yOffset = (viewBounds.height - scaledImageHeight) / 2
    }
    
    let imageX = (x - xOffset) / scale
    let imageY = (y - yOffset) / scale
    
    return CGPoint(x: imageX, y: imageY)
  }
}

extension AVCaptureDevice {
  static func requestCameraAccess(_ completion: @MainActor @escaping () -> Void) {
    AVCaptureDevice.requestAccess(for: .video) { granted in
      Task { @MainActor in
        completion()
      }
    }
  }
}

final class CaptureButton: UIButton {
  private let outerCircleLayer = CAShapeLayer()
  private let innerCircleLayer = CAShapeLayer()
  private let inset: CGFloat = 4

  override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }

  private func commonInit() {
    backgroundColor = .clear
    layer.addSublayer(outerCircleLayer)
    layer.addSublayer(innerCircleLayer)

    outerCircleLayer.lineWidth = 2
    outerCircleLayer.strokeColor = UIColor.white.cgColor
    outerCircleLayer.fillColor = UIColor.clear.cgColor

    innerCircleLayer.fillColor = UIColor.white.cgColor
    innerCircleLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    
    addTarget(self, action: #selector(self.touchDown), for: .touchDown)
    addTarget(self, action: #selector(self.touchUp), for: .touchUpInside)
    addTarget(self, action: #selector(self.touchUp), for: .touchUpOutside)
    addTarget(self, action: #selector(self.touchUp), for: .touchCancel)
  }
  
  @objc
  private func touchDown() {
    self.innerCircleLayer.opacity = 0.7
  }
  
  @objc
  private func touchUp() {
    self.innerCircleLayer.opacity = 1
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    let bounds = self.bounds
    let outerPath = UIBezierPath(ovalIn: bounds)
    outerCircleLayer.path = outerPath.cgPath
    outerCircleLayer.frame = bounds

    let innerRect = bounds.insetBy(dx: inset, dy: inset)
    let innerPath = UIBezierPath(ovalIn: innerRect)
    innerCircleLayer.path = innerPath.cgPath
    innerCircleLayer.frame = bounds
  }
}
