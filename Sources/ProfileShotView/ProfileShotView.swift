import UIKit
import AVFoundation


// MARK: - Delegate protocol

public protocol ProfileShotViewDelegate: class
{
    func profileShotView(_ view: ProfileShotView, didUpdateFrame image: CIImage?, withFaceRect: CGRect?, faceFeatures: CIFaceFeature?)
    func profileShotView(_ view: ProfileShotView, containmentDidChangeTo: ProfileShotView.Containment)
    func profileShotView(_ view: ProfileShotView, willCapturePhoto: Bool)
    func profileShotView(_ view: ProfileShotView, didCapturePhoto image: UIImage?)
}

// Optional protocol functions
extension ProfileShotViewDelegate
{
    func profileShotView(_ view: ProfileShotView, didUpdateFrame image: CIImage?, withFaceRect: CGRect?, faceFeatures: CIFaceFeature?)  { }
    func profileShotView(_ view: ProfileShotView, containmentDidChangeTo: ProfileShotView.Containment)  { }
    func profileShotView(_ view: ProfileShotView, willCapturePhoto: Bool)  { }
}


// MARK: - Subtypes

extension ProfileShotView
{
    public enum Containment { case none, outside, inside }

    public enum InitializationStatus
    {
        case success
        case accessDenied
        case noCapableCamera
        case cameraInputError
        case videoOutputError
        case photoOutputError
        case metadataOutputError
        case error(Error)
    }
}


// MARK: - The view

public class ProfileShotView: UIView
{
    // MARK: - Public interface

    /// Capture photo automatically when the person smiles
    public var captureWhenSmiling: Bool = false
    /// How much wider than the face to capture for the full profile image. The height will follow from the aspect ratio of this view.
    public var faceToPhotoWidthExtensionFactor: CGFloat = 2.5
    /// Whether photo capture is currently in progres.
    public var isCapturingPhoto: Bool { return _isCapturingPhoto }
    /// Whether there is another camera available to switch to.
    public var canSwitchCamera: Bool { /*_session.isRunning &&*/ (_frontCamera != nil && _backCamera != nil) }
    /// Whether the video view and capture should rotate automatically with device orientation change
    public var shouldAutoRotate: Bool = false
    /// Duration for the flip animation when switching between front and back camera.
    public var flipDuration: TimeInterval = 0.5
    /// The time to freeze the face and crop frames before we accept that a face is lost (to avoid thrashing).
    public var faceLostTimeout: TimeInterval = 0.5
    /// Duration for the photo to animate from the video crop size to full size.
    public var photoResizeDuration: TimeInterval = 0.5

    // Transient properties
    
    public var photoBackground: PhotoLayer.Background
    {
        get { return _photoLayer.background }
        set { _photoLayer.background = newValue }
    }

    public var faceIndicatorColor: UIColor
    {
        get { return UIColor(cgColor: _videoLayer.faceIndicatorColor) }
        set { _videoLayer.faceIndicatorColor = newValue.cgColor }
    }
    public var faceIndicatorLineWidth: CGFloat
    {
        get { _videoLayer.faceIndicatorLineWidth }
        set { _videoLayer.faceIndicatorLineWidth = newValue }
    }
    public var containmentInsideColor: UIColor
    {
        get { return UIColor(cgColor: _videoLayer.containmentInsideColor) }
        set { _videoLayer.containmentInsideColor = newValue.cgColor }
    }
    public var containmentOutsideColor: UIColor
    {
        get { return UIColor(cgColor: _videoLayer.containmentOutsideColor) }
        set { _videoLayer.containmentOutsideColor = newValue.cgColor }
    }
    public var containmentMaskColor: UIColor
    {
        get { return UIColor(cgColor: _videoLayer.containmentMaskColor) }
        set { _videoLayer.containmentMaskColor = newValue.cgColor }
    }
    public var containmentLineWidth: CGFloat
    {
        get { _videoLayer.containmentLineWidth }
        set { _videoLayer.containmentLineWidth = newValue }
    }
    public var containmentCornerRadius: CGFloat
    {
        get { _videoLayer.containmentCornerRadius }
        set { _videoLayer.containmentCornerRadius = newValue }
    }

