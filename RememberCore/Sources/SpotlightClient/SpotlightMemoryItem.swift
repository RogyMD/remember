/*
import Foundation

public struct SpotlightMemoryItem: Sendable {
  public let id: String
  public let memoryID: String
  public var title: String?
  public let subtitle: String
  public let contentDescription: String
  public var keywords: [String]
  public let thumbnailURL: URL
  public let previewImageURL: URL
  public let textContent: String?
  public var creationDate: Date?
  /// Domain identifier to group items in Spotlight (useful for bulk deletes by domain in the future)
  public var domainIdentifier: String = "memory"

  public var attributeSet: CSSearchableItemAttributeSet {
    // Use PNG since your previews are PNG; adjust if needed.
    let set = CSSearchableItemAttributeSet(contentType: .png)
    set.title = title
    set.contentDescription = contentDescription
    set.keywords = keywords
    set.contentCreationDate = creationDate
    set.thumbnailURL = thumbnailURL
    set.textContent = textContent
    
    return set
  }

  public init(
    id: String,
    memoryID: String,
    title: String?,
    subtitle: String,
    contentDescription: String,
    keywords: [String],
    thumbnailURL: URL,
    previewImageURL: URL,
    textContent: String?,
    creationDate: Date?,
    domainIdentifier: String = "memory"
  ) {
    self.id = id
    self.memoryID = memoryID
    self.title = title
    self.subtitle = subtitle
    self.contentDescription = contentDescription
    self.keywords = keywords
    self.thumbnailURL = thumbnailURL
    self.previewImageURL = previewImageURL
    self.textContent = textContent
    self.creationDate = creationDate
    self.domainIdentifier = domainIdentifier
  }

  /// Convenience initializer to build a Spotlight item from your AppIntents entity.
  public init(_ entity: MemoryItemAppEntity) {
    self.init(
      id: entity.id,
      memoryID: entity.memoryID,
      title: entity.title,
      subtitle: entity.subtitle,
      contentDescription: entity.contentDescription,
      keywords: entity.keywords,
      thumbnailURL: entity.thumbnailURL,
      previewImageURL: entity.previewImageURL,
      textContent: entity.textContent,
      creationDate: entity.creationDate,
      domainIdentifier: "memory"
    )
  }
}
*/
