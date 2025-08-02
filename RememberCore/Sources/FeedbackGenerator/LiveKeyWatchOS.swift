#if os(watchOS)
import Dependencies
import WatchKit

extension FeedbackGenerator: DependencyKey {
  public static let liveValue = Self { @MainActor feedback in
    return Generator(feedback: feedback, interface: .current())
  }
}

// MARK: -
struct Generator: GeneratorProtocol {
  let feedback: FeedbackGenerator.Feedback
  let interface: WKInterfaceDevice
  init(feedback: FeedbackGenerator.Feedback, interface: WKInterfaceDevice) {
    self.feedback = feedback
    self.interface = interface
  }
  func prepare() {}
  func run() {
    switch feedback {
    case .selection:
      interface.play(.click)
    case .notification(let notificationFeedbackType):
      switch notificationFeedbackType {
      case .success:
        interface.play(.success)
      case .warning:
        interface.play(.notification)
      case .error:
        interface.play(.failure)
      }
    case .impact(let impactFeedbackStyle, _):
      switch impactFeedbackStyle {
      case .light:
        interface.play(.start)
      case .medium:
        interface.play(.retry)
      case .heavy:
        interface.play(.stop)
      case .soft:
        interface.play(.directionUp)
      case .rigid:
        interface.play(.directionDown)
      }
    }
  }
}
#endif
