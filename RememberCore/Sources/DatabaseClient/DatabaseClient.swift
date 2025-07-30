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
  public var syncWithFileSystem: @Sendable () async throws -> SyncResult
}

extension DatabaseClient {
  public struct SyncResult {
    public var invalidMemories: Set<Memory.ID>
    public var orphanItems: Set<URL>
    init(invalidMemories: Set<Memory.ID> = [], orphanItems: Set<URL> = []) {
      self.invalidMemories = invalidMemories
      self.orphanItems = orphanItems
    }
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
      syncWithFileSystem: {
        var contentItems = Set(try fileClient.contentsOfDirectory(.memoryDirectory))
        contentItems.remove(URL.rememberConfig.lastPathComponent)
        var syncResult = SyncResult()
        var verifiedItems: Set<String> = []
        let memories = try await database().fetch(.memories, compactMap: Memory.init)
        for memory in memories {
          let memoryDirectoryURL = memory.memoryDirectoryURL
          let isValid = (
            fileClient.itemExists(memory.originalImageURL) &&
            fileClient.itemExists(memory.previewImageURL) &&
            fileClient.itemExists(memory.thumbnailImageURL) &&
            fileClient.itemExists(memory.textFileURL)
          )
          if isValid == false {
            syncResult.invalidMemories.insert(memory.id)
            if contentItems.contains(memoryDirectoryURL.lastPathComponent) {
              syncResult.orphanItems.insert(memoryDirectoryURL)
            }
          }
          verifiedItems.insert(memoryDirectoryURL.lastPathComponent)
         }
        
        let unverifiedItems = contentItems.subtracting(verifiedItems)
        for item in unverifiedItems {
          let url = URL.memoryDirectory.appendingPathComponent(item)
          if let memory = Memory.init(directoryURL: url) {
            try? await database().updateOrInsertMemory(memory)
          } else {
            syncResult.orphanItems.insert(url)
          }
        }
        return syncResult
      }
    )
  }()
}

extension Memory {
  static let expectedFiles: Set<String> = [
    "original.png",
    "preview.png",
    "thumbnail.png",
    "memory.txt",
  ]
  init?(directoryURL: URL) {
    @Dependency(\.fileClient) var fileClient
    guard let contents = (try? fileClient.contentsOfDirectory(directoryURL)).map(Set.init),
            contents.isSuperset(of: Self.expectedFiles) else {
      return nil
    }
    let memoryFileURL = directoryURL.appending(component: "memory.txt")
    do {
      let data = try Data(contentsOf: memoryFileURL)
      let memoryFile = try JSONDecoder().decode(MemoryFile.self, from: data)
      let created = MemoryFile.dateFormatter.date(from: memoryFile.created) ?? Date()
      self = .init(
        id: memoryFile.id,
        created: created,
        notes: memoryFile.notes ?? "",
        items: memoryFile.items?.map({ item in
          .init(name: item, center: .zero)
        }) ?? [],
        tags: memoryFile.tags?.map(MemoryTag.init) ?? [],
        location: memoryFile.location.flatMap({ location in
          guard let lat = location["latitude"], let long = location["longitude"] else {
            return nil
          }
          return .init(lat: lat, long: long)
        })
      )
    } catch {
      reportIssue(error)
      return nil
    }
  }
  
  init(_ model: MemoryModel) {
    self.init(
      id: model.id,
      created: model.created,
      notes: model.notes,
      isPrivate: model.isPrivate,
      items: model.items
        .map(MemoryItem.init)
        .sorted(by: { $0.name < $1.name }),
      recognizedItems: model.recognizedItems
        .map(MemoryItem.init)
        .sorted(by: { $0.name < $1.name }),
      tags: model.tags
        .map(MemoryTag.init)
        .sorted(by: { $0.label < $1.label }),
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
