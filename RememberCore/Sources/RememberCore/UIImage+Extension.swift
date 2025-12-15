import UIKit

extension UIImage {
  public func previewImage() async -> UIImage? {
    let screenSize = await MainActor.run { UIScreen.main.bounds.size }
    return await self.resized(to: screenSize)
  }
  public func croppedToScreen() async -> UIImage? {
    // Normalize the image to portrait orientation
    let image = self.fixedOrientation()
    
    // Use the screen's portrait ratio
    let screenSize = await MainActor.run {
      let scale = UIScreen.main.scale
      let size = UIScreen.main.bounds.size
      return CGSize(width: size.width * scale, height: size.height * scale)
    }
    let screenRatio = screenSize.width / screenSize.height
    
    let imagePixelWidth = image.size.width * image.scale
    let imagePixelHeight = image.size.height * image.scale
    let imageRatio = imagePixelWidth / imagePixelHeight
    
    var cropWidth: CGFloat
    var cropHeight: CGFloat
    
    if imageRatio > screenRatio {
      // Image is wider than the portrait ratio, so use full height
      cropHeight = imagePixelHeight
      cropWidth = cropHeight * screenRatio
    } else {
      // Image is narrower than (or equal to) the portrait ratio, so use full width
      cropWidth = imagePixelWidth
      cropHeight = cropWidth / screenRatio
    }
    
    let originX = (imagePixelWidth - cropWidth) / 2
    let originY = (imagePixelHeight - cropHeight) / 2
    let cropRect = CGRect(x: originX, y: originY, width: cropWidth, height: cropHeight)
    
    guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return nil }
    let resultImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    guard resultImage.size.height > screenSize.height else { return resultImage }
    // Resize cropped image to match screen height
    let targetHeight = screenSize.height
    let aspectRatio = resultImage.size.width / resultImage.size.height
    let targetWidth = targetHeight * aspectRatio
    let targetSize = CGSize(width: targetWidth, height: targetHeight)

    let format = UIGraphicsImageRendererFormat()
    format.scale = resultImage.scale
    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

    let resizedImage = renderer.image { _ in
      resultImage.draw(in: CGRect(origin: .zero, size: targetSize))
    }
    return resizedImage
  }
  public func resized(to target: CGSize) async -> UIImage? {
    let scale = await MainActor.run { UIScreen.main.scale }
    let targetImageSize = CGSize(
      width: target.width * scale,
      height: target.height * scale
    )
    guard size.width > targetImageSize.width || size.height > targetImageSize.height else {
      return self
    }
    let aspectWidth = targetImageSize.width / size.width
    let aspectHeight = targetImageSize.height / size.height
    let aspectFitScale = min(aspectWidth, aspectHeight)
    let scaledSize = CGSize(
      width: size.width * aspectFitScale,
      height: size.height * aspectFitScale
    )
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
    let resizedImage = renderer.image { _ in
      self.draw(in: CGRect(origin: .zero, size: scaledSize))
    }
    return resizedImage.cgImage.map(UIImage.init)
  }
  public func resizedAndCropped(to target: CGSize) async -> UIImage? {
    let scale = await MainActor.run { UIScreen.main.scale }
    let targetImageSize = CGSize(
      width: target.width * scale,
      height: target.height * scale
    )
    guard size.width > targetImageSize.width || size.height > targetImageSize.height else {
      return self
    }
    let aspectWidth = targetImageSize.width / size.width
    let aspectHeight = targetImageSize.height / size.height
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
            x: (scaledSize.width - targetImageSize.width) / 2,
            y: (scaledSize.height - targetImageSize.height) / 2
          ),
          size: targetImageSize
        )
      )
      .map(UIImage.init)
  }
  
  private func fixedOrientation() -> UIImage {
    if self.imageOrientation == .up {
      return self
    }
    UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
    self.draw(in: CGRect(origin: .zero, size: self.size))
    let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    return normalizedImage
  }
}
