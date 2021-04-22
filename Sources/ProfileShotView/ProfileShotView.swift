import UIKit
import AVFoundation


// MARK: - Delegate protocol

public protocol ProfileShotViewDelegate: class
{
    func profileShotView(_ view: ProfileShotView, didUpdateFrame image: CIImage?, withFace: CIFaceFeature?)
    func profileShotView(_ view: ProfileShotView, didCapturePhoto image: UIImage?)
    func profileShotView(_ view: ProfileShotView, containmentDidChangeTo: ProfileShotView.Containment)
}

// Optional protocol functions
extension ProfileShotViewDelegate
{
    func profileShotView(_ view: ProfileShotView, didUpdateFrame image: CIImage?, withFace: CIFaceFeature?)  { }
    func profileShotView(_ view: ProfileShotView, containmentDidChangeTo: ProfileShotView.Containment)  { }
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
        case error(Error)
    }
}


// MARK: - The view

public class ProfileShotView: UIView
{
    // MARK: - Public interface

    public var containmentInsideColor: UIColor = .green
    public var containmentOutsideColor: UIColor = .red
    public var faceIndicatorColor: UIColor = .cyan
    public var containmentMaskColor: UIColor = UIColor.black.withAlphaComponent(0.5)
    /// Capture photo automatically when the person smiles
    public var captureWhenSmiling: Bool = false
    /// How much wider than the face to capture for the full profile image. The height will follow from the aspect ratio of this view.
    public var faceToPhotoWidthExtensionFactor: CGFloat = 2.5
    /// Whether photo capture is currently in progres.
    public var isCapturingPhoto: Bool { return _isCapturingPhoto }
    /// Whether there is another camera available to switch to.
    public var canSwitchCamera: Bool { _session.isRunning && (_frontCamera != nil && _backCamera != nil) }
    /// Whether the video view and capture should rotate automatically with device orientation change
    public var shouldAutoRotate: Bool = false
    public var flipDuration: TimeInterval = 0.5
    
    public var photoBackground: PhotoLayer.Background
    {
        get { return _photoLayer.background }
        set { _photoLayer.background = newValue }
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

    public func startCamera()
    {
        if _session.isRunning { return }
        containment = .none
        _isCapturingPhoto = false
        _videoLayer.isHidden = false
        _photoLayer.isHidden = true
        _session.startRunning()
    }

    public func stopCamera()
    {
        _videoLayer.isHidden = true
        _session.stopRunning()
        containment = .none
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
    private let _lowpassCropRect = LowpassFilteredRect(RC: 0.10)
    
    private var _currentOrientation: AVCaptureVideoOrientation = .portrait
    private var _isCapturingPhoto: Bool = false
    
    private var _captureDevice: AVCaptureDevice? = nil
    private var _frontCamera: AVCaptureDevice? = nil
    private var _backCamera: AVCaptureDevice? = nil
    
    private var _isMirrored: Bool { _captureDevice == _frontCamera }
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
                if granted {
                    self._configureCaptureSession(position, completion: completion)
                } else {
                    completion(.accessDenied)
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
        // Note: Not mirrored
        
        completion(.success)
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
        _videoLayer.drawOverlays(faceRect: nil, cropRect: nil, captureSize: .zero)
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
//
//        do {
//            let cameraInput = try AVCaptureDeviceInput(device: camera)
//            if !_session.canAddInput(cameraInput) {
//                //completion(.cameraInputError)
//                return
//            }
//            _session.addInput(cameraInput)
//            _captureDevice = camera
//        } catch {
//            //completion(.error(error))
//            return
//        }
        
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

        DispatchQueue.main.async {
            self.delegate?.profileShotView(self, didUpdateFrame: image, withFace: bestFace)
        }

        // Update stabilized frames
        var (faceRect, cropRect) = _getNormRects(bestFace?.bounds, captureSize: image.extent.size)
        faceRect = _lowpassFaceRect.update(faceRect)
        cropRect = _lowpassCropRect.update(cropRect)

        // Update containment
        if let cropRect = cropRect {
            let relBounds = _videoLayer.normRect(captureSize: image.extent.size)
            containment = relBounds.contains(cropRect) ? .inside : .outside
        } else {
            containment = .none
        }

        DispatchQueue.main.async { [weak self] in
            self?._displayVideoOverlays(captureSize: image.extent.size)
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

    private func _getNormRects(_ faceRect: CGRect?, captureSize: CGSize) -> (CGRect?, CGRect?)
    {
        guard let faceRect = faceRect else { return(nil, nil) }

        let normFace = CGRect(
            x      : faceRect.origin.x / captureSize.width,
            y      : faceRect.origin.y / captureSize.height,
            width  : faceRect.size.width / captureSize.width,
            height : faceRect.size.height / captureSize.height
        )

        // Crop rect is larger... s is scale factor extension relative to the face width
        let s = faceToPhotoWidthExtensionFactor
        let viewAspectRatio = _videoLayer.bounds.size.width / _videoLayer.bounds.size.height
        let sw: CGFloat = (faceRect.size.width * s) / captureSize.width
        let sh: CGFloat = (faceRect.size.width * s) / captureSize.height / viewAspectRatio
        let cropRect = CGRect(x: normFace.midX - sw/2, y: normFace.midY - sh/2, width: sw, height: sh)

        return (normFace, cropRect)
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
            _photoOutput.capturePhoto(with: photoSettings, delegate: self)
        } else {
            delegate?.profileShotView(self, didCapturePhoto: nil)
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
        // Else grab the entire video layer
        let relBounds = _videoLayer.normRect(captureSize: maskedImage.extent.size)
        let cropRect = _lowpassCropRect.value
        let useRect: CGRect
        if let cropRect = cropRect, relBounds.contains(cropRect) {
            useRect = cropRect
        } else {
            useRect = relBounds
        }
        guard let croppedCGImage = _getCroppedCGImage(maskedImage, relCIRect: useRect) else {
            DispatchQueue.main.async {
                self.delegate?.profileShotView(self, didCapturePhoto: nil)
            }
            return
        }

        // Create a saveable UIImage to send to the delegate
        let uiImage = UIImage(cgImage: croppedCGImage)
        var saveableImage: UIImage? = nil
        if let pngData = uiImage.pngData() {
            saveableImage = UIImage(data: pngData)
        }
        
        DispatchQueue.main.async {
            self._displayPhoto(croppedCGImage)
            self.delegate?.profileShotView(self, didCapturePhoto: saveableImage)
        }
    }

    private func _getCroppedCGImage(_ ciImage: CIImage, relCIRect: CGRect?) -> CGImage?
    {
        var relRect = relCIRect ?? CGRect(x: 0, y: 0, width: 1, height: 1)

        // The rect is for the possibly mirrored video image, so mirror it back here since the photo is not mirrored
        if _isMirrored {
            relRect.origin.x = 1 - relRect.origin.x - relRect.width
        }
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
    private func _displayVideoOverlays(captureSize: CGSize)
    {
        _videoLayer.faceIndicatorColor      = faceIndicatorColor.cgColor
        _videoLayer.containmentInsideColor  = containmentInsideColor.cgColor
        _videoLayer.containmentOutsideColor = containmentOutsideColor.cgColor
        _videoLayer.containmentMaskColor    = containmentMaskColor.cgColor

        _videoLayer.drawOverlays(faceRect: _lowpassFaceRect.value, cropRect: _lowpassCropRect.value, captureSize: captureSize)
    }

    private func _displayPhoto(_ cgImage: CGImage)
    {
        _photoLayer.photo = cgImage

        _videoLayer.isHidden = true
        _photoLayer.isHidden = false
    }
}
