import UIKit

extension UIImage {
  func croppedToScreen() async -> UIImage? {
    // Normalize the image to portrait orientation
    let image = self.fixedOrientation()
    
    // Use the screen's portrait ratio
    let screenSize = await MainActor.run {
      UIScreen.main.bounds.size
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
    return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
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
