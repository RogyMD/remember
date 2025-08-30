import Foundation

public struct TextFrame: Equatable, Identifiable, Sendable, Hashable {
  public var id: Self { self }
  public var text: String
  public var frame: CGRect
  public init(text: String, frame: CGRect) {
    self.text = text
    self.frame = frame
  }
}
