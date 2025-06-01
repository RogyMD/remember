import Dependencies
import DependenciesMacros
import RememberCore
import UIKit
import FileClient

@DependencyClient
public struct DatabaseClient: Sendable {
  @DependencyEndpoint
  public var configure: @Sendable () async -> Void
  @DependencyEndpoint
  public var hasMemories: @Sendable () async throws -> Bool
  @DependencyEndpoint
  public var fetchMemories: @Sendable () async throws -> [Memory]
  @DependencyEndpoint
  public var searchMemories: @Sendable (String) async throws -> [Memory]
  @DependencyEndpoint
  public var searchMemoriesByTags: @Sendable (String) async throws -> [Memory]
  @DependencyEndpoint
  public var fetchTags: @Sendable () async throws -> [MemoryTag]
  @DependencyEndpoint
  public var insertTag: @Sendable (MemoryTag) async throws -> Void
  @DependencyEndpoint
  public var updateMemory: @Sendable (Memory) async throws -> Void
  @DependencyEndpoint
  public var saveMemory: @Sendable (Memory, UIImage, UIImage) async throws -> Void
  @DependencyEndpoint
  public var updateItem: @Sendable (MemoryItem) async throws -> Void
  @DependencyEndpoint
  public var deleteMemory: @Sendable (String) async throws -> Void
  @DependencyEndpoint
  public var deleteItem: @Sendable (String) async throws -> Void
  @DependencyEndpoint
  public var removeAllData: @Sendable () async throws -> Void
  @DependencyEndpoint
  public var sync: @Sendable () async throws -> SyncResult
}

extension DatabaseClient {
  public struct SyncResult {
    public let invalidMemories: Set<Memory.ID>
    public let orphanDirectories: Set<URL>
  }
}

extension DependencyValues {
  public var database: DatabaseClient {
    get { self[DatabaseClient.self] }
    set { self[DatabaseClient.self] = newValue }
  }
}

extension DatabaseClient: TestDependencyKey {
  public static let testValue = Self()
}

// MARK: - Live

extension DatabaseClient: DependencyKey {
  public static let liveValue: DatabaseClient = {
    let database: @Sendable () -> DatabaseService = { DatabaseService.shared }
    @Dependency(\.fileClient) var fileClient
    return DatabaseClient(
      configure: {
        let service = database()
        await fileClient.migrateMemoriesToNewFileStructureIfNeeded({
          try await service.fetch(.memories, compactMap: Memory.init)
        })
      },
      hasMemories: {
        try await database().hasMemories()
      },
      fetchMemories: {
        try await database().fetch(.memories, compactMap: Memory.init)
      },
      searchMemories: { query in
        try await database().fetch(.search(query), compactMap: Memory.init)
      },
      searchMemoriesByTags: { term in
        try await database().fetch(.memories, compactMap: Memory.init)
      },
      fetchTags: {
        try await database().fetch(.tags, compactMap: MemoryTag.init)
      },
      insertTag: { tag in
        try await database().insertTag(tag)
      },
      updateMemory: { memory in
        guard let existingMemory = try await database().fetch(.memory(id: memory.id), compactMap: Memory.init).first else {
          return
        }
        try await database().updateOrInsertMemory(memory)
        let memoryFile = MemoryFile(memory: memory)
        let existingMemoryFile = MemoryFile(memory: existingMemory)
        if memoryFile != existingMemoryFile {
          let data = try MemoryFile.encoder.encode(memoryFile)
          fileClient.createFile(data, existingMemory.textFileURL, true)
        }
        let newMemoryDirectory = memory.memoryDirectoryURL
        let existingMemoryDirectory = existingMemory.memoryDirectoryURL
        if newMemoryDirectory != existingMemoryDirectory {
          try fileClient.moveItem(existingMemoryDirectory, newMemoryDirectory)
        }
        
      },
      saveMemory: { memory, image, previewImage in
        try await database().updateOrInsertMemory(memory)
        try await fileClient.saveMemory(memory, image: image, previewImage: previewImage)
      },
      updateItem: { item in
        try await database().updateItem(item)
      },
      deleteMemory: { id in
        guard let memory = try await database().fetch(.memory(id: id), compactMap: Memory.init).first else {
          return
        }
        try await database().deleteMemory(id: id)
        try fileClient.removeItem(memory.memoryDirectoryURL)
      },
      deleteItem: { id in
        try await database().deleteItem(id: id)
      },
      removeAllData: {
        try await database().removeAllData()
      },
      sync: {
        fatalError()
      }
    )
  }()
}

extension Memory {
  init(_ model: MemoryModel) {
    self.init(
      id: model.id,
      created: model.created,
      notes: model.notes,
      items: model.items
        .map(MemoryItem.init)
        .sorted(by: { $0.name < $1.name }),
      tags: model.tags.map(MemoryTag.init),
      location: model.location.map(MemoryLocation.init)
    )
  }
}

extension MemoryItem {
  init(_ model: ItemModel) {
    self.init(id: model.id, name: model.name, center: .init(x: model.center.x, y: model.center.y))
  }
}

extension MemoryLocation {
  init(_ model: LocationModel) {
    self.init(lat: model.latitude, long: model.longitude)
  }
}

extension MemoryTag {
  init(_ model: TagModel) {
    self.init(label: model.label)
  }
}
