import Foundation
import SwiftData
import IssueReporting
import FileClient
import Dependencies

enum ModelError: LocalizedError {
  case setup(error: Error)
}
@discardableResult
func setupModelContainer(
  for versionedSchema: VersionedSchema.Type = SchemaLatest.self,
  migrationPlan: SchemaMigrationPlan.Type = AppSchemaMigrationPlan.self,
  url: URL,
  rollback: Bool = false
) throws -> ModelContainer {
  do {
    @Dependency(\.fileClient) var fileClient
    try fileClient.createDirectory(url.deletingLastPathComponent())
    let schema = Schema(versionedSchema: versionedSchema)
    let config: ModelConfiguration = .init(schema: schema, url: url)
    let container = try ModelContainer(
        for: schema,
        migrationPlan: migrationPlan,//rollback ? RollbackMigrationPlan.self : MigrationPlan.self,
        configurations: [config]
    )
    Logger.database.info("setup database -> \(String(describing: container))")
    return container
  } catch {
    throw ModelError.setup(error: error)
  }
}
extension ModelContainer {
  nonisolated(unsafe) public static var appModelContainer: ModelContainer = {
    do {
      moveDatabaseFilesIfNeeded()
      copyReadmeFile()
      Logger.database.info("SwiftData.storeURL: \(URL.storeURL.absoluteString)")
      return try setupModelContainer(url: URL.storeURL, rollback: false)
    } catch {
#if DEBUG
      fatalError("container failed to init. Error: \(error)")
#else
      removeDatabaseFiles()
      return try! setupModelContainer(url: URL.storeURL, rollback: false)
#endif
    }
  }()
  
  public static func removeDatabaseFiles() {
    @Dependency(\.fileClient) var fileClient
    let files = ["database.sqlite-wal", "database.sqlite-shm", "database.sqlite"]
    for file in files {
      let fileURL = URL.databaseDirectory.appending(path: file)
      do {
        try fileClient.removeItem(fileURL)
        Logger.database.info("Removed database at \(fileURL)")
      } catch {
        reportIssue(error)
      }
    }
  }
  
  public static func moveDatabaseFilesIfNeeded() {
    @Dependency(\.fileClient) var fileClient
    guard fileClient.itemExists(URL.deprected_storeURL) else { return }
    let files = ["database.sqlite-wal", "database.sqlite-shm", "database.sqlite"]
    for file in files {
      let fileURL = URL.documentsDirectory.appending(path: file)
      do {
        let newFileURL = URL.databaseDirectory.appendingPathComponent(file)
        try fileClient.moveItem(fileURL, newFileURL)
        Logger.database.info("Moved database to \(newFileURL)")
      } catch {
        reportIssue(error)
      }
    }
  }
  
  static func copyReadmeFile() {
    @Dependency(\.fileClient) var fileClient
    if let url = URL.readmeFile,
       fileClient.itemExists(url),
       fileClient.itemExists(.documentsDirectory.appending(component: url.lastPathComponent)) == false {
      do {
        try fileClient.copyItem(url, .documentsDirectory.appending(component: url.lastPathComponent))
      } catch {
        reportIssue(error)
      }
    }
  }
}

extension URL {
  public static let rememberConfig: URL = URL.memoryDirectory.appending(component: ".remember", directoryHint: .isDirectory)
  public static let databaseDirectory: URL = URL.rememberConfig.appending(component: "db", directoryHint: .isDirectory)
  public static let readmeFile: URL? = Bundle.module.url(forResource: "README", withExtension: "txt")
  
  public static let deprected_storeURL = URL.documentsDirectory.appending(path: "database.sqlite")
  public static let storeURL = URL.databaseDirectory.appending(path: "database.sqlite")
}

import OSLog

extension Logger {
  static let database = Logger(subsystem: "", category: "DatabaseService")
}
