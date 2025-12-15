import CoreGraphics
import UIKit

extension CGPoint {
  /// Converts a normalized point (from a full image) back to screen coordinates,
  /// accounting for the aspect fit cropping.
  public func convertPoint(from imageSize: CGSize, to bounds: CGRect) -> CGPoint {
    let imageAspectRatio = imageSize.width / imageSize.height
    let viewAspectRatio = bounds.width / bounds.height

    let scale: CGFloat
    if imageAspectRatio < viewAspectRatio {
      // Width is cropped
      scale = bounds.height / imageSize.height
    } else {
      // Height is cropped
      scale = bounds.width / imageSize.width
    }
    
    let scaledImageWidth = imageSize.width * scale
    let xOffset = (bounds.width - scaledImageWidth) / 2
    let scaledImageHeight = imageSize.height * scale
    let yOffset = (bounds.height - scaledImageHeight) / 2

    let screenX = self.x * scale + xOffset
    let screenY = self.y * scale + yOffset

    return CGPoint(x: screenX, y: screenY)
  }
}

extension CGRect {
  public func convertFrame(from imageSize: CGSize, to bounds: CGRect) -> CGRect {
    let imageAspectRatio = imageSize.width / imageSize.height
    let viewAspectRatio = bounds.width / bounds.height

    let scale: CGFloat
    if imageAspectRatio < viewAspectRatio {
      scale = bounds.height / imageSize.height
    } else {
      scale = bounds.width / imageSize.width
    }
    
    let scaledImageWidth = imageSize.width * scale
    let xOffset = (bounds.width - scaledImageWidth) / 2
    let scaledImageHeight = imageSize.height * scale
    let yOffset = (bounds.height - scaledImageHeight) / 2
    return self.applying(
      .init(
        scaleX: scale,
        y: scale
      ).concatenating(
        .init(
          translationX: xOffset,
          y: yOffset
        )
      )
    )
  }
}
