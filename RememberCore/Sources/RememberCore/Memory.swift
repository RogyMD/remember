import SwiftUI
import ComposableArchitecture

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
    (items.isEmpty && location == nil && tags.isEmpty) ||
    (items.count == 1 && location == nil && tags.isEmpty && items[0].name.isEmpty)
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
    recognizedText: RecognizedText? = nil
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

public struct MemoryLocation: Sendable, Equatable {
  public let lat: Double
  public let long: Double
  public init(lat: Double, long: Double) {
    self.lat = lat
    self.long = long
  }
}

public struct MemoryTag: Sendable, Equatable, Identifiable, Hashable, Comparable {
  public static func < (lhs: MemoryTag, rhs: MemoryTag) -> Bool {
    lhs.label < rhs.label
  }
  
  public var id: String { label }
  public let label: String
  public init(label: String) {
    self.label = label
  }
}

public struct MemoryItem: Sendable, Equatable, Identifiable {
  public let id: String
  public var name: String
  public let center: CGPoint
  public init(
    id: String = UUID().uuidString,
    name: String,
    center: CGPoint
  ) {
    self.id = id
    self.name = name
    self.center = center
  }
}

public struct TextFrame: Equatable, Identifiable, Sendable {
  public var id: CGRect { frame }
  public var text: String
  public var frame: CGRect
  public init(text: String, frame: CGRect) {
    self.text = text
    self.frame = frame
  }
}

public struct RecognizedText: Equatable, Sendable {
  public var text: String
  public var textFrames: [TextFrame]
  public init(text: String, textFrames: [TextFrame]) {
    self.text = text
    self.textFrames = textFrames
  }
}
