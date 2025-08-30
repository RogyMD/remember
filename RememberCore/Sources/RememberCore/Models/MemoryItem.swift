import Foundation

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
