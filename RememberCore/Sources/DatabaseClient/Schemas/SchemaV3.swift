import Foundation
@preconcurrency import SwiftData

public enum SchemaV3: VersionedSchema {
  public static let versionIdentifier: Schema.Version = .init(3, 0, 0)
  public static var models: [any PersistentModel.Type] {
    [
      MemoryModel.self,
      TagModel.self,
      LocationModel.self,
      ItemModel.self,
      TextFrameModel.self,
      RecognizedTextModel.self,
    ]
  }
  public struct Rect: Codable, Sendable {
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat
    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
      self.x = x
      self.y = y
      self.width = width
      self.height = height
    }
    public var cgRect: CGRect { .init(x: x, y: y, width: width, height: height) }
    public init(_ rect: CGRect) {
      self.init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
    }
    static let zero = Self(.zero)
  }
  @Model
  public final class TextFrameModel {
    public var text: String
    public var frame: Rect = Rect.zero
    init(text: String, frame: CGRect) {
      self.text = text
      self.frame = .init(frame)
    }
  }
  @Model
  public final class RecognizedTextModel {
    @Attribute(.unique) public var id: String
    public var text: String
    @Relationship(deleteRule: .cascade)
    public var textFrames: [TextFrameModel]
    init(
      id: String,
      text: String,
      textFrames: [TextFrameModel]
    ) {
      self.id = id
      self.text = text
      self.textFrames = textFrames
    }
  }
  @Model
  public final class MemoryModel {
    @Attribute(.unique) public var id: String
    public var created: Date
    public var modified: Date
    public var notes: String = ""
    public var isPrivate: Bool = false
    @Relationship(deleteRule: .cascade)
    public var items: [ItemModel]
    @Relationship(inverse: \TagModel.memories)
    public var tags: [TagModel]
    @Relationship(deleteRule: .cascade)
    public var location: LocationModel?
    @Relationship(deleteRule: .cascade)
    public var recognizedText: RecognizedTextModel?
    
    init(
      id: String,
      created: Date,
      modified: Date,
      notes: String = "",
      isPrivate: Bool,
      items: [ItemModel],
      tags: [TagModel],
      location: LocationModel?,
      recognizedText: RecognizedTextModel?
    ) {
      self.id = id
      self.created = created
      self.modified = modified
      self.notes = notes
      self.items = items
      self.tags = tags
      self.location = location
      self.recognizedText = recognizedText
    }
  }
  
  @Model
  public final class TagModel {
    @Attribute(.unique) public var label: String
    public var memories: [MemoryModel] = []
    
    init(label: String) {
      self.label = label
    }
  }
  
  @Model
  public final class LocationModel {
    public var latitude: Double
    public var longitude: Double
    init(latitude: Double, longitude: Double) {
      self.latitude = latitude
      self.longitude = longitude
    }
  }
  
  @Model
  public final class ItemModel {
    @Attribute(.unique) public var id: String
    public var created: Date
    public var modified: Date
    public var name: String
    public var center: Point
    public var memory: MemoryModel?
    
    init(
      id: String,
      created: Date = Date(),
      modified: Date? = nil,
      name: String,
      center: Point
    ) {
      self.id = id
      self.created = created
      self.modified = modified ?? created
      self.name = name
      self.center = center
    }
  }
  
  public struct Point: Codable, Equatable {
    let x: Double
    let y: Double
    public init(_ point: CGPoint) {
      self.x = point.x
      self.y = point.y
    }
  }
}
