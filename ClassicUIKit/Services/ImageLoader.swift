import UIKit

protocol ImageLoader {
    func image(for path: String?) -> UIImage?
}

struct ImageLoaderImpl: ImageLoader {
    func image(for path: String?) -> UIImage? {
        ImageFileManager.image(for: path)
    }
}