    /// Whether the crop rectangle around the face is inside the view.
    public private(set) var containment: Containment = .none
    {
        didSet {
            if containment != oldValue {
                let newContainment = containment
                DispatchQueue.main.async {
                    self.delegate?.profileShotView(self, containmentDidChangeTo: newContainment)
                }
            }
        }
    }

    public weak var delegate: ProfileShotViewDelegate? = nil


    public convenience init() { self.init(frame: .zero) }

    override public init(frame: CGRect)
    {
        super.init(frame: frame)
        _commonInit()
    }

    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
        _commonInit()
    }

    private func _commonInit()
    {
        translatesAutoresizingMaskIntoConstraints = false

        _videoLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(_videoLayer)
        layer.addSublayer(_photoLayer)
        
        addSubview(_blackoutView)
        _blackoutView.backgroundColor = .black
        _blackoutView.isHidden = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(_orientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func startCamera(suspended: Bool = false)
    {
        if _cameraStarted { return }
        _cameraStarted = true
        
        containment = .none
        _isCapturingPhoto = false
        _videoLayer.isHidden = false
        _photoLayer.isHidden = true
        if !suspended {
            _session.startRunning()
        }
    }

    public func stopCamera()
    {
//        _videoLayer.isHidden = true
        _session.stopRunning()
        containment = .none
        
        _cameraStarted = false
    }

    public func suspend()
    {
        if _cameraStarted {
            _session.stopRunning()
        }
    }

    public func resume()
    {
        if _cameraStarted {
            _session.startRunning()
        }
    }
    
    public func capturePhoto()
    {
        _capturePhoto()
    }
    
    public func switchCamera(_ position: AVCaptureDevice.Position? = nil)
    {
        _switchCamera(position)
    }
    

    // MARK: - Private properties

    private let _session = AVCaptureSession()
    private let _dataOutputQueue = DispatchQueue(label: "com.imatech.proShot.videoQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private let _videoOutput = AVCaptureVideoDataOutput()
    private let _photoOutput = AVCapturePhotoOutput()
    private let _faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])
    private let _clearBackground: CIImage = CIImage(color: CIColor(color: .clear))
    private lazy var _videoLayer: VideoLayer = { VideoLayer(session: _session) }()
    private let _photoLayer = PhotoLayer(.checkerboard(20))
    private let _blackoutView = UIView()

    private let _lowpassFaceRect = LowpassFilteredRect(RC: 0.10)
    private let _lowpassCropRect = LowpassFilteredRect(RC: 0.10)//0.25)
    
    private var _currentOrientation: AVCaptureVideoOrientation = .portrait
    private var _isCapturingPhoto: Bool = false
    
    private var _captureDevice: AVCaptureDevice? = nil
    private var _frontCamera: AVCaptureDevice? = nil
    private var _backCamera: AVCaptureDevice? = nil
    
    private var _isMirrored: Bool { _captureDevice == _frontCamera }
    private var _faceLostDate: Date? = nil
    private var _cameraStarted: Bool = false
}


// MARK: - UIView overrides

extension ProfileShotView
{
    override public func layoutSubviews()
    {
        super.layoutSubviews()
        layer.sublayers?.forEach { $0.frame = layer.bounds }
        _blackoutView.frame = bounds
    }
}


// MARK: - Device setup

