import UIKit

extension String {
  public static let previewSuffix = "-preview"
  public static let thumbnailSuffix = "-thumbnail"
}

extension CGSize {
  public static let thumbnailSize = CGSize(width: 80, height: 80)
}

extension Memory {
  static let dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    return dateFormatter
  }()
  
  public var memoryDirectoryName: String {
    let maxItems = 3
    let suffix = [String(id.prefix(3)), Self.dateFormatter.string(from: created)].joined(separator: "_")
    let extraItems = items.count - maxItems
    var itemsPrefix = items
      .sorted(by: { $0.name < $1.name })
      .prefix(maxItems)
      .map(\.name.sanitizedForFolderName)
      .joined(separator: "-")
    if extraItems > .zero {
      itemsPrefix += "+\(extraItems)"
    }
    return itemsPrefix.nonEmpty.map({ [$0, suffix].joined(separator: "_") }) ?? suffix
  }
  public var memoryDirectoryURL: URL {
    URL.memoryDirectory.appending(path: memoryDirectoryName, directoryHint: .isDirectory)
  }
  public var originalImageURL: URL {
    memoryDirectoryURL.appendingPathComponent("original").appendingPathExtension("png")
  }
  public var previewImageURL: URL {
    memoryDirectoryURL.appendingPathComponent("preview").appendingPathExtension("png")
  }
  public var thumbnailImageURL: URL {
    memoryDirectoryURL.appendingPathComponent("thumbnail").appendingPathExtension("png")
  }
  public var textFileURL: URL {
    memoryDirectoryURL.appendingPathComponent("memory").appendingPathExtension("txt")
  }
  public var previewImage: UIImage {
    UIImage(contentsOfFile: previewImageURL.path()) ?? UIImage(systemName: "exclamationmark.octagon.fill") ?? UIImage()
  }
  public var thumbnailImage: UIImage {
    if let thumbnail = UIImage(contentsOfFile: thumbnailImageURL.path()) {
      return thumbnail
    } else {
      return UIImage(systemName: "exclamationmark.octagon.fill") ?? UIImage()
    }
  }
}

extension Memory {
  public var deprecated_originalImageURL: URL {
    URL.imagesDirectory.appendingPathComponent(id).appendingPathExtension("png")
  }
  public var deprecated_previewImageURL: URL {
    URL.imagesDirectory.appendingPathComponent(id + .previewSuffix).appendingPathExtension("png")
  }
  public var deprecated_thumbnailImageURL: URL {
    URL.imagesDirectory.appendingPathComponent(id + .thumbnailSuffix).appendingPathExtension("png")
  }
}

extension URL {
  public static let imagesDirectory: URL = documentsDirectory.appendingPathComponent("Images", isDirectory: true)
  public static let memoryDirectory: URL = documentsDirectory.appendingPathComponent("Memories", isDirectory: true)
}

extension String {
  var sanitizedForFolderName: String {
    let sanitized = unicodeScalars.map { CharacterSet.folderNameAllowed.contains($0) ? Character($0) : "_" }
    return String(sanitized.prefix(15))
  }
}

extension CharacterSet {
  static let folderNameAllowed: CharacterSet = .urlPathAllowed.subtracting(.disallowedSymbols)
  private static let disallowedSymbols = CharacterSet(charactersIn: "/:\\?%*|\"<>{}[]() ")
}

extension CharacterSet {
  static let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
}
