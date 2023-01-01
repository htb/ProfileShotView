import CoreImage


public class ImageFilters
{
    public static func matteMask(image: CIImage, background: CIImage, mask: CIImage) -> CIImage
    {
        let scale = max(image.extent.width, image.extent.height) / max(mask.extent.width, mask.extent.height)
        let scaledMask = mask.applyingFilter("CIBicubicScaleTransform", parameters: [ "inputScale": scale ])
        
        let crop = CIVector(x: 0, y: 0, z: image.extent.size.width, w: image.extent.size.height)
        let croppedBG = background.applyingFilter("CICrop", parameters: ["inputRectangle": crop])
        let filtered = image.applyingFilter("CIBlendWithMask", parameters: [
            "inputBackgroundImage": croppedBG,
            "inputMaskImage": scaledMask
        ])
        return filtered
    }
}