extension ProfileShotView
{
    public func initialize(_ position: AVCaptureDevice.Position = .unspecified, completion: @escaping (_ status: InitializationStatus)->())
    {
        switch AVCaptureDevice.authorizationStatus(for: .video)
        {
        case .authorized:
            _configureCaptureSession(position, completion: completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self._configureCaptureSession(position, completion: completion)
                    } else {
                        completion(.accessDenied)
                    }
                }
            }
        case .denied:
            completion(.accessDenied)
        case .restricted:
            completion(.accessDenied)
        @unknown default:
            completion(.accessDenied)
        }
    }
    
    private func _configureCaptureSession(_ position: AVCaptureDevice.Position, completion: (_ status: InitializationStatus)->())
    {
        _frontCamera = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)
        _backCamera = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back)
        
        let prefCamera: AVCaptureDevice?
        if position == .front { prefCamera = _frontCamera }
        else if position == .back { prefCamera = _backCamera }
        else { prefCamera = _frontCamera ?? _backCamera }
        
        guard let camera = prefCamera else {
            completion(.noCapableCamera)
            return
        }

        _session.sessionPreset = .photo
        
        _addInputOutput(camera, completion: completion)
    }
    
    private func _addInputOutput(_ camera: AVCaptureDevice, completion: (_ status: InitializationStatus)->())
    {
        _session.inputs.forEach { _session.removeInput($0) }
        _session.outputs.forEach { _session.removeOutput($0) }
        
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            if !_session.canAddInput(cameraInput) {
                completion(.cameraInputError)
                return
            }
            _session.addInput(cameraInput)
            _captureDevice = camera
        } catch {
            completion(.error(error))
            return
        }

        let orientation = _getVideoOrientation()
        _videoLayer.connection?.videoOrientation = orientation

        // Video output

        _videoOutput.setSampleBufferDelegate(self, queue: _dataOutputQueue)
        _videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        _videoOutput.alwaysDiscardsLateVideoFrames = true

        if !_session.canAddOutput(_videoOutput) {
            completion(.videoOutputError)
            return
        }

        _session.addOutput(_videoOutput)

        let videoConnection = _videoOutput.connection(with: .video)
        videoConnection?.videoOrientation = orientation
        videoConnection?.isVideoMirrored = _isMirrored

        do {
            try camera.lockForConfiguration()
            if let format = camera.activeDepthDataFormat, let range = format.videoSupportedFrameRateRanges.first {
                camera.activeVideoMinFrameDuration = range.minFrameDuration
            }
            camera.unlockForConfiguration()
        } catch {
            completion(.error(error))
            return
        }

        // Photo output

        if !_session.canAddOutput(_photoOutput) {
            completion(.photoOutputError)
            return
        }
        
        _session.addOutput(_photoOutput)
        _photoOutput.isHighResolutionCaptureEnabled = true
        _photoOutput.isDepthDataDeliveryEnabled = true  // a requirement for portraitEffectsMatte
        _photoOutput.isPortraitEffectsMatteDeliveryEnabled = true

        let photoConnection = _photoOutput.connection(with: .video)
        photoConnection?.videoOrientation = orientation
        photoConnection?.isVideoMirrored = _isMirrored
        
        completion(.success)
        
        // Metadata output (for the face)
        
        let metadataOutput = AVCaptureMetadataOutput()
        metadataOutput.setMetadataObjectsDelegate(self, queue: _dataOutputQueue)
        if _session.canAddOutput(metadataOutput) {
            _session.addOutput(metadataOutput)
        } else {
            completion(.metadataOutputError)
            return
        }
        
        metadataOutput.metadataObjectTypes = [.face]
    }
    
    public func _switchCamera(_ position: AVCaptureDevice.Position?)
    {
        if !canSwitchCamera { return }
        guard let currentDevice = _captureDevice else { return }
        if position == currentDevice.position { return }
        let targetPosition = position ?? (currentDevice.position == .back ? .front : .back)
        guard let targetDevice = targetPosition == .back ? _backCamera : _frontCamera else { return }

        if flipDuration > 0
        {
            _flipStart(targetDevice)
        } else {
            _deactivateCamera()
            _activateCamera(targetDevice)
            _blackoutView.isHidden = true
        }
    }

    private func _flipStart(_ targetDevice: AVCaptureDevice)
    {
        let duration: TimeInterval = flipDuration

        self._blackoutView.alpha = 0.0
        self._blackoutView.isHidden = false
        

        UIView.transition(with: self, duration: duration, options: [.transitionFlipFromLeft, .allowAnimatedContent, .curveLinear], animations: {
        } , completion: {
            finished in
        })

        self._deactivateCamera()
        

        UIView.animate(withDuration: duration / 2, delay: 0, options: [.curveEaseIn], animations: {
            self._blackoutView.alpha = 1.0
        }, completion: {
            finished in
            self._blackoutView.alpha = 1.0
            self._activateCamera(targetDevice)

            UIView.animate(withDuration: duration / 2 * (0.5), delay: 0, options: [.curveEaseIn], animations: {
                self._blackoutView.alpha = 0.0
            }, completion: {
                finished in
                self._blackoutView.alpha = 0.0
                self._blackoutView.isHidden = true
            })
        })
    }
    
    private func _deactivateCamera()
    {
        _videoLayer.drawOverlays(faceRect: nil, cropRect: nil)
//        _videoLayer.session = nil
        _session.stopRunning()
        
        if let currentInput = _session.inputs.first {
            _session.removeInput(currentInput)
        }
    }

    private func _activateCamera(_ camera: AVCaptureDevice)
    {
        containment = .none

        _addInputOutput(camera, completion: { _ in })
        
//        _videoLayer.session = _session
        _session.startRunning()
    }
}


