import UIKit
import CoreImage

protocol ShaderProcessingService {
    func apply(shaders: [ShaderType], to image: UIImage) -> UIImage?
}

final class ShaderProcessingServiceImpl: ShaderProcessingService {

    private let context = CIContext()

    func apply(shaders: [ShaderType], to image: UIImage) -> UIImage? {
        guard !shaders.isEmpty, var ciImage = CIImage(image: image) else {
            return image
        }

        for shader in shaders {
            guard let filter = makeFilter(for: shader, extent: ciImage.extent) else { continue }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            guard let output = filter.outputImage else { continue }
            ciImage = output
        }

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func makeFilter(for shader: ShaderType, extent: CGRect) -> CIFilter? {
        switch shader {
        case .pixellate:
            let filter = PixellateFilter()
            let maxDimension = max(extent.width, extent.height)
            let pixelScale = max(CGFloat(4), maxDimension / 50)
            filter.blockSize = Float(pixelScale)
            return filter
        case .grainy:
            return GrainyFilter()
        case .grayscale:
            return GrayscaleFilter()
        case .spectral:
            return SpectralFilter()
        case .threeDGlasses:
            return ThreeDGlassesShader()
        case .alien:
            return AlienFilter()
        case .thickGlassSquares:
            let filter = ThickGlassSquaresFilter()
            filter.intensity = Float(min(extent.width, extent.height) / 32)
            return filter
        case .lens:
            let filter = LensFilter()
            filter.width = Float(extent.width)
            filter.height = Float(extent.height)
            filter.centerX = 0.5
            filter.centerY = 0.5
            filter.radius = 0.35
            filter.intensity = 0.65
            return filter
        }
    }

}
