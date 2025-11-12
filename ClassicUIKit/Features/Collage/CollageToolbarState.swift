import Foundation

struct CollageToolbarState: Equatable {
    var isVisible: Bool
    var isCutoutActive: Bool
    var shaderStates: [ShaderType: Bool]

    static let hidden = CollageToolbarState(isVisible: false, isCutoutActive: false, shaderStates: [:])
}
