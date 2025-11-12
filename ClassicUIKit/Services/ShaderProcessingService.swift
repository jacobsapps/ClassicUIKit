import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

protocol ShaderProcessingService {
    func apply(shaders: [ShaderType], to image: UIImage) -> UIImage?
}

final class ShaderProcessingServiceImpl: ShaderProcessingService {

    private let context = CIContext()
    private let libraryData: Data?
    private lazy var pixellateKernel = Self.makeKernel(named: "pixellateShader", from: libraryData)
    private lazy var grainyKernel = Self.makeKernel(named: "grainyFilter", from: libraryData)
    private lazy var grayscaleKernel = Self.makeKernel(named: "grayscaleFilter", from: libraryData)
    private lazy var spectralKernel = Self.makeKernel(named: "spectralFilter", from: libraryData)
    private lazy var threeDGlassesKernel = Self.makeKernel(named: "threeDGlassesShader", from: libraryData)
    private lazy var glitchKernel = Self.makeKernel(named: "glitchShader", from: libraryData)
    private lazy var thickGlassKernel = Self.makeWarpKernel(named: "thickGlassSquares", from: libraryData)
    private lazy var lensKernel = Self.makeWarpKernel(named: "lensFilter", from: libraryData)

    init(bundle: Bundle = .main) {
        let libraryURL = bundle.url(forResource: "ImageShaders", withExtension: "metallib") ??
            bundle.url(forResource: "default", withExtension: "metallib")
        if let libraryURL,
           let data = try? Data(contentsOf: libraryURL) {
            libraryData = data
        } else {
            libraryData = nil
        }
    }

    func apply(shaders: [ShaderType], to image: UIImage) -> UIImage? {
        guard !shaders.isEmpty, var ciImage = CIImage(image: image) else {
            return image
        }

        for shader in shaders {
            switch shader {
            case .pixellate:
                guard let kernel = pixellateKernel else { continue }
                let maxDimension = max(ciImage.extent.width, ciImage.extent.height)
                let pixelScale = max(CGFloat(4), maxDimension / 50)
                ciImage = applyKernel(kernel, to: ciImage, arguments: [Float(pixelScale)])
            case .grainy:
                guard let kernel = grainyKernel else { continue }
                ciImage = applyKernel(kernel, to: ciImage)
            case .grayscale:
                guard let kernel = grayscaleKernel else { continue }
                ciImage = applyKernel(kernel, to: ciImage)
            case .spectral:
                guard let kernel = spectralKernel else { continue }
                ciImage = applyKernel(kernel, to: ciImage)
            case .threeDGlasses:
                guard let kernel = threeDGlassesKernel else { continue }
                ciImage = applyKernel(kernel, to: ciImage)
            case .glitch:
                guard let kernel = glitchKernel else { continue }
                let timeValue = Float(CFAbsoluteTimeGetCurrent().truncatingRemainder(dividingBy: 100))
                let args: [Any] = [
                    Float(ciImage.extent.width),
                    Float(ciImage.extent.height),
                    timeValue
                ]
                ciImage = applyKernel(kernel, to: ciImage, arguments: args)
            case .thickGlassSquares:
                guard let kernel = thickGlassKernel else { continue }
                let intensity = Float(min(ciImage.extent.width, ciImage.extent.height) / 32)
                ciImage = applyWarpKernel(kernel, to: ciImage, arguments: [intensity])
            case .lens:
                guard let kernel = lensKernel else { continue }
                let args: [Any] = [
                    Float(ciImage.extent.width),
                    Float(ciImage.extent.height),
                    Float(0.5),
                    Float(0.5),
                    Float(0.35),
                    Float(0.65)
                ]
                ciImage = applyWarpKernel(kernel, to: ciImage, arguments: args)
            }
        }

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private func applyKernel(_ kernel: CIKernel?, to image: CIImage, arguments: [Any] = []) -> CIImage {
        guard let kernel else { return image }
        var kernelArguments: [Any] = [image]
        kernelArguments.append(contentsOf: arguments)
        let roiCallback: CIKernelROICallback = { _, rect in rect }
        return kernel.apply(extent: image.extent, roiCallback: roiCallback, arguments: kernelArguments) ?? image
    }

    private static func makeKernel(named name: String, from data: Data?) -> CIKernel? {
        guard let data else { return nil }
        return try? CIKernel(functionName: name, fromMetalLibraryData: data)
    }

    private static func makeWarpKernel(named name: String, from data: Data?) -> CIWarpKernel? {
        guard let data else { return nil }
        return try? CIWarpKernel(functionName: name, fromMetalLibraryData: data)
    }

    private func applyWarpKernel(_ kernel: CIWarpKernel?, to image: CIImage, arguments: [Any] = []) -> CIImage {
        guard let kernel else { return image }
        return kernel.apply(
            extent: image.extent,
            roiCallback: { _, rect in rect },
            image: image,
            arguments: arguments
        ) ?? image
    }

}
