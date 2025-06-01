import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct FileClient: Sendable {
  @DependencyEndpoint
  public var createDirectory: @Sendable (URL) throws -> Void
  @DependencyEndpoint
  public var createFile: @Sendable (Data?, URL, Bool) -> Void
  @DependencyEndpoint
  public var moveItem: @Sendable (URL, URL) throws -> Void
  @DependencyEndpoint
  public var removeItem: @Sendable (URL) throws -> Void
  @DependencyEndpoint
  public var itemExists: @Sendable (URL) -> Bool = { _ in false }
  @DependencyEndpoint
  public var contentsOfDirectory: @Sendable (URL) throws -> [String]
}

extension DependencyValues {
  public var fileClient: FileClient {
    get { self[FileClient.self] }
    set { self[FileClient.self] = newValue }
  }
}

extension FileClient: TestDependencyKey {
  public static let testValue = Self()
}

// MARK: - Live

extension FileClient: DependencyKey {
  public static let liveValue: Self = {
    let fileManager: @Sendable () -> FileManager = { FileManager.default }
    return Self(
      createDirectory: { url in
        try fileManager().createDirectories(to: url)
      },
      createFile: { data, url, override in
        if override && fileManager().fileExists(atPath: url.path()) {
          try? fileManager().removeItem(at: url)
        }
        try? fileManager().createDirectories(to: url.deletingLastPathComponent())
        fileManager().createFile(atPath: url.path(), contents: data)
      },
      moveItem: { source, destination in
        try fileManager().createDirectories(to: destination.deletingLastPathComponent())
        try fileManager().moveItem(at: source, to: destination)
      },
      removeItem: {
        try fileManager().removeItem(at: $0)
      },
      itemExists: {
        fileManager().fileExists(atPath: $0.path())
      },
      contentsOfDirectory: {
        try fileManager().contentsOfDirectory(atPath: $0.path())
      }
    )
  }()
}

extension FileManager {
  func createDirectories(to targetPath: URL) throws {
    var directory = targetPath
    var missingDirectories: [String] = []
    while fileExists(atPath: directory.path()) == false {
      missingDirectories.append(directory.lastPathComponent)
      directory = directory.deletingLastPathComponent()
    }
    missingDirectories.reverse()
    while directory != targetPath, missingDirectories.isEmpty == false {
      let path = missingDirectories.removeFirst()
      directory = directory.appending(path: path)
      try createDirectory(at: directory, withIntermediateDirectories: true)
    }
  }
}
