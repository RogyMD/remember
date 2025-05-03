import UIKit

extension String {
  public static let previewSuffix = "-preview"
  public static let thumbnailSuffix = "-thumbnail"
}

extension CGSize {
  public static let thumbnailSize = CGSize(width: 80, height: 80)
}

extension Memory {
  public var originalImageURL: URL {
    URL.imagesDirectory.appendingPathComponent(id).appendingPathExtension("png")
  }
  public var previewImageURL: URL {
    URL.imagesDirectory.appendingPathComponent(id + .previewSuffix).appendingPathExtension("png")
  }
  public var thumbnailImageURL: URL {
    URL.imagesDirectory.appendingPathComponent(id + .thumbnailSuffix).appendingPathExtension("png")
  }
  public var previewImage: UIImage {
    UIImage(contentsOfFile: previewImageURL.path()) ?? UIImage(systemName: "exclamationmark.octagon.fill")!
  }
  public var thumbnailImage: UIImage {
    if let thumbnail = UIImage(contentsOfFile: thumbnailImageURL.path()) {
      return thumbnail
    } else {
      return UIImage(systemName: "exclamationmark.octagon.fill")!
    }
  }
}

extension URL {
  public static let imagesDirectory: URL = documentsDirectory.appendingPathComponent("Images", isDirectory: true)
}
