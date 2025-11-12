import UIKit

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage? {
        let maxSide = max(size.width, size.height)
        guard maxSide > 0 else { return self }
        let scaleRatio = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scaleRatio, height: size.height * scaleRatio)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1)
        draw(in: CGRect(origin: .zero, size: newSize))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
