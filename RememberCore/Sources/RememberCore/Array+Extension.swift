import ComposableArchitecture

public extension Array where Element: Identifiable {
  var identified: IdentifiedArrayOf<Element> {
    .init(uniqueElements: self)
  }
}
extension Array where Element == String {
  public mutating func removeLast(maxCapacity: Int) {
    removeLast(Swift.max((count - maxCapacity), 0))
  }
}

