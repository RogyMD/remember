public struct LocationCoordinates: Equatable, Sendable {
  public let lat: Double
  public let long: Double
  public init(lat: Double = .zero, long: Double = .zero) {
    self.lat = lat
    self.long = long
  }
  static let zero = LocationCoordinates()
}
