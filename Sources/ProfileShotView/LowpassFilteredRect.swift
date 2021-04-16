import CoreGraphics


public class LowpassFilteredRect
{
    private let _x      = LowpassFilteredValueVariable()
    private let _y      = LowpassFilteredValueVariable()
    private let _width  = LowpassFilteredValueVariable()
    private let _height = LowpassFilteredValueVariable()

    public var RC: Double
    {
        get {
            return _x.RC
        }
        set {
            _x.RC = newValue
            _y.RC = newValue
            _width.RC = newValue
            _height.RC = newValue
        }
    }

    public var modulo: Double?
    {
        get {
            return _x.modulo
        }
        set {
            _x.modulo = newValue
            _y.modulo = newValue
            _width.modulo = newValue
            _height.modulo = newValue
        }
    }
    
    public var value: CGRect?
    {
        get {
            guard let x = _x.value, let y = _y.value, let w = _width.value, let h = _height.value else { return nil }
            return CGRect(x: x, y: y, width: w, height: h)
        }
        set {
            if let v = newValue {
                _x.value = Double(v.origin.x)
                _y.value = Double(v.origin.y)
                _width.value = Double(v.size.width)
                _height.value = Double(v.size.height)
            } else {
                _x.value = nil; _y.value = nil; _width.value = nil; _height.value = nil
            }
        }
    }

    public init(RC: Double? = nil, modulo: Double? = nil)
    {
        if let rc = RC { self.RC = rc }
        self.modulo = modulo
    }
    
    @discardableResult
    public func update(_ newValue: CGRect?) -> CGRect?
    {
        guard let newValue = newValue else {
            value = nil
            return value
        }
        
        return CGRect(
            x: _x.update(Double(newValue.origin.x)),
            y: _y.update(Double(newValue.origin.y)),
            width: _width.update(Double(newValue.size.width)),
            height: _height.update(Double(newValue.size.height))
        )
    }
}
