import ComposableArchitecture
import Foundation

public struct Memory: Sendable, Equatable, Identifiable {
  public let id: String
  public let created: Date
  public var modified: Date
  public var notes: String
  public var isPrivate: Bool
  public var items: IdentifiedArrayOf<MemoryItem>
  public var tags: IdentifiedArrayOf<MemoryTag>
  public var location: MemoryLocation?
  public var recognizedText: RecognizedText?
  public var isNew: Bool {
    ((items.isEmpty && tags.isEmpty) ||
    (items.count == 1 && tags.isEmpty && items[0].name.isEmpty))
  }
  public init(
    id: String = UUID().uuidString,
    created: Date = Date(),
    modified: Date? = nil,
    notes: String = "",
    isPrivate: Bool = false,
    items: Array<MemoryItem> = [],
    tags: Array<MemoryTag> = [],
    location: MemoryLocation? = nil,
    recognizedText: RecognizedText? = nil,
  ) {
    self.id = id
    self.created = created
    self.modified = modified ?? created
    self.notes = notes
    self.isPrivate = isPrivate
    self.items = items.identified
    self.tags = tags.identified
    self.location = location
    self.recognizedText = recognizedText
  }
}
