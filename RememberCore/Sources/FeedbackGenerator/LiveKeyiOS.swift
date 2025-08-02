#if os(iOS)
import Dependencies
import UIKit

extension FeedbackGenerator: DependencyKey {
  public static let liveValue = Self { @MainActor feedback in
    let uiFeedbackGenerator: UIFeedbackGenerator =
    switch feedback {
    case .selection: UISelectionFeedbackGenerator()
    case .notification: UINotificationFeedbackGenerator()
    case .impact(let style, _): UIImpactFeedbackGenerator(style: .init(style))
    }
      return Generator(feedback: feedback, generator: uiFeedbackGenerator)
  }
}

// MARK: -
struct Generator: GeneratorProtocol {
  let feedback: FeedbackGenerator.Feedback
  let generator: UIFeedbackGenerator
  init(
    feedback: FeedbackGenerator.Feedback,
    generator: UIFeedbackGenerator,
    prepare: Bool = true
  ) {
    self.feedback = feedback
    self.generator = generator
    if prepare {
      Task { [self] in
        await self.prepare()
      }
    }
  }
  func prepare() async {
    await generator.prepare()
  }
  func run() async {
    await MainActor.run {
      switch feedback {
      case .selection:
        (generator as? UISelectionFeedbackGenerator)?.selectionChanged()
      case .notification(let type):
        (generator as? UINotificationFeedbackGenerator)?.notificationOccurred(.init(type))
      case .impact(_, let intensity):
        (generator as? UIImpactFeedbackGenerator)?.impactOccurred(intensity: intensity)
      }
    }
  }
}

extension UINotificationFeedbackGenerator.FeedbackType {
  init(_ type: FeedbackGenerator.Feedback.NotificationFeedbackType) {
    switch type {
    case .success:
      self = .success
    case .warning:
      self = .warning
    case .error:
      self = .error
    }
  }
}

extension UIImpactFeedbackGenerator.FeedbackStyle {
  init(_ style: FeedbackGenerator.Feedback.ImpactFeedbackStyle) {
    switch style {
    case .light:
      self = .light
    case .medium:
      self = .medium
    case .heavy:
      self = .heavy
    case .soft:
      self = .soft
    case .rigid:
      self = .rigid
    }
  }
}

#endif

enum EmptyGenerator: GeneratorProtocol {
  case generator
  func prepare() {}
  func run() {}
}
