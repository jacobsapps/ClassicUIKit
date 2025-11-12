import UIKit

struct CanvasItemModel: Identifiable {
    let id: UUID
    var baseImage: UIImage
    var cutoutImage: UIImage?
    var renderedImage: UIImage?
    var basePath: String?
    var cutoutPath: String?
    var usesCutout: Bool
    var shaderStack: [ShaderType]
    var transform: CollageItemTransform
    var zPosition: Int
    var isProcessingCutout: Bool
    var requiresAssetSave: Bool

    init(
        id: UUID = UUID(),
        baseImage: UIImage,
        cutoutImage: UIImage? = nil,
        renderedImage: UIImage? = nil,
        basePath: String? = nil,
        cutoutPath: String? = nil,
        usesCutout: Bool = false,
        shaderStack: [ShaderType] = [],
        transform: CollageItemTransform = .identity,
        zPosition: Int = 0,
        isProcessingCutout: Bool = false,
        requiresAssetSave: Bool = true
    ) {
        self.id = id
        self.baseImage = baseImage
        self.cutoutImage = cutoutImage
        self.renderedImage = renderedImage ?? baseImage
        self.basePath = basePath
        self.cutoutPath = cutoutPath
        self.usesCutout = usesCutout
        self.shaderStack = shaderStack
        self.transform = transform
        self.zPosition = zPosition
        self.isProcessingCutout = isProcessingCutout
        self.requiresAssetSave = requiresAssetSave
    }

    var activeImage: UIImage {
        usesCutout ? (cutoutImage ?? baseImage) : baseImage
    }
}
