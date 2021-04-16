struct ProfileShotView
{
    var text = "hello"
}

import UIKit

public class ProfileShotView2: UIView
{
    public convenience init() { self.init(frame: .zero) }
    
    override public init(frame: CGRect)
    {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
    }
}

//import UIKit
//import AVFoundation
//
//
//// MARK: - Delegate protocol
//
//public protocol ProfileShotViewDelegate: class
//{
//    func profileShotView(_ view: ProfileShotView, didUpdateFrame image: CIImage?, withFace: CIFaceFeature?)
//    func profileShotView(_ view: ProfileShotView, didCapturePhoto image: UIImage?)
//    func profileShotView(_ view: ProfileShotView, containmentDidChangeTo: ProfileShotView.Containment)
//}
//
//
//// MARK: - Subtypes
//
//extension ProfileShotView
//{
//    public enum Containment { case none, outside, inside }
//}
//
//
//// MARK: - The view
//
//public class ProfileShotView: UIView
//{
//    // MARK: - Public interface
//
//    public var containmentInsideColor: UIColor = .green
//    public var containmentOutsideColor: UIColor = .red
//    public var faceIndicatorColor: UIColor = .cyan
//    public var containmentMaskColor: UIColor = UIColor.black.withAlphaComponent(0.5)
//    /// Capture photo automatically when the person smiles
//    public var captureWhenSmiling: Bool = true
//    /// How much wider than the face to capture for the full profile image. The height will follow from the aspect ratio of this view.
//    public var faceToPhotoWidthExtensionFactor: CGFloat = 2.5
//    /// Whether photo capture is currently in progres.
//    public var isCapturingPhoto: Bool { return _isCapturingPhoto }
//
//    /// Whether the crop rectangle around the face is inside the view.
//    public private(set) var containment: Containment = .none
//    {
//        didSet {
//            if containment != oldValue {
//                let newContainment = containment
//                DispatchQueue.main.async {
//                    self.delegate?.profileShotView(self, containmentDidChangeTo: newContainment)
//                }
//            }
//        }
//    }
//
//    public weak var delegate: ProfileShotViewDelegate? = nil
//
//
//    public convenience init() { self.init(frame: .zero) }
//
//    override public init(frame: CGRect)
//    {
//        super.init(frame: frame)
//        _commonInit()
//    }
//
//    required init?(coder: NSCoder)
//    {
//        super.init(coder: coder)
//        _commonInit()
//    }
//
//    private func _commonInit()
//    {
//        _videoLayer.videoGravity = .resizeAspectFill
//        layer.addSublayer(_videoLayer)
//        layer.addSublayer(_photoLayer)
//
//        _configureCaptureSession()
//    }
//
//    public func startCamera()
//    {
//        if _session.isRunning { return }
//        containment = .none
//        _isCapturingPhoto = false
//        _videoLayer.isHidden = false
//        _photoLayer.isHidden = true
//        _session.startRunning()
//    }
//
//    public func stopCamera()
//    {
//        _videoLayer.isHidden = true
//        _session.stopRunning()
//        containment = .none
//    }
//
//    public func capturePhoto()
//    {
//        _capturePhoto()
//    }
//
//
//    // MARK: - Private properties
//
//    private let _session = AVCaptureSession()
//    private let _dataOutputQueue = DispatchQueue(label: "com.imatech.proShot.videoQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
//    private let _photoOutput = AVCapturePhotoOutput()
//    private let _faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])
//
//    private let _clearBackground: CIImage = CIImage(color: CIColor(color: .clear))
//
//    private var _isCapturingPhoto: Bool = false
//
//    private lazy var _videoLayer: VideoLayer = { VideoLayer(session: _session) }()
//    private let _photoLayer = PhotoLayer(.checkerboard(20))
//
//    private let _lowpassFaceRect = LowpassFilteredRect(RC: 0.10)
//    private let _lowpassCropRect = LowpassFilteredRect(RC: 0.10)
//}
//
//
//// MARK: - UIView overrides
//
//extension ProfileShotView
//{
//    override public func layoutSubviews()
//    {
//        super.layoutSubviews()
//        layer.sublayers?.forEach { $0.frame = layer.bounds }
//    }
//}
//
//
//// MARK: - Private helpers
//
//extension ProfileShotView
//{
//    // TODO: Make this more robust
//    private func _configureCaptureSession()
//    {
//        // Hard coded for now:
//        let position: AVCaptureDevice.Position = .front //.unspecified
//
//        let deviceType: AVCaptureDevice.DeviceType = (position == .front) ? .builtInTrueDepthCamera : .builtInDualCamera
//
//        guard let camera = AVCaptureDevice.default(deviceType, for: .video, position: position) else {
//            fatalError("No depth video camera available for position")
//        }
//
//        _session.sessionPreset = .photo
//
//        do {
//            let cameraInput = try AVCaptureDeviceInput(device: camera)
//            _session.addInput(cameraInput)
//        } catch {
//            fatalError(error.localizedDescription)
//        }
//
//        let orientation = _getVideoOrientation()
//        _videoLayer.connection?.videoOrientation = orientation
//
//        // Video output
//
//        let videoOutput = AVCaptureVideoDataOutput()
//        videoOutput.setSampleBufferDelegate(self, queue: _dataOutputQueue)
//        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
//        videoOutput.alwaysDiscardsLateVideoFrames = true
//        _session.addOutput(videoOutput)
//
//        let videoConnection = videoOutput.connection(with: .video)
//        videoConnection?.videoOrientation = orientation
//        videoConnection?.isVideoMirrored = (position == .front)
//
////        let outputRect = CGRect(x: 0, y: 0, width: 1, height: 1)
////        let videoRect = videoOutput.outputRectConverted(fromMetadataOutputRect: outputRect)
//
//        do {
//            try camera.lockForConfiguration()
//            if let format = camera.activeDepthDataFormat, let range = format.videoSupportedFrameRateRanges.first {
//                camera.activeVideoMinFrameDuration = range.minFrameDuration
//            }
//            camera.unlockForConfiguration()
//        } catch {
//            fatalError(error.localizedDescription)
//        }
//
//        // Photo output
//
//        _session.addOutput(_photoOutput)
//        _photoOutput.isHighResolutionCaptureEnabled = true
//        _photoOutput.isDepthDataDeliveryEnabled = true  // a requirement for portraitEffectsMatte
//        _photoOutput.isPortraitEffectsMatteDeliveryEnabled = true
//
//        let photoConnection = _photoOutput.connection(with: .video)
//        photoConnection?.videoOrientation = orientation
////        photoConnection?.isVideoMirrored = (position == .front)
//    }
//
//    private func _getVideoOrientation(interfaceOrientation: UIInterfaceOrientation? = nil) -> AVCaptureVideoOrientation
//    {
//
////        let defOr = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation
////        guard let interfaceOrientation = interfaceOrientation ?? UIApplication.shared.windows.first?.windowScene?.interfaceOrientation
////        else {
////            fatalError("Can't get interface orientation")
////        }
//
//        let defOr = UIApplication.shared.statusBarOrientation
//        let interfaceOrientation = interfaceOrientation ?? defOr
//
//        switch interfaceOrientation
//        {
//        case .landscapeLeft: return .landscapeLeft
//        case .landscapeRight: return .landscapeRight
//        case .portraitUpsideDown: return .portraitUpsideDown
//        default:
//            return .portrait
//        }
//    }
//}
//
//
//// MARK: - Capture video data delegate methods
//
//extension ProfileShotView: AVCaptureVideoDataOutputSampleBufferDelegate
//{
//    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
//    {
//        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
//        let image = CIImage(cvPixelBuffer: pixelBuffer)
//
//        let bestFace = _getBiggestFace(image: image)
//
//        DispatchQueue.main.async {
//            self.delegate?.profileShotView(self, didUpdateFrame: image, withFace: bestFace)
//        }
//
//        // Update stabilized frames
//        var (faceRect, cropRect) = _getNormRects(bestFace?.bounds, captureSize: image.extent.size)
//        faceRect = _lowpassFaceRect.update(faceRect)
//        cropRect = _lowpassCropRect.update(cropRect)
//
//        // Update containment
//        if let cropRect = cropRect {
//            let relBounds = _videoLayer.normRect(captureSize: image.extent.size)
//            containment = relBounds.contains(cropRect) ? .inside : .outside
//        } else {
//            containment = .none
//        }
//
//        DispatchQueue.main.async { [weak self] in
//            self?._displayVideoOverlays(captureSize: image.extent.size)
//        }
//
//        // Capture photo if smiling
//        if !_isCapturingPhoto && captureWhenSmiling && bestFace?.hasSmile == true { capturePhoto() }
//    }
//
//    private func _getBiggestFace(image: CIImage) -> CIFaceFeature?
//    {
//        let options: [String: Any] = [
//            CIDetectorSmile: true,
//            CIDetectorTracking: true
//        ]
//        let allFeatures = _faceDetector?.features(in: image, options: options)
//        let faceFeatures = allFeatures?.compactMap { $0 as? CIFaceFeature }
//        let biggestFace = faceFeatures?.max(by: { $0.bounds.area < $1.bounds.area } )
//        return biggestFace
//    }
//
//    private func _getNormRects(_ faceRect: CGRect?, captureSize: CGSize) -> (CGRect?, CGRect?)
//    {
//        guard let faceRect = faceRect else { return(nil, nil) }
//
//        let normFace = CGRect(
//            x      : faceRect.origin.x / captureSize.width,
//            y      : faceRect.origin.y / captureSize.height,
//            width  : faceRect.size.width / captureSize.width,
//            height : faceRect.size.height / captureSize.height
//        )
//
//        // Crop rect is larger... s is scale factor extension relative to the face width
//        let s = faceToPhotoWidthExtensionFactor
//        let viewAspectRatio = _videoLayer.bounds.size.width / _videoLayer.bounds.size.height
//        let sw: CGFloat = (faceRect.size.width * s) / captureSize.width
//        let sh: CGFloat = (faceRect.size.width * s) / captureSize.height / viewAspectRatio
//        let cropRect = CGRect(x: normFace.midX - sw/2, y: normFace.midY - sh/2, width: sw, height: sh)
//
//        return (normFace, cropRect)
//    }
//}
//
//
//extension ProfileShotView: AVCapturePhotoCaptureDelegate
//{
//    private func _capturePhoto()
//    {
//        if _isCapturingPhoto { return }
//
//        let photoSettings = AVCapturePhotoSettings()
//        if let photoPreviewType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
//            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoPreviewType]
//            photoSettings.isHighResolutionPhotoEnabled = true
//            photoSettings.isDepthDataDeliveryEnabled = true
//            photoSettings.isPortraitEffectsMatteDeliveryEnabled = true
//            photoSettings.embedsDepthDataInPhoto = true
//            photoSettings.embedsPortraitEffectsMatteInPhoto = true
//            photoSettings.previewPhotoFormat = nil
//            photoSettings.isDepthDataFiltered = true
//            _isCapturingPhoto = true
//            _photoOutput.capturePhoto(with: photoSettings, delegate: self)
//        } else {
//            delegate?.profileShotView(self, didCapturePhoto: nil)
//        }
//    }
//
//    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?)
//    {
//        defer {
//            _isCapturingPhoto = false
//            stopCamera()
//        }
//
//        guard
//            let cgImageRef = photo.cgImageRepresentation()
////            let matte = photo.portraitEffectsMatte
//        else {
//            print("No image data or portrait matte for photo.")
//            // TODO: Call delegate with error
//            return
//        }
//
//        let image = CIImage(cgImage: cgImageRef.takeUnretainedValue())
//        var maskedImage = image
//        if let matte = photo.portraitEffectsMatte {
//            let mask = CIImage(cvPixelBuffer: matte.mattingImage)
//            maskedImage = ImageFilters.matteMask(image: image, background: _clearBackground, mask: mask)
//        } else {
//           // print("No matte; proceeding without mask")
//        }
//
//        // Fix orientation
//        var orientation: CGImagePropertyOrientation?
//        if let orientationNum = photo.metadata[kCGImagePropertyOrientation as String] as? NSNumber {
//            orientation = CGImagePropertyOrientation(rawValue: orientationNum.uint32Value)
//        }
//        if let orientation = orientation {
//            maskedImage = maskedImage.oriented(orientation)
//        }
//
//        // Crop around the face if we have a crop rect inside the video layer.
//        // Else grab the entire video layer
//        let relBounds = _videoLayer.normRect(captureSize: maskedImage.extent.size)
//        let cropRect = _lowpassCropRect.value
//        let useRect: CGRect
//        if let cropRect = cropRect, relBounds.contains(cropRect) {
//            useRect = cropRect
//        } else {
//            useRect = relBounds
//        }
//        guard let croppedCGImage = Self._getCroppedCGImage(maskedImage, relCIRect: useRect) else {
//            // TODO: Call delegate with error
//            return
//        }
//
//        // Create a saveable UIImage to send to the delegate
//        let uiImage = UIImage(cgImage: croppedCGImage)
//        let saveableImage = UIImage(data: uiImage.pngData()!)!
//
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//            self._displayPhoto(croppedCGImage)
//            self.delegate?.profileShotView(self, didCapturePhoto: saveableImage)
//        }
//    }
//
//    private static func _getCroppedCGImage(_ ciImage: CIImage, relCIRect: CGRect?) -> CGImage?
//    {
//        var relRect = relCIRect ?? CGRect(x: 0, y: 0, width: 1, height: 1)
//
//        // The rect is for the mirrored video image, so mirror it back here since the photo is not mirrored
//        relRect.origin.x = 1 - relRect.origin.x - relRect.width
//        let w = ciImage.extent.size.width
//        let h = ciImage.extent.size.height
//        let rect = CGRect(x: relRect.origin.x * w, y: relRect.origin.y * h, width: relRect.size.width * w, height: relRect.size.height * h)
//        let croppedImage = ciImage.cropped(to: rect)
//
//        let cgImage = CIContext().createCGImage(croppedImage, from: croppedImage.extent)
//        return cgImage
//    }
//}
//
//
//// MARK: - Display photo and video with face frame in this view
//
//extension ProfileShotView
//{
//    private func _displayVideoOverlays(captureSize: CGSize)
//    {
//        _videoLayer.faceIndicatorColor      = faceIndicatorColor.cgColor
//        _videoLayer.containmentInsideColor  = containmentInsideColor.cgColor
//        _videoLayer.containmentOutsideColor = containmentOutsideColor.cgColor
//        _videoLayer.containmentMaskColor    = containmentMaskColor.cgColor
//
//        _videoLayer.drawOverlays(faceRect: _lowpassFaceRect.value, cropRect: _lowpassCropRect.value, captureSize: captureSize)
//    }
//
//    private func _displayPhoto(_ cgImage: CGImage)
//    {
//        _photoLayer.photo = cgImage
//
//        _videoLayer.isHidden = true
//        _photoLayer.isHidden = false
//    }
//}
