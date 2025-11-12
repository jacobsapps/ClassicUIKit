import UIKit
import Photos

protocol PhotoLibraryService: AnyObject {
    func presentPicker(from controller: UIViewController, delegate: (UIImagePickerControllerDelegate & UINavigationControllerDelegate)?)
    func saveImageToLibrary(_ image: UIImage, completion: @escaping (Bool) -> Void)
}

final class PhotoLibraryServiceImpl: NSObject, PhotoLibraryService {

    func presentPicker(from controller: UIViewController, delegate: (UIImagePickerControllerDelegate & UINavigationControllerDelegate)?) {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = delegate
        controller.present(picker, animated: true)
    }

    func saveImageToLibrary(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                completion(false)
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                completion(success)
            }
        }
    }
}
