import QuartzCore
import UIKit  // For checkerboard colors


public class PhotoLayer: CALayer
{
    public enum Background
    {
        case checkerboard(CGFloat)
        case color(CGColor)
        case image(CGImage)
    }
    
    internal let _photoLayer = CALayer()
    internal let _backgroundLayer = CALayer()
    
    public var background: Background = .checkerboard(20) { didSet {
        _backgroundLayer.setNeedsDisplay()
    } }
    public var photo: CGImage? = nil { didSet {
        //_drawPhoto()
        setNeedsDisplay()
    } }
    
    public convenience init(_ background: Background)
    {
        self.init()
        _backgroundLayer.contentsGravity = .resizeAspectFill
        _photoLayer.contentsGravity = .resizeAspect
        addSublayer(_backgroundLayer)
        addSublayer(_photoLayer)
        _backgroundLayer.delegate = self
        self.setNeedsDisplay()
    }

    override public func layoutSublayers()
    {
        super.layoutSublayers()
        _backgroundLayer.frame = bounds
        _photoLayer.frame = bounds
    }
    
    override public func draw(in ctx: CGContext)
    {
        _drawPhoto()
    }
    
    public func _drawPhoto()
    {
        _photoLayer.contents = photo
    }
}

extension PhotoLayer: CALayerDelegate
{
    public func draw(_ layer: CALayer, in ctx: CGContext)
    {
        switch background
        {
        case .checkerboard(let size): _drawCheckerboard(in: ctx, blockSize: size)
        case .color(let color): _drawColor(in: ctx, color: color)
        case .image(let image): _drawImage(in: ctx, image: image)
        }
    }
    
    private func _drawCheckerboard(in ctx: CGContext, blockSize: CGFloat)
    {
        let bg1, bg2: UIColor
        if #available(iOS 13, *) {
            bg1 = UIColor.systemBackground
            bg2 = UIColor.secondarySystemBackground
        } else {
            bg1 = UIColor.white
            bg2 = UIColor.lightGray
        }
        
        ctx.setFillColor(bg1.cgColor)
        ctx.fill(bounds)
        ctx.setFillColor(bg2.cgColor)
        let columns = Int(ceil(bounds.width / blockSize))
        let rows = Int(ceil(bounds.height / blockSize))
        for row in 0 ..< rows {
            for col in 0 ..< columns {
                if (row + col) % 2 == 0 {
                    ctx.fill(CGRect(x: CGFloat(col) * blockSize, y: CGFloat(row) * blockSize, width: blockSize, height: blockSize))
                }
            }
        }
    }
    
    private func _drawColor(in ctx: CGContext, color: CGColor)
    {
        ctx.setFillColor(color)
        ctx.fill(bounds)
    }
    
    private func _drawImage(in ctx: CGContext, image: CGImage)
    {
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: bounds)
        ctx.restoreGState()
    }
}
