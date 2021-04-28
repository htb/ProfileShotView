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
                        DispatchQueue.main.async {
                            completion?(true, nil)
                        }
                    }
                } catch let error {
                    DispatchQueue.main.async {
                        completion?(false, error)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion?(false, PHPhotosError(.libraryVolumeOffline))
                }
            }
        }
    }
}
