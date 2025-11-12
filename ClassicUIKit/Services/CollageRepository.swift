import UIKit

protocol CollageRepository {
    func loadCollages() throws -> [Collage]
    func loadCollage(id: UUID) throws -> Collage?
    func saveCollage(_ collage: Collage, snapshot: UIImage?) throws -> Collage
    func deleteCollage(id: UUID) throws
    func persistItemAssets(collageID: UUID, itemID: UUID, baseImage: UIImage, cutout: UIImage?) -> (basePath: String, cutoutPath: String?)
}

final class CollageRepositoryImpl: CollageRepository {

    private let database: CollageDatabase

    init(database: CollageDatabase) {
        self.database = database
    }

    func loadCollages() throws -> [Collage] {
        try database.fetchCollages()
    }

    func loadCollage(id: UUID) throws -> Collage? {
        try database.fetchCollage(id: id)
    }

    func saveCollage(_ collage: Collage, snapshot: UIImage?) throws -> Collage {
        var mutableCollage = collage
        if let snapshot {
            let path = fileName(for: collage.id, suffix: "snapshot.jpeg")
            ImageFileManager.save(snapshot, key: path, compression: .jpeg(0.85))
            mutableCollage.snapshotPath = path
        }
        mutableCollage.updatedAt = Date()
        try database.upsert(mutableCollage)
        return mutableCollage
    }

    func persistItemAssets(collageID: UUID, itemID: UUID, baseImage: UIImage, cutout: UIImage?) -> (basePath: String, cutoutPath: String?) {
        let basePath = fileName(for: collageID, itemID: itemID, suffix: "base.jpeg")
        ImageFileManager.save(baseImage, key: basePath, compression: .jpeg(0.85))
        var cutoutPath: String?
        if let cutout {
            let file = fileName(for: collageID, itemID: itemID, suffix: "cutout.png")
            ImageFileManager.save(cutout, key: file, compression: .png)
            cutoutPath = file
        }
        return (basePath, cutoutPath)
    }

    func deleteCollage(id: UUID) throws {
        if let collage = try loadCollage(id: id) {
            if let snapshotPath = collage.snapshotPath {
                ImageFileManager.delete(snapshotPath)
            }
            collage.items.forEach {
                ImageFileManager.delete($0.baseImagePath)
                if let cutoutPath = $0.cutoutImagePath {
                    ImageFileManager.delete(cutoutPath)
                }
            }
        }
        try database.deleteCollage(id: id)
    }

    private func fileName(for collageID: UUID, suffix: String) -> String {
        "\(collageID.uuidString)-\(suffix)"
    }

    private func fileName(for collageID: UUID, itemID: UUID, suffix: String) -> String {
        "\(collageID.uuidString)-\(itemID.uuidString)-\(suffix)"
    }
}
