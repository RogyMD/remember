import Foundation

public struct MemoryLocation: Sendable, Equatable {
  public let lat: Double
  public let long: Double
  public init(lat: Double, long: Double) {
    self.lat = lat
    self.long = long
  }
}
