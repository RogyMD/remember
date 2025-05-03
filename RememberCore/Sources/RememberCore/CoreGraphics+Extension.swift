import CoreGraphics
import UIKit

extension CGPoint {
  /// Converts a normalized point (from a full image) back to screen coordinates,
  /// accounting for the aspect fill cropping.
  public func convertPoint(from imageSize: CGSize, to bounds: CGRect) -> CGPoint {
    let imageAspectRatio = imageSize.width / imageSize.height
    let viewAspectRatio = bounds.width / bounds.height

    var scale: CGFloat
    var xOffset: CGFloat = 0
    var yOffset: CGFloat = 0

    if imageAspectRatio < viewAspectRatio {
      // Width is cropped
      scale = bounds.height / imageSize.height
      let scaledImageWidth = imageSize.width * scale
      xOffset = (bounds.width - scaledImageWidth) / 2
    } else {
      // Height is cropped
      scale = bounds.width / imageSize.width
      let scaledImageHeight = imageSize.height * scale
      yOffset = (bounds.height - scaledImageHeight) / 2
    }

    let screenX = self.x * scale + xOffset
    let screenY = self.y * scale + yOffset

    return CGPoint(x: screenX, y: screenY)
  }
}
