import Foundation


/// Lowpass filter, for smoothing signal readings based on previous reading.
public class LowpassFilter
{
    /// Higher RC makes the filter smoother but slower
    public var RC: Double = 0.15 { didSet { _calcAlpha() } }
    /// Update frequency, 1/s
    public var updateFrequency: Double { didSet { _calcAlpha() } }
    /// The smoothing value, between 0 and 1, where lower is smoother.
    /// Calculated from RC and updateFrequency
    public private(set) var alpha: Double = 0.0

    public init(_ updateFrequency: Double, RC: Double? = nil)
    {
        self.updateFrequency = updateFrequency
        if let rc = RC { self.RC = rc}
        _calcAlpha()
    }

    /// Calculate and returns the filtered value based on the new signal reading and old value.
    public func filter(new newValue: Double, old oldValue: Double) -> Double
    {
        return newValue * alpha + (1.0 - alpha) * oldValue;
    }

    private func _calcAlpha()
    {
        alpha = 1.0 / (RC / updateFrequency + 1.0)
    }
}

/// Like the LowpassFilter, only it stores a value so you use update(_) instead of filter().
public class LowpassFilteredValue : LowpassFilter
{
    /// Set initial value manually, otherwise use update(_) to retrieve a new value.
    public var value: Double = 0.0

    /// Filter the new signal value. Returns the filtered value.
    @discardableResult
    public func update(_ newValue: Double) -> Double
    {
        value = filter(new: newValue, old: value)
        return value
    }
}


/// Like the LowpassFilteredValue, but update interval varies
public class LowpassFilteredValueVariable
{
    /// Higher RC makes the filter smoother but slower
    public var RC: Double = 0.15
    /// Allows for circular values, such as compass repeating after 360 degrees;
    /// in this case it moves towards the closest value in any direction.
    public var modulo: Double? = nil
    /// Time of last observed value
    public private(set) var lastObservation: TimeInterval = 0

    /// Set initial value manually, otherwise use update(_) to retrieve a new value.
    public var value: Double? = nil {
        didSet {
            lastObservation = Date.timeIntervalSinceReferenceDate
        }
    }

    public init(RC: Double? = nil, modulo: Double? = nil)
    {
        if let rc = RC { self.RC = rc}
        self.modulo = modulo
    }

    /// Filter the new signal value. Returns the filtered value.
    @discardableResult
    public func update(_ newValue: Double) -> Double
    {
        let now = Date.timeIntervalSinceReferenceDate
        let interval = now - lastObservation
        lastObservation = now

        guard let oldValue = value else {
            value = newValue
            return newValue
        }
        if interval == 0 {
            return oldValue
        }

        if let modulo = modulo, abs(newValue - oldValue) > modulo / 2.0 {
            let nv = fmod(newValue + modulo/2.0, modulo)
            let ov = fmod(oldValue + modulo/2.0, modulo)
            let v = fmod(_filter(nv, ov, interval) + modulo/2.0, modulo)
            value = v
            return v
        } else {
            let v = _filter(newValue, oldValue, interval)
            value = v
            return v
        }
    }

    private func _filter(_ newValue: Double, _ oldValue: Double, _ interval: Double) -> Double
    {
        let alpha = 1.0 / (RC / interval + 1.0)
        return newValue * alpha + (1.0 - alpha) * oldValue;
    }
}
