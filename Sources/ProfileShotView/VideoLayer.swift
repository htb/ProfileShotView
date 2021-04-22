import AVFoundation
import UIKit // For default colors


public class VideoLayer: AVCaptureVideoPreviewLayer
{
    private let _maskLayer = CAShapeLayer()
    private let _faceFrameLayer = CAShapeLayer()
    private let _cropFrameLayer = CAShapeLayer()
    
    
    public var containmentInsideColor  : CGColor = UIColor.green.cgColor
    public var containmentOutsideColor : CGColor = UIColor.red.cgColor
    public var faceIndicatorColor      : CGColor = UIColor.cyan.cgColor
    public var containmentMaskColor    : CGColor = UIColor.black.withAlphaComponent(0.5).cgColor
    
    
    override public init(session: AVCaptureSession)
    {
        super.init(session: session)
        _commonInit()
    }
    
    // Since we are overriding the designated initialize..
    override public init(layer: Any)
    {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
        _commonInit()
    }
    
    private func _commonInit()
    {
        addSublayer(_maskLayer)
        addSublayer(_faceFrameLayer)
        addSublayer(_cropFrameLayer)
        _faceFrameLayer.fillColor = UIColor.clear.cgColor
        _cropFrameLayer.fillColor = UIColor.clear.cgColor
    }
    
    override public func layoutSublayers()
    {
        super.layoutSublayers()
        sublayers?.forEach { $0.frame = bounds }
    }

    private func _getMaskPath(_ rect: CGRect) -> CGPath
    {
        let path = UIBezierPath(rect: bounds)
        let maskPath = UIBezierPath(rect: rect)
        path.append(maskPath)
        path.usesEvenOddFillRule = true
        return path.cgPath
    }
    
    public func layerRect(normRect: CGRect?, captureSize: CGSize) -> CGRect?
    {
        guard var normRect = normRect else { return nil }

        // Normalized rectangle has Y up; convert to Y down
        normRect.origin.y = 1 - normRect.origin.y - normRect.size.height
        
        let s = _getScale(captureSize: captureSize)

        var layerRect = normRect * captureSize / s

        // Since it is centered with both .resizeAspect and .resizeAspectFill
        layerRect.origin.x += (bounds.width  - captureSize.width  / s) / 2
        layerRect.origin.y += (bounds.height - captureSize.height / s) / 2

        return layerRect
    }

    public func normRect(layerRect: CGRect? = nil, captureSize: CGSize) -> CGRect
    {
        var layerRect = layerRect ?? CGRect(origin: .zero, size: bounds.size)

        let s = _getScale(captureSize: captureSize)

        // Since it is centered with both .resizeAspect and .resizeAspectFill
        layerRect.origin.x -= (bounds.width  - captureSize.width  / s) / 2
        layerRect.origin.y -= (bounds.height - captureSize.height / s) / 2

        var normRect = layerRect / captureSize * s

        // Layer coordinate system has Y down; convert to Y up
        normRect.origin.y = 1 - normRect.origin.y - normRect.size.height

        return normRect
    }
    
    private func _getScale(captureSize: CGSize) -> CGFloat
    {
        // Scale from aspect ratio zoom in (.aspectFill) or out (.aspectFit)
        let s = (videoGravity == .resizeAspectFill)
            ? min(captureSize.width / bounds.width, captureSize.height / bounds.height)
            : max(captureSize.width / bounds.width, captureSize.height / bounds.height)
        return s
    }
    
    private class func _getFaceIndicatorPath(_ layerRect: CGRect) -> CGPath
    {
        let d: CGFloat = min(layerRect.height, layerRect.width) / 5
        let path = UIBezierPath()

        path.move(to: CGPoint(x: layerRect.minX + d , y: layerRect.minY))
        path.addQuadCurve(
            to: CGPoint(x: layerRect.minX , y: layerRect.minY + d),
            controlPoint: CGPoint(x: layerRect.minX, y: layerRect.minY)
        )
        path.move(to: CGPoint(x: layerRect.maxX - d , y: layerRect.minY))
        path.addQuadCurve(
            to: CGPoint(x: layerRect.maxX , y: layerRect.minY + d),
            controlPoint: CGPoint(x: layerRect.maxX, y: layerRect.minY)
        )
        path.move(to: CGPoint(x: layerRect.minX + d , y: layerRect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: layerRect.minX , y: layerRect.maxY - d),
            controlPoint: CGPoint(x: layerRect.minX, y: layerRect.maxY)
        )
        path.move(to: CGPoint(x: layerRect.maxX - d , y: layerRect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: layerRect.maxX , y: layerRect.maxY - d),
            controlPoint: CGPoint(x: layerRect.maxX, y: layerRect.maxY)
        )
        return path.cgPath
    }

    public func drawOverlays(faceRect: CGRect?, cropRect: CGRect?, captureSize: CGSize)
    {
        // Note: Face and crop rects are in CI space and normalized relative to captureSize

        if let layerRect = layerRect(normRect: faceRect, captureSize: captureSize) {
            _faceFrameLayer.lineWidth = 3
            _faceFrameLayer.strokeColor = faceIndicatorColor
            _faceFrameLayer.path = Self._getFaceIndicatorPath(layerRect)
            _faceFrameLayer.isHidden = false
        } else {
            _faceFrameLayer.isHidden = true
        }

        if let layerRect = layerRect(normRect: cropRect, captureSize: captureSize) {
            let isInside = bounds.contains(layerRect)

            _cropFrameLayer.lineWidth = (isInside ? 5 : 3)
            _cropFrameLayer.strokeColor = (isInside ? containmentInsideColor : containmentOutsideColor)
            _cropFrameLayer.path = UIBezierPath(rect: layerRect).cgPath
            _cropFrameLayer.isHidden = false
            
            _maskLayer.fillRule = .evenOdd
            _maskLayer.fillColor = containmentMaskColor
            _maskLayer.path = _getMaskPath(layerRect)
            _maskLayer.isHidden = false
            
        } else {
            _cropFrameLayer.isHidden = true
            _maskLayer.isHidden = true
        }
    }
}
