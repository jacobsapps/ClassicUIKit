import UIKit

struct GalleryDisplayModel: Hashable {
    let collage: Collage
    var image: UIImage?

    func hash(into hasher: inout Hasher) {
        hasher.combine(collage.id)
    }

    static func == (lhs: GalleryDisplayModel, rhs: GalleryDisplayModel) -> Bool {
        lhs.collage.id == rhs.collage.id && lhs.collage.updatedAt == rhs.collage.updatedAt
    }
}