// MARK: - Orientation management

extension ProfileShotView
{
    @objc private func _orientationDidChange()
    {
        if shouldAutoRotate {
            resetOrientation()
        }
    }

    private func _getVideoOrientation() -> AVCaptureVideoOrientation
    {
        switch UIDevice.current.orientation
        {
        case .landscapeLeft      : return .landscapeRight
        case .landscapeRight     : return .landscapeLeft
        case .portraitUpsideDown : return .portraitUpsideDown
        case .portrait           : return .portrait
        default                  : return _currentOrientation
        }
    }
    
    public func resetOrientation()
    {
        let orientation = _getVideoOrientation()
        if orientation == _currentOrientation { return }
        
        _currentOrientation = orientation

        let videoConnection = _videoOutput.connection(with: .video)
        videoConnection?.videoOrientation = orientation

        let photoConnection = _photoOutput.connection(with: .video)
        photoConnection?.videoOrientation = orientation
        
        _videoLayer.connection?.videoOrientation = orientation
    }
}


// MARK: - Video capture

extension ProfileShotView: AVCaptureVideoDataOutputSampleBufferDelegate
{
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let image = CIImage(cvPixelBuffer: pixelBuffer)

        let bestFace = _getBiggestFace(image: image)

        DispatchQueue.main.async { [ weak self] in
            guard let self = self else { return }
            self.delegate?.profileShotView(self, didUpdateFrame: image, withFaceRect: self._lowpassFaceRect.value, faceFeatures: bestFace)
        }

        DispatchQueue.main.async { [weak self] in
            self?._displayVideoOverlays()
    }

        // Capture photo if smiling
        if !_isCapturingPhoto && captureWhenSmiling && bestFace?.hasSmile == true { capturePhoto() }
    }

    private func _getBiggestFace(image: CIImage) -> CIFaceFeature?
    {
        let options: [String: Any] = [
            CIDetectorSmile: true,
            CIDetectorTracking: true
        ]
        let allFeatures = _faceDetector?.features(in: image, options: options)
        let faceFeatures = allFeatures?.compactMap { $0 as? CIFaceFeature }
        let biggestFace = faceFeatures?.max(by: { $0.bounds.area < $1.bounds.area } )
        return biggestFace
    }
}


// MARK: - Metadata output (face)

extension ProfileShotView: AVCaptureMetadataOutputObjectsDelegate
{
    private func _getCropRect(faceRect: CGRect?) -> CGRect?
    {
        guard let faceRect = faceRect else { return nil }

        // Crop rect is larger... s is scale factor extension relative to the face width
        let s = faceToPhotoWidthExtensionFactor
        let viewAspectRatio = _videoLayer.bounds.size.width / _videoLayer.bounds.size.height
        let sw: CGFloat = faceRect.width * s
        let sh: CGFloat = faceRect.width * s / viewAspectRatio
        let cropRect = CGRect(x: faceRect.midX - sw/2, y: faceRect.midY - sh/2, width: sw, height: sh)

        return cropRect
    }

    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection)
    {
        let faces = metadataObjects.compactMap( { $0 as? AVMetadataFaceObject } )
        let biggestFace = faces.max(by: { $0.bounds.area < $1.bounds.area } )

        var faceRect: CGRect? = nil
        if let biggestFace = biggestFace, let t = _videoLayer.transformedMetadataObject(for: biggestFace) {
            faceRect = t.bounds
        }

        // Update stabilized frames
        
        // Avoid nil
        if faceRect == nil {
            if let ts = _faceLostDate {
                if (-ts.timeIntervalSinceNow) < faceLostTimeout {
                    // Do not update
                    return
                } else {
                    // Accept that it is lost and continue with nil faceRect
                }
            } else {
                // Mark the time we lost the face, but do not update
                _faceLostDate = Date()
                return
            }
        } else {
            _faceLostDate = nil
        }

        faceRect = _lowpassFaceRect.update(faceRect)
        var cropRect = _getCropRect(faceRect: faceRect)
        cropRect = _lowpassCropRect.update(cropRect)
        
        // Update containment
        if let cropRect = cropRect {
            containment = _videoLayer.bounds.contains(cropRect) ? .inside : .outside
        } else {
            containment = .none
        }
    }
}


