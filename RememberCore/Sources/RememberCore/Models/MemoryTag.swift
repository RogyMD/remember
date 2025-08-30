import Foundation

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
