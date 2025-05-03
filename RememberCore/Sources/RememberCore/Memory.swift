import SwiftUI
import ComposableArchitecture

public struct Memory: Sendable, Equatable, Identifiable {
  public let id: String
  public let created: Date
  public var modified: Date
  public var items: IdentifiedArrayOf<MemoryItem>
  public var tags: IdentifiedArrayOf<MemoryTag>
  public var location: MemoryLocation?
  public var isNew: Bool {
    (items.isEmpty && location == nil && tags.isEmpty) ||
    (items.count == 1 && location == nil && tags.isEmpty && items[0].name.isEmpty)
  }
  public init(
    id: String = UUID().uuidString,
    created: Date = Date(),
    modified: Date = Date(),
    items: Array<MemoryItem> = [],
    tags: Array<MemoryTag> = [],
    location: MemoryLocation? = nil
  ) {
    self.id = id
    self.created = created
    self.modified = modified
    self.items = items.identified
    self.tags = tags.identified
    self.location = location
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
