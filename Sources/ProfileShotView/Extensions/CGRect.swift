import CoreGraphics


extension CGRect
{
    public var area: CGFloat
    {
        return abs(self.maxX - self.minX) * abs(self.maxY - self.minY)
    }
}


func *(left: CGRect, right: CGSize) -> CGRect
{
    return CGRect(x: left.origin.x * right.width, y: left.origin.y * right.height, width: left.width * right.width, height: left.height * right.height)
}

func /(left: CGRect, right: CGSize) -> CGRect
{
    return left * CGSize(width: 1/right.width, height: 1/right.height)
}

func *(left: CGRect, right: CGFloat) -> CGRect
{
    return CGRect(x: left.origin.x * right, y: left.origin.y * right, width: left.width * right, height: left.height * right)
}

func /(left: CGRect, right: CGFloat) -> CGRect
{
    return left * (1/right)
}
