import CoreImage
import CoreImageUtils
import Foundation

@SamplerKernel
final class GrainyFilter: CIFilter { }

@SamplerKernel
final class GrayscaleFilter: CIFilter { }

@SamplerKernel
final class SpectralFilter: CIFilter { }

@SamplerKernel
final class ThreeDGlassesShader: CIFilter { }

@ColorKernel
final class AlienFilter: CIFilter { }

final class PixellateFilter: CIFilter {

    @objc dynamic var inputImage: CIImage?
    @objc dynamic var blockSize: Float = 8

    override var outputImage: CIImage? {
        guard let inputImage,
              let filter = CIFilter(name: "CIPixellate") else { return nil }
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(blockSize, forKey: kCIInputScaleKey)
        let center = CIVector(x: inputImage.extent.midX, y: inputImage.extent.midY)
        filter.setValue(center, forKey: kCIInputCenterKey)
        return filter.outputImage
    }
}

final class ThickGlassSquaresFilter: CIFilter {

    @objc dynamic var intensity: Float = 32
    @objc dynamic var inputImage: CIImage?

    override var outputImage: CIImage? {
        guard let inputImage else { return nil }
        return Self.kernel.apply(
            extent: inputImage.extent,
            roiCallback: { _, rect in rect },
            image: inputImage,
            arguments: [intensity]
        )
    }

    private static let kernel: CIWarpKernel = {
        ShaderKernelLoader.warpKernel(named: "thickGlassSquares")
    }()
}

final class LensFilter: CIFilter {

    @objc dynamic var inputImage: CIImage?
    @objc dynamic var centerX: Float = 0.5
    @objc dynamic var centerY: Float = 0.5
    @objc dynamic var radius: Float = 0.35
    @objc dynamic var intensity: Float = 0.65

    override var outputImage: CIImage? {
        guard let inputImage else { return nil }
        let width = self.width > 0 ? self.width : Float(inputImage.extent.width)
        let height = self.height > 0 ? self.height : Float(inputImage.extent.height)
        return Self.kernel.apply(
            extent: inputImage.extent,
            roiCallback: { _, rect in rect },
            image: inputImage,
            arguments: [
                width,
                height,
                centerX,
                centerY,
                radius,
                intensity
            ]
        )
    }

    @objc dynamic var width: Float = 0
    @objc dynamic var height: Float = 0

    private static let kernel: CIWarpKernel = {
        ShaderKernelLoader.warpKernel(named: "lensFilter")
    }()
}

private enum ShaderKernelLoader {

    static func kernel(named name: String) -> CIKernel {
        guard let data = libraryData else {
            fatalError("Unable to load metal library data for kernel: \(name)")
        }
        do {
            return try CIKernel(functionName: name, fromMetalLibraryData: data)
        } catch {
            fatalError("Failed to create kernel \(name): \(error)")
        }
    }

    static func warpKernel(named name: String) -> CIWarpKernel {
        guard let data = libraryData else {
            fatalError("Unable to load metal library data for warp kernel: \(name)")
        }
        do {
            return try CIWarpKernel(functionName: name, fromMetalLibraryData: data)
        } catch {
            fatalError("Failed to create warp kernel \(name): \(error)")
        }
    }

    private static let libraryData: Data? = {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "ImageShaders", withExtension: "metallib"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let url = bundle.url(forResource: "default", withExtension: "metallib"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }()
}
