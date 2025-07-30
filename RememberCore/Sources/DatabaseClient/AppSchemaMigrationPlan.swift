import SwiftData
enum AppSchemaMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] {
    [
      SchemaV1.self,
      SchemaV2.self,
      SchemaV3.self,
    ]
  }
  
  static var stages: [MigrationStage] {
    []
  }
}
