import Foundation
import CoreGraphics

struct Collage: Identifiable, Equatable {
    let id: UUID
    var snapshotPath: String?
    var createdAt: Date
    var updatedAt: Date
    var items: [CollageItem]

    init(id: UUID = UUID(), snapshotPath: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date(), items: [CollageItem] = []) {
        self.id = id
        self.snapshotPath = snapshotPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.items = items
    }
}

struct CollageItem: Identifiable, Equatable {
    let id: UUID
    var baseImagePath: String
    var cutoutImagePath: String?
    var usesCutout: Bool
    var zPosition: Int
    var transform: CollageItemTransform
    var shaderStack: [ShaderType]

    init(
        id: UUID = UUID(),
        baseImagePath: String,
        cutoutImagePath: String? = nil,
        usesCutout: Bool = false,
        zPosition: Int = 0,
        transform: CollageItemTransform = .identity,
        shaderStack: [ShaderType] = []
    ) {
        self.id = id
        self.baseImagePath = baseImagePath
        self.cutoutImagePath = cutoutImagePath
        self.usesCutout = usesCutout
        self.zPosition = zPosition
        self.transform = transform
        self.shaderStack = shaderStack
    }
}

struct CollageItemTransform: Codable, Equatable {
    var translation: CGPoint
    var scale: CGFloat
    var rotation: CGFloat
    var size: CGSize

    static var identity: CollageItemTransform {
        CollageItemTransform(translation: .zero, scale: 1.0, rotation: 0, size: .zero)
    }
}

enum ShaderType: String, Codable, CaseIterable {
    case pixellate
    case grainy
    case grayscale
    case spectral
    case threeDGlasses
    case alien
    case thickGlassSquares
    case lens

    static var allCases: [ShaderType] {
        [
            .pixellate,
            .grainy,
            .grayscale,
            .spectral,
            .threeDGlasses,
            .alien,
            .thickGlassSquares,
            .lens
        ]
    }

    var symbolName: String {
        switch self {
        case .pixellate:
            return "squareshape.split.3x3"
        case .grainy:
            return "water.waves"
        case .grayscale:
            return "circle.lefthalf.filled"
        case .spectral:
            return "laser.burst"
        case .threeDGlasses:
            return "eyeglasses"
        case .alien:
            return "globe.asia.australia.fill"
        case .thickGlassSquares:
            return "square.grid.2x2.fill"
        case .lens:
            return "globe.fill"
        }
    }

}
