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
  public var updateOrInsertMemory: @Sendable (Memory) async throws -> Void
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
      updateOrInsertMemory: { memory in
        try await database().updateOrInsertMemory(memory)
      },
      saveMemory: { memory, image, previewImage in
        try await database().updateOrInsertMemory(memory)
        try FileManager.default.saveImage(image, id: memory.id)
        try FileManager.default.saveImage(previewImage, id: memory.id + .previewSuffix)
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
          try FileManager.default.saveImage(thumbnailImage, id: memory.id + .thumbnailSuffix)
        } else {
          reportIssue("Couldn't generate thumbnail for image: \(previewImage)")
        }
      },
      updateItem: { item in
        try await database().updateItem(item)
      },
      deleteMemory: { id in
        try await database().deleteMemory(id: id)
        FileManager.default.deleteImages(id: id)
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

// TODO: Move to a Dependency
extension FileManager {
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
      items: model.items.map(MemoryItem.init),
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
