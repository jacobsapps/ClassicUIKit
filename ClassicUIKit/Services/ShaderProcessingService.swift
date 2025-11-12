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
                let maxDimension = max(ciImage.extent.width, ciImage.extent.height)
                let pixelScale = max(CGFloat(4), maxDimension / 50)
                if let kernel = pixellateKernel {
                    ciImage = applyKernel(kernel, to: ciImage, arguments: [Float(pixelScale)])
                } else if let fallback = applyPixellateFallback(to: ciImage, scale: pixelScale) {
                    ciImage = fallback
                }
            case .grainy:
                if let kernel = grainyKernel {
                    ciImage = applyKernel(kernel, to: ciImage)
                }
            case .grayscale:
                if let kernel = grayscaleKernel {
                    ciImage = applyKernel(kernel, to: ciImage)
                }
            case .spectral:
                if let kernel = spectralKernel {
                    ciImage = applyKernel(kernel, to: ciImage)
                }
            case .threeDGlasses:
                if let kernel = threeDGlassesKernel {
                    ciImage = applyKernel(kernel, to: ciImage)
                } else if let fallback = applyThreeDFallback(to: ciImage) {
                    ciImage = fallback
                }
            case .glitch:
                let timeValue = Float(CFAbsoluteTimeGetCurrent().truncatingRemainder(dividingBy: 100))
                if let kernel = glitchKernel {
                    let args: [Any] = [
                        Float(ciImage.extent.width),
                        Float(ciImage.extent.height),
                        timeValue
                    ]
                    ciImage = applyKernel(kernel, to: ciImage, arguments: args)
                } else if let fallback = applyGlitchFallback(to: ciImage, time: timeValue) {
                    ciImage = fallback
                }
            case .thickGlassSquares:
                if let kernel = thickGlassKernel {
                    let intensity = Float(min(ciImage.extent.width, ciImage.extent.height) / 32)
                    ciImage = applyWarpKernel(kernel, to: ciImage, arguments: [intensity])
                }
            case .lens:
                if let kernel = lensKernel {
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

    private func applyPixellateFallback(to image: CIImage, scale: CGFloat) -> CIImage? {
        let filter = CIFilter.pixellate()
        filter.inputImage = image
        filter.scale = Float(scale)
        return filter.outputImage?.cropped(to: image.extent)
    }

    private func applyThreeDFallback(to image: CIImage) -> CIImage? {
        let redOnly = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ])
        let blueOnly = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ])
        let redShift = redOnly.applyingFilter("CIAffineTransform", parameters: [
            kCIInputTransformKey: CGAffineTransform(translationX: -3, y: -3)
        ])
        let blueShift = blueOnly.applyingFilter("CIAffineTransform", parameters: [
            kCIInputTransformKey: CGAffineTransform(translationX: 2, y: 2)
        ])
        return redShift.composited(over: blueShift).composited(over: image)
    }

    private func applyGlitchFallback(to image: CIImage, time: Float) -> CIImage? {
        guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage else { return image }
        let offset = CGFloat(sin(time) * 15)
        let displacedNoise = noise
            .applyingFilter("CIAffineTransform", parameters: [
                kCIInputTransformKey: CGAffineTransform(translationX: offset, y: 0)
            ])
            .applyingFilter("CIAffineTransform", parameters: [
                kCIInputTransformKey: CGAffineTransform(scaleX: 2, y: 2)
            ])
        return image.applyingFilter("CIDisplacementDistortion", parameters: [
            "inputDisplacementImage": displacedNoise,
            kCIInputScaleKey: 25
        ])
    }
}
