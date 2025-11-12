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
    private lazy var threeDGlassesKernel = Self.makeKernel(named: "threeDGlassesShader", from: libraryData)
    private lazy var glitchKernel = Self.makeKernel(named: "glitchShader", from: libraryData)

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
                let maxDimension = max(ciImage.extent.width, ciImage.extent.height)
                let pixelScale = max(CGFloat(8), maxDimension / 25)
                ciImage = applyKernel(pixellateKernel, to: ciImage, arguments: [Float(pixelScale)])
            case .threeDGlasses:
                ciImage = applyKernel(threeDGlassesKernel, to: ciImage)
            case .glitch:
                let timeValue = Float(CFAbsoluteTimeGetCurrent().truncatingRemainder(dividingBy: 100))
                let args: [Any] = [
                    Float(ciImage.extent.width),
                    Float(ciImage.extent.height),
                    timeValue
                ]
                ciImage = applyKernel(glitchKernel, to: ciImage, arguments: args)
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
}