// MARK: - Photo capture

extension ProfileShotView: AVCapturePhotoCaptureDelegate
{
    private func _capturePhoto()
    {
        if _isCapturingPhoto { return }

        let photoSettings = AVCapturePhotoSettings()
        if let photoPreviewType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoPreviewType]
            photoSettings.isHighResolutionPhotoEnabled = true
            photoSettings.isDepthDataDeliveryEnabled = true
            photoSettings.isPortraitEffectsMatteDeliveryEnabled = true
            photoSettings.embedsDepthDataInPhoto = true
            photoSettings.embedsPortraitEffectsMatteInPhoto = true
            photoSettings.previewPhotoFormat = nil
            photoSettings.isDepthDataFiltered = true
            _isCapturingPhoto = true
            DispatchQueue.main.async {
                self.delegate?.profileShotView(self, willCapturePhoto: true)
                self._photoOutput.capturePhoto(with: photoSettings, delegate: self)
            }
        } else {
            DispatchQueue.main.async {
                self.delegate?.profileShotView(self, willCapturePhoto: false)
            }
        }
    }

    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?)
    {
        _isCapturingPhoto = false
        stopCamera()

        guard
            let cgImageRef = photo.cgImageRepresentation()
        else {
            DispatchQueue.main.async {
                self.delegate?.profileShotView(self, didCapturePhoto: nil)
            }
            return
        }

        let image = CIImage(cgImage: cgImageRef.takeUnretainedValue())
        var maskedImage = image
        if let matte = photo.portraitEffectsMatte {
            let mask = CIImage(cvPixelBuffer: matte.mattingImage)
            maskedImage = ImageFilters.matteMask(image: image, background: _clearBackground, mask: mask)
        } else {
           // print("No matte; proceeding without mask")
        }

        // Fix orientation
        var orientation: CGImagePropertyOrientation?
        if let orientationNum = photo.metadata[kCGImagePropertyOrientation as String] as? NSNumber {
            orientation = CGImagePropertyOrientation(rawValue: orientationNum.uint32Value)
        }
        if let orientation = orientation {
            maskedImage = maskedImage.oriented(orientation)
        }

        // Crop around the face if we have a crop rect inside the video layer.
        // Else grab the entire video layer.
        let useRect: CGRect
        if let cropRect = _lowpassCropRect.value, _videoLayer.bounds.contains(cropRect) {
            useRect = cropRect
        } else {
            useRect = _videoLayer.bounds
        }
        
        // Convert from layer rect to relative video capture rect.
        let normVideoRect = _videoLayer.normRect(layerRect: useRect, captureSize: maskedImage.extent.size)
        
        guard let croppedCGImage = _getCroppedCGImage(maskedImage, relCIRect: normVideoRect) else {
            DispatchQueue.main.async {
                self.delegate?.profileShotView(self, didCapturePhoto: nil)
            }
            return
        }

        // Create a saveable UIImage to send to the delegate
        let saveableImage = _getSaveableImage(cgImage: croppedCGImage)
        
        let layerRect = useRect
        DispatchQueue.main.async {
            self._displayPhoto(croppedCGImage, layerRect: layerRect)
            self.delegate?.profileShotView(self, didCapturePhoto: saveableImage)
        }
    }
    
    private func _getSaveableImage(cgImage: CGImage) -> UIImage?
    {
        var image = UIImage(cgImage: cgImage, scale: 1, orientation: _isMirrored ? .upMirrored : .up)
        
        if image.imageOrientation != UIImage.Orientation.up {
            UIGraphicsBeginImageContext(image.size)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let copy = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            if let i = copy { image = i } else { return nil }
        }
        
        if let pngData = image.pngData() {
            return UIImage(data: pngData)
        } else {
            return nil
        }
    }

    private func _getCroppedCGImage(_ ciImage: CIImage, relCIRect: CGRect?) -> CGImage?
    {
        let relRect = relCIRect ?? CGRect(x: 0, y: 0, width: 1, height: 1)

//        // The rect is for the possibly mirrored video image, so mirror it back here since the photo is not mirrored
//        if _isMirrored {
//            relRect.origin.x = 1 - relRect.origin.x - relRect.width
//        }
        let w = ciImage.extent.size.width
        let h = ciImage.extent.size.height
        let rect = CGRect(x: relRect.origin.x * w, y: relRect.origin.y * h, width: relRect.size.width * w, height: relRect.size.height * h)
        let croppedImage = ciImage.cropped(to: rect)

        let cgImage = CIContext().createCGImage(croppedImage, from: croppedImage.extent)
        return cgImage
    }
}


