import Foundation
import SwiftData

protocol CollageDatabase {
    func fetchCollages() throws -> [Collage]
    func fetchCollage(id: UUID) throws -> Collage?
    func upsert(_ collage: Collage) throws
}

final class CollageDatabaseImpl: CollageDatabase, Database {
    typealias Entity = CollageEntity
    let container: ModelContainer

    init() throws {
        let schema = Schema([
            CollageEntity.self,
            CollageItemEntity.self
        ])
        container = try ModelContainer(for: schema)
    }

    func fetchCollages() throws -> [Collage] {
        try read(sortBy: SortDescriptor(\.updatedAt, order: .reverse)).map { $0.toDomain() }
    }

    func fetchCollage(id: UUID) throws -> Collage? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CollageEntity>(predicate: #Predicate<CollageEntity> { entity in
            entity.id == id
        })
        return try context.fetch(descriptor).first?.toDomain()
    }

    func upsert(_ collage: Collage) throws {
        let context = ModelContext(container)
        let collageID = collage.id
        let descriptor = FetchDescriptor<CollageEntity>(predicate: #Predicate<CollageEntity> { entity in
            entity.id == collageID
        })
        let entity = try context.fetch(descriptor).first ?? CollageEntity(
            id: collage.id,
            snapshotPath: collage.snapshotPath,
            createdAt: collage.createdAt,
            updatedAt: collage.updatedAt,
            items: []
        )

        entity.snapshotPath = collage.snapshotPath
        entity.createdAt = collage.createdAt
        entity.updatedAt = collage.updatedAt

        entity.items.forEach { context.delete($0) }
        entity.items.removeAll()
        entity.items = collage.items.map { CollageItemEntity.from($0, collage: entity) }

        context.insert(entity)
        try context.save()
    }
}
