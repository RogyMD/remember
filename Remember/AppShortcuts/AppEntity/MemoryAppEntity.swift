import AppIntents
import DatabaseClient
import RememberCore
import Dependencies
import DependenciesMacros

public struct MemoryAppEntity: AppEntity {
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
      )
    )
  }
  
  public static var typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: LocalizedStringResource("Memory"))
  public static var defaultQuery = MemoryQuery()
}

extension MemoryAppEntity {
  public struct MemoryQuery: EntityStringQuery {
    public init() {}
    public func entities(for identifiers: [MemoryAppEntity.ID]) async throws -> [MemoryAppEntity] {
      let ids = Set(identifiers)
      return try await MemoryDataSource.allMemories().filter({ ids.contains($0.id) })
    }
    public func entities(matching string: String) async throws -> [MemoryAppEntity] {
      try await MemoryDataSource.searchMemories(string)
    }
    public func suggestedEntities() async throws -> [MemoryAppEntity] {
      try await MemoryDataSource.suggestedMemories()
    }
  }
}

enum MemoryDataSource {
  @Dependency(\.database) static var database
  static func allMemories() async throws -> [MemoryAppEntity] {
    try await database.fetchMemories()
      .filter({ $0.isPrivate == false })
      .map(MemoryAppEntity.init)
  }
  static func searchMemories(_ text: String) async throws -> [MemoryAppEntity] {
    try await database.searchMemories(text)
      .filter({ $0.isPrivate == false })
      .map(MemoryAppEntity.init)
  }
  static func suggestedMemories() async throws -> [MemoryAppEntity] {
    try await database.fetchMemories()
      .filter({ $0.isPrivate == false })
      .prefix(20)
      .map(MemoryAppEntity.init)
  }
}

extension MemoryAppEntity {
  init(memory: Memory) {
    self.init(
      id: memory.id,
      title: memory.displayTitle.nonEmpty ?? "Memory",
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
