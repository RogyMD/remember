import AppIntents
import DatabaseClient
import RememberCore
import Dependencies
import UniformTypeIdentifiers
@preconcurrency import CoreSpotlight

public struct MemoryItemAppEntity: IndexedEntity {
  public let id: String
  public let memoryID: String
  
  @Property
  public var title: String?
  
  public let subtitle: String
  public let contentDescription: String
  public var creationDate: Date?
  public var keywords: [String]
  public let thumbnailURL: URL
  public let previewImageURL: URL
  public let textContent: String?
  public var hideInSpotlight: Bool = false // TODO: return if it's private
  
  
  
  public var attributeSet: CSSearchableItemAttributeSet {
    let set = CSSearchableItemAttributeSet(contentType: .image)
    set.identifier = id
    set.title = title
    set.keywords = keywords
    set.contentCreationDate = creationDate
    set.contentDescription = contentDescription
    if let thumbnailData = try? Data(contentsOf: thumbnailURL) {
      set.thumbnailData = thumbnailData
    } else {
      set.thumbnailURL = thumbnailURL
    }
    set.textContent = textContent
    set.domainIdentifier = "item"
    return set
  }
 
  
  public var displayRepresentation: DisplayRepresentation {
    let image: DisplayRepresentation.Image? = {
      if let data = try? Data(contentsOf: thumbnailURL) {
        return .init(data: data)
      }
      return nil
    }()
    return .init(
      title: .init(stringLiteral: title ?? subtitle),
      subtitle: .init(stringLiteral: subtitle),
      image: image,
      synonyms: [
        "the \(title ?? subtitle)",
        "my \(title ?? subtitle)",
      ]
    )
  }
  
  public static var typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: LocalizedStringResource("Memorised Item"))
  public static var defaultQuery = MemoryItemQuery()
}

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
      .prefix(20)
      .flatMap({ memory in
        memory
          .items
          .filter({ $0.name.trimmingCharacters(in: .whitespaces).isEmpty == false })
          .map({ MemoryItemAppEntity(memory: memory, item: $0) })
      })
      .prefix(20))
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
  }
}



extension Memory {
  var subtitle: String {
    notes.nonEmpty ??
    tags.nonEmpty?.sorted(using: SortDescriptor(\.label)).map({ "#" + $0.label }).joined(separator: " ") ??
    created.formatted(date: .abbreviated, time: .shortened)
  }
}
