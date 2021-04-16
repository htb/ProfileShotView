import UIKit
import Photos


extension UIImage
{
    public func saveToPhotoLibrary(completion: ((_ success: Bool, _ error: Error?)->Void)?)
    {
        let image = self
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                do {
                    try PHPhotoLibrary.shared().performChangesAndWait {
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                        completion?(true, nil)
                    }
                } catch let error {
                    completion?(false, error)
                }
            } else {
                completion?(false, NSError(domain: PHPhotosError.errorDomain, code: PHPhotosError.libraryVolumeOffline.rawValue, userInfo: nil))
            }
        }
    }
}
