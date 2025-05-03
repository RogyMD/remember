import Foundation
import SwiftData
import IssueReporting

enum ModelError: LocalizedError {
    case setup(error: Error)
}
@discardableResult
func setupModelContainer(
  for versionedSchema: VersionedSchema.Type = SchemaLatest.self,
  migrationPlan: SchemaMigrationPlan.Type = AppSchemaMigrationPlan.self,
  url: URL? = nil,
  rollback: Bool = false
) throws -> ModelContainer {
  do {
    let schema = Schema(versionedSchema: versionedSchema)
    let config: ModelConfiguration =
    if let url {
      .init(schema: schema, url: url)
    } else {
      .init(schema: schema)
    }
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
      Logger.database.info("SwiftData.storeURL: \(ModelConfiguration.storeURL.absoluteString)")
      return try setupModelContainer(url: ModelConfiguration.storeURL, rollback: false)
    } catch {
#if DEBUG
      fatalError("container failed to init. Error: \(error)")
#else
      removeDatabaseFiles()
      return try! setupModelContainer(url: ModelConfiguration.storeURL, rollback: false)
#endif
    }
  }()
  
  public static func removeDatabaseFiles() {
    let files = ["database.sqlite-wal", "database.sqlite-shm", "database.sqlite"]
    for file in files {
      let fileURL = URL.documentsDirectory.appending(path: file)
      do {
        try FileManager.default.removeItem(at: fileURL)
        Logger.database.info("Removed database at \(fileURL)")
      } catch {
          reportIssue(error)
      }
    }
  }
}

extension ModelConfiguration {
  public static let storeURL = URL.documentsDirectory.appending(path: "database.sqlite")
}

import OSLog

extension Logger {
  static let database = Logger(subsystem: "", category: "DatabaseService")
}
