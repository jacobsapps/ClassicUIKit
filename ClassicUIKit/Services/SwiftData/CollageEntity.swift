import Foundation
import SwiftData

@Model
final class CollageEntity {
    @Attribute(.unique) var id: UUID
    var snapshotPath: String?
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \CollageItemEntity.collage)
    var items: [CollageItemEntity]

    init(id: UUID, snapshotPath: String?, createdAt: Date, updatedAt: Date, items: [CollageItemEntity]) {
        self.id = id
        self.snapshotPath = snapshotPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.items = items
    }
}

@Model
final class CollageItemEntity {
    @Attribute(.unique) var id: UUID
    var baseImagePath: String
    var cutoutImagePath: String?
    var usesCutout: Bool
    var zPosition: Int
    var rotation: Double
    var scale: Double
    var translationX: Double
    var translationY: Double
    var width: Double
    var height: Double
    var shaderStack: [String]
    var createdAt: Date
    var updatedAt: Date

    @Relationship var collage: CollageEntity?

    init(
        id: UUID,
        baseImagePath: String,
        cutoutImagePath: String?,
        usesCutout: Bool,
        zPosition: Int,
        rotation: Double,
        scale: Double,
        translationX: Double,
        translationY: Double,
        width: Double,
        height: Double,
        shaderStack: [String],
        createdAt: Date,
        updatedAt: Date,
        collage: CollageEntity?
    ) {
        self.id = id
        self.baseImagePath = baseImagePath
        self.cutoutImagePath = cutoutImagePath
        self.usesCutout = usesCutout
        self.zPosition = zPosition
        self.rotation = rotation
        self.scale = scale
        self.translationX = translationX
        self.translationY = translationY
        self.width = width
        self.height = height
        self.shaderStack = shaderStack
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.collage = collage
    }
}

extension CollageEntity {
    func toDomain() -> Collage {
        Collage(
            id: id,
            snapshotPath: snapshotPath,
            createdAt: createdAt,
            updatedAt: updatedAt,
            items: items.sorted { $0.zPosition < $1.zPosition }.map { $0.toDomain() }
        )
    }

    static func from(_ collage: Collage) -> CollageEntity {
        let entity = CollageEntity(
            id: collage.id,
            snapshotPath: collage.snapshotPath,
            createdAt: collage.createdAt,
            updatedAt: collage.updatedAt,
            items: []
        )
        entity.items = collage.items.map { CollageItemEntity.from($0, collage: entity) }
        return entity
    }
}

extension CollageItemEntity {
    func toDomain() -> CollageItem {
        CollageItem(
            id: id,
            baseImagePath: baseImagePath,
            cutoutImagePath: cutoutImagePath,
            usesCutout: usesCutout,
            zPosition: zPosition,
            transform: CollageItemTransform(
                translation: CGPoint(x: translationX, y: translationY),
                scale: CGFloat(scale),
                rotation: CGFloat(rotation),
                size: CGSize(width: width, height: height)
            ),
            shaderStack: shaderStack.compactMap(ShaderType.init(rawValue:))
        )
    }

    static func from(_ item: CollageItem, collage: CollageEntity?) -> CollageItemEntity {
        CollageItemEntity(
            id: item.id,
            baseImagePath: item.baseImagePath,
            cutoutImagePath: item.cutoutImagePath,
            usesCutout: item.usesCutout,
            zPosition: item.zPosition,
            rotation: Double(item.transform.rotation),
            scale: Double(item.transform.scale),
            translationX: Double(item.transform.translation.x),
            translationY: Double(item.transform.translation.y),
            width: Double(item.transform.size.width),
            height: Double(item.transform.size.height),
            shaderStack: item.shaderStack.map { $0.rawValue },
            createdAt: Date(),
            updatedAt: Date(),
            collage: collage
        )
    }
}