// MARK: - Display photo and video with face frame in this view

extension ProfileShotView
{
    private func _displayVideoOverlays()
    {
        _videoLayer.drawOverlays(faceRect: _lowpassFaceRect.value, cropRect: _lowpassCropRect.value)
    }

    private func _displayPhoto(_ cgImage: CGImage, layerRect: CGRect)
    {
        _photoLayer.photo = cgImage

        let duration = photoResizeDuration
        let fromPosition = CGPoint(x: layerRect.midX, y: layerRect.midY)
        let toPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        let fromBounds = CGRect(origin: .zero, size: layerRect.size)
        let toBounds   = self.bounds

        let targetBlock = {
            // Make sure we end with the target states, even if the animation failed

            self._videoLayer.isHidden = true
            self._videoLayer.opacity = 1.0 // Restore it now that it is hidden
            // Note: Face and crop frame layers will recover by themselves

            self._photoLayer._backgroundLayer.opacity = 1.0
            self._photoLayer._photoLayer.position = toPosition
            self._photoLayer._photoLayer.bounds = toBounds
            self._photoLayer.isHidden = false
            

            self._videoLayer.removeAllAnimations()
            self._photoLayer._backgroundLayer.removeAllAnimations()
            self._photoLayer._photoLayer.removeAllAnimations()
        }
        
        if duration == 0 {
            targetBlock()
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        _photoLayer.displayIfNeeded()
        _photoLayer.isHidden = false
        _videoLayer._faceFrameLayer.isHidden = true
        _videoLayer._cropFrameLayer.isHidden = true

        CATransaction.setCompletionBlock(targetBlock)

        _addAnimation(_videoLayer,                  "opacity" , duration, from: 1.0         , to: 0.0       , timing: .easeIn)
        _addAnimation(_photoLayer._backgroundLayer, "opacity" , duration, from: 0.0         , to: 1.0       , timing: .easeIn)
        _addAnimation(_photoLayer._photoLayer,      "position", duration, from: fromPosition, to: toPosition, timing: .easeIn)
        _addAnimation(_photoLayer._photoLayer,      "bounds"  , duration, from: fromBounds  , to: toBounds  , timing: .easeIn)
        
        CATransaction.commit()
    }
    
    private func _addAnimation(
        _ layer: CALayer, _ keyPath: String, _ duration: TimeInterval,
        from fromValue: Any, to toValue: Any,
        timing: CAMediaTimingFunctionName = .default
    )
    {
        let a = CABasicAnimation(keyPath: keyPath)
        a.duration = duration
        a.fromValue = fromValue
        a.toValue = toValue
        a.isRemovedOnCompletion = true
        a.fillMode = .forwards
        a.timingFunction = CAMediaTimingFunction(name: timing)
        layer.add(a, forKey: keyPath)
    }
}
