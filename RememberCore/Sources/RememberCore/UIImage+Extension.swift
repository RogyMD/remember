import UIKit

extension UIImage {
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
