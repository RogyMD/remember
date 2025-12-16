import UIKit

extension String {
  public static let previewSuffix = "-preview"
  public static let thumbnailSuffix = "-thumbnail"
}

extension CGSize {
  public static let thumbnailSize = CGSize(width: 80, height: 80)
}

extension Memory {
  public var displayTitle: String {
    items.map(\.name).sorted(using: SortDescriptor(\.self)).joined(separator: ", ")
  }
}

extension Memory {
  public var directoryName: String {
    let maxItems = 3
    let suffix = String(id.prefix(6))
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
  public var directoryURL: URL {
    URL.memoryDirectory.appending(path: directoryName, directoryHint: .isDirectory)
  }
  public var originalImageURL: URL {
    directoryURL.appendingPathComponent("original").appendingPathExtension("png")
  }
  public var previewImageURL: URL {
    directoryURL.appendingPathComponent("preview").appendingPathExtension("png")
  }
  public var thumbnailImageURL: URL {
    directoryURL.appendingPathComponent("thumbnail").appendingPathExtension("png")
  }
  public var textFileURL: URL {
    directoryURL.appendingPathComponent("memory").appendingPathExtension("txt")
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

// TODO: V2 - To be removed
extension Memory {
  static let dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    return dateFormatter
  }()
  @available(*, deprecated, message: "Use directoryName instead.")
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
  @available(*, deprecated, message: "Use directoryURL instead.")
  public var memoryDirectoryURL: URL {
    URL.memoryDirectory.appending(path: memoryDirectoryName, directoryHint: .isDirectory)
  }
}

extension URL {
  public static let imagesDirectory: URL = documentsDirectory.appendingPathComponent("Images", isDirectory: true)
  public static let memoryDirectory: URL = documentsDirectory.appendingPathComponent("Memories", isDirectory: true)
}

extension String {
  public var sanitizedForFolderName: String {
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
