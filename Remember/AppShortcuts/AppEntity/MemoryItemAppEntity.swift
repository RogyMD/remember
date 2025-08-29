import AppIntents
import DatabaseClient
import RememberCore
import Dependencies
//import CoreLocation
@preconcurrency import CoreSpotlight

//@AssistantEntity(schema: .photos.asset)
public struct MemoryItemAppEntity: IndexedEntity {
  public let id: String
  public let memoryID: String
  
  @Property(title: "Title")
  public var title: String?
  
  public let subtitle: String
  public let contentDescription: String
  public var keywords: [String]
  public let thumbnailURL: URL
  public let previewImageURL: URL
  public let textContent: String?
  public var hideInSpotlight: Bool = false // TODO: return if it's private
  
  var creationDate: Date?
//  var location: CLPlacemark?
//  var assetType: AssetType?
//  var isFavorite: Bool
//  var isHidden: Bool
//  var hasSuggestedEdits: Bool
  
  public var attributeSet: CSSearchableItemAttributeSet {
    let set = CSSearchableItemAttributeSet(contentType: .png)
    set.identifier = id
    set.title = title
    set.keywords = keywords
    set.contentCreationDate = creationDate
    set.contentDescription = contentDescription
    set.thumbnailURL = thumbnailURL
    set.textContent = textContent
    return set
  }
  
  public var displayRepresentation: DisplayRepresentation {
    .init(
      title: .init(stringLiteral: title ?? subtitle),
      subtitle: .init(stringLiteral: subtitle),
      image: .init(
        url: thumbnailURL,
        isTemplate: false
      ),
      synonyms: [
        "the \(title ?? subtitle)",
        "my \(title ?? subtitle)",
      ]
    )
  }
  
  public static var typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: LocalizedStringResource("Memorised Item"))
  public static var defaultQuery = MemoryItemQuery()
}

//@AssistantEnum(schema: .photos.assetType)
//enum AssetType: String, AppEnum {
//    case photo
//    case video
//
//    static let caseDisplayRepresentations: [AssetType: DisplayRepresentation] = [
//        .photo: "Photo",
//        .video: "Video"
//    ]
//}

import CoreTransferable

extension MemoryItemAppEntity: Transferable {
  public static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .png) { item in
        .init(item.previewImageURL, allowAccessingOriginalFile: true)
    }
    DataRepresentation(exportedContentType: .png) { item in
        try Data(contentsOf: item.previewImageURL)
    }
  }
}

extension MemoryItemAppEntity {
  public struct MemoryItemQuery: EntityStringQuery {
    public init() {}
    public func entities(for identifiers: [MemoryItemAppEntity.ID]) async throws -> [MemoryItemAppEntity] {
      let ids = Set(identifiers)
      return try await MemoryItemDataSource.allItems().filter({ ids.contains($0.id) })
    }
    public func entities(matching string: String) async throws -> [MemoryItemAppEntity] {
      try await MemoryItemDataSource.searchItems(string)
    }
    public func suggestedEntities() async throws -> [MemoryItemAppEntity] {
      try await MemoryItemDataSource.suggestedItems()
    }
  }
}

enum MemoryItemDataSource {
  @Dependency(\.database) static var database
  static func allItems() async throws -> [MemoryItemAppEntity] {
    try await database.fetchMemories()
      .filter({ $0.isPrivate == false })
      .flatMap({ memory in
        memory
          .items
          .filter({ $0.name.trimmingCharacters(in: .whitespaces).isEmpty == false })
          .map({ MemoryItemAppEntity(memory: memory, item: $0) })
      })
  }
  static func searchItems(_ text: String) async throws -> [MemoryItemAppEntity] {
    try await database.searchMemoriesWithItems(text)
      .filter({ $0.isPrivate == false })
      .flatMap({ memory in
        memory
          .items
          .filter({ $0.name.localizedStandardContains(text) })
          .map({ MemoryItemAppEntity(memory: memory, item: $0) })
      })
  }
  static func suggestedItems() async throws -> [MemoryItemAppEntity] {
    try await Array(database.fetchMemories()
      .filter({ $0.isPrivate == false })
      .prefix(10)
      .flatMap({ memory in
        memory
          .items
          .filter({ $0.name.trimmingCharacters(in: .whitespaces).isEmpty == false })
          .map({ MemoryItemAppEntity(memory: memory, item: $0) })
      })
      .prefix(15))
  }
}

extension MemoryItemAppEntity {
  init(memory: Memory, item: MemoryItem) {
    self.init(
      id: item.id,
      memoryID: memory.id,
      subtitle: memory.subtitle,
      contentDescription: memory.notes,
      keywords: memory.tags.map(\.label),
      thumbnailURL: memory.thumbnailImageURL,
      previewImageURL: memory.previewImageURL,
      textContent: memory.recognizedText?.text
    )
    self.title = item.name
    self.creationDate = memory.created
//    self.assetType = .photo
  }
}

extension Memory {
  var subtitle: String {
    notes.nonEmpty ?? tags.nonEmpty?.sorted(using: SortDescriptor(\.label)).map({ "#" + $0.label }).joined(separator: " ") ?? created.formatted(date: .abbreviated, time: .shortened)
  }
}

