import Foundation
import SwiftData

protocol Database {
    associatedtype Entity: PersistentModel
    var container: ModelContainer { get }
    func create(_ entity: Entity) throws
    func read(sortBy sortDescriptors: SortDescriptor<Entity>...) throws -> [Entity]
    func update(_ entity: Entity) throws
}

extension Database {
    func create(_ entity: Entity) throws {
        let context = ModelContext(container)
        context.insert(entity)
        try context.save()
    }

    func read(sortBy sortDescriptors: SortDescriptor<Entity>...) throws -> [Entity] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Entity>(sortBy: sortDescriptors)
        return try context.fetch(descriptor)
    }

    func update(_ entity: Entity) throws {
        let context = ModelContext(container)
        context.insert(entity)
        try context.save()
    }
}
