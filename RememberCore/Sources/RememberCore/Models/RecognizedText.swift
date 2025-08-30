import Foundation

public struct RecognizedText: Equatable, Sendable {
  public var id: String
  public var text: String
  public var textFrames: [TextFrame]
  public init(id: String, text: String, textFrames: [TextFrame]) {
    self.id = id
    self.text = text
    self.textFrames = textFrames
  }
  public var isEmpty: Bool {
    textFrames.isEmpty
  }
}
