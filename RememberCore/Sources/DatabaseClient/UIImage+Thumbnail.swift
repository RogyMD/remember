import UIKit
import RememberCore

extension UIImage {
  func thumbnailImage() async -> UIImage? {
    let scale = await MainActor.run { UIScreen.main.scale }
    let thumbnailImageSize = CGSize(
      width: CGSize.thumbnailSize.width * scale,
      height: CGSize.thumbnailSize.height * scale
    )
    
    let aspectWidth = thumbnailImageSize.width / size.width
    let aspectHeight = thumbnailImageSize.height / size.height
    let aspectFillScale = max(aspectWidth, aspectHeight)

    let scaledSize = CGSize(
      width: size.width * aspectFillScale,
      height: size.height * aspectFillScale
    )
    
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
    let resizedImage = renderer.image { _ in
      self.draw(in: CGRect(origin: .zero, size: scaledSize))
    }

    return resizedImage.cgImage?
      .cropping(
        to: CGRect(
          origin: CGPoint(
            x: (scaledSize.width - thumbnailImageSize.width) / 2,
            y: (scaledSize.height - thumbnailImageSize.height) / 2
          ),
          size: thumbnailImageSize
        )
      )
      .map(UIImage.init)
  }
}
