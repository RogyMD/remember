import AppIntents
import DatabaseClient
import RememberCore
import Dependencies

public struct MemoryItemAppEntity: AppEntity {
  public let id: String
  public let title: String
  public let subtitle: String
  public let thumbnailURL: URL
  public var displayRepresentation: DisplayRepresentation {
    .init(
      title: .init(stringLiteral: title),
      subtitle: .init(stringLiteral: subtitle),
      image: .init(
        url: thumbnailURL,
        isTemplate: false
      ),
      synonyms: [
        "the \(title)",
        "my \(title)",
      ]
    )
  }
  
  public static var typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: LocalizedStringResource("Memorised Item"))
  public static var defaultQuery = MemoryItemQuery()
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
      .prefix(25))
  }
}

extension MemoryItemAppEntity {
  init(memory: Memory, item: MemoryItem) {
    self.init(
      id: item.id,
      title: item.name.nonEmpty ?? "Unnamed",
      subtitle: memory.subtitle,
      thumbnailURL: memory.thumbnailImageURL
    )
  }
}

extension Memory {
  var subtitle: String {
    notes.nonEmpty ?? tags.nonEmpty?.sorted(using: SortDescriptor(\.label)).map({ "#" + $0.label }).joined(separator: " ") ?? created.formatted(date: .abbreviated, time: .shortened)
  }
}

