import FactoryKit
import UIKit

extension Container {
    var collageDatabase: Factory<CollageDatabase> {
        self { try! CollageDatabaseImpl() }.singleton
    }

    var collageRepository: Factory<CollageRepository> {
        self { CollageRepositoryImpl(database: self.collageDatabase()) }.singleton
    }

    var imageLoader: Factory<ImageLoader> {
        self { ImageLoaderImpl() }
    }

    var photoLibraryService: Factory<PhotoLibraryService> {
        self { PhotoLibraryServiceImpl() }.singleton
    }

    var shaderProcessingService: Factory<ShaderProcessingService> {
        self { ShaderProcessingServiceImpl() }.singleton
    }
}
