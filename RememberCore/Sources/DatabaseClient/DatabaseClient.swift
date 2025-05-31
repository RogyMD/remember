import Dependencies
import DependenciesMacros
import RememberCore
import UIKit
import IssueReporting

@DependencyClient
public struct DatabaseClient: Sendable {
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
    return DatabaseClient(
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
          try? FileManager.default.removeItem(at: existingMemory.textFileURL)
          let data = try MemoryFile.encoder.encode(memoryFile)
          FileManager.default.createFile(atPath: existingMemory.textFileURL.path(), contents: data)
        }
        let newMemoryDirectory = memory.memoryDirectoryURL
        let existingMemoryDirectory = existingMemory.memoryDirectoryURL
        if newMemoryDirectory != existingMemoryDirectory {
          try FileManager.default.moveItem(at: existingMemoryDirectory, to: newMemoryDirectory)
        }
        
      },
      saveMemory: { memory, image, previewImage in
        try await database().updateOrInsertMemory(memory)
        try await FileManager.default.saveMemory(memory, image: image, previewImage: previewImage)
      },
      updateItem: { item in
        try await database().updateItem(item)
      },
      deleteMemory: { id in
        guard let memory = try await database().fetch(.memory(id: id), compactMap: Memory.init).first else {
          return
        }
        try await database().deleteMemory(id: id)
        try FileManager.default.removeItem(at: memory.memoryDirectoryURL)
      },
      deleteItem: { id in
        try await database().deleteItem(id: id)
      },
      removeAllData: {
        try await database().removeAllData()
      }
    )
  }()
}

struct MemoryFile: Equatable, Codable {
  var created: String
  var items: [String]?
  var tags: [String]?
  var location: [String: Double]?
  var notes: String?
  init(memory: Memory) {
    created = DateFormatter.localizedString(from: memory.created, dateStyle: .medium, timeStyle: .medium)
    items = memory.items.nonEmpty?.map(\.name)
    tags = memory.tags.nonEmpty?.map(\.label)
    notes = memory.notes.nonEmpty
    location = memory.location.map({ location in
      ["latitude": location.lat, "longitude": location.long]
    })
  }
  static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }()
}

// TODO: Move to a Dependency
extension FileManager {
  @discardableResult
  func saveMemory(_ memory: Memory, image: UIImage, previewImage: UIImage) async throws -> Bool {
    let memoryDirectoryURL = memory.memoryDirectoryURL
    if fileExists(atPath: URL.memoryDirectory.path()) == false {
      try createDirectory(at: URL.memoryDirectory, withIntermediateDirectories: true)
    }
    try createDirectory(at: memoryDirectoryURL, withIntermediateDirectories: true)
    let memoryFile = MemoryFile(memory: memory)
    let data = try MemoryFile.encoder.encode(memoryFile)
    guard createFile(atPath: memory.textFileURL.path(), contents: data) else {
      assertionFailure("Couldn't save json at \(memory.textFileURL)")
      return false
    }
    guard createFile(atPath: memory.originalImageURL.path(), contents: image.pngData()) else {
      assertionFailure("Couldn't save image at \(memory.originalImageURL)")
      return false
    }
    guard createFile(atPath: memory.previewImageURL.path(), contents: previewImage.pngData()) else {
      assertionFailure("Couldn't save image at \(memory.previewImage)")
      return false
    }
    let scale = await MainActor.run { UIScreen.main.scale }
    let thumbnailImageSize = CGSize(
      width: CGSize.thumbnailSize.width * scale,
      height: CGSize.thumbnailSize.height * scale
    )
    
    let aspectWidth = thumbnailImageSize.width / previewImage.size.width
    let aspectHeight = thumbnailImageSize.height / previewImage.size.height
    let aspectFillScale = max(aspectWidth, aspectHeight)

    let scaledSize = CGSize(
      width: previewImage.size.width * aspectFillScale,
      height: previewImage.size.height * aspectFillScale
    )
    
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
    let resizedImage = renderer.image { _ in
      previewImage.draw(in: CGRect(origin: .zero, size: scaledSize))
    }

    if let thumbnailImage = resizedImage.cgImage?
      .cropping(to: CGRect(
        origin: CGPoint(x: (scaledSize.width - thumbnailImageSize.width) / 2, y: (scaledSize.height - thumbnailImageSize.height) / 2),
        size: thumbnailImageSize))
        .map(UIImage.init) {
      guard createFile(atPath: memory.thumbnailImageURL.path(), contents: thumbnailImage.pngData()) else {
        assertionFailure("Couldn't save image at \(memory.previewImage)")
        return false
      }
      return true
    } else {
      reportIssue("Couldn't generate thumbnail for image: \(previewImage)")
      return false
    }
  }
  
  @discardableResult
  func saveImage(_ image: UIImage, id: String) throws -> Bool {
    if fileExists(atPath: URL.imagesDirectory.path(), isDirectory: nil) == false {
      try createDirectory(at: .imagesDirectory, withIntermediateDirectories: true)
    }
    let path = URL.imagesDirectory.appendingPathComponent(id).appendingPathExtension("png").path()
    return createFile(atPath: path, contents: image.pngData())
  }
  
  func deleteImages(id: String) {
    [
      id,
      (id + .thumbnailSuffix),
      (id + .previewSuffix)
    ].forEach { imageName in
      try? removeItem(
        at: URL.imagesDirectory
        .appendingPathComponent(imageName)
        .appendingPathExtension("png")
      )
    }
  }
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
