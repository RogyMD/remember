import SwiftData
enum AppSchemaMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] {
    [
      SchemaV1.self,
    ]
  }
  
  static var stages: [MigrationStage] {
    []
  }
}
