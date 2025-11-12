import UIKit

enum ImageFileManager {
    enum Compression {
        case jpeg(CGFloat)
        case png
    }

    static func save(_ image: UIImage, key: String, compression: Compression) {
        guard let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = folder.appendingPathComponent(key)
        let data: Data?
        switch compression {
        case .jpeg(let quality):
            data = image.jpegData(compressionQuality: quality)
        case .png:
            data = image.pngData()
        }
        guard let data else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func url(for key: String?) -> URL? {
        guard let key,
              let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return folder.appendingPathComponent(key)
    }

    static func data(for key: String?) -> Data? {
        guard let url = url(for: key) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func image(for key: String?) -> UIImage? {
        guard let data = data(for: key) else { return nil }
        return UIImage(data: data)
    }

    static func delete(_ key: String?) {
        guard let key,
              let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(key))
    }
}
