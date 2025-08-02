import Dependencies
import DependenciesMacros
import UIKit
import XCTestDynamicOverlay

public protocol GeneratorProtocol: Sendable {
  func prepare() async
  func run() async
}

@DependencyClient
public struct FeedbackGenerator: Sendable {
  public enum Feedback: Sendable {
    public enum NotificationFeedbackType: Int, Sendable {
      case success = 0
      case warning = 1
      case error = 2
    }
    public enum ImpactFeedbackStyle : Int, Sendable {
        case light = 0
        case medium = 1
        case heavy = 2
        case soft = 3
        case rigid = 4
    }
    case selection
    case notification(NotificationFeedbackType)
    case impact(ImpactFeedbackStyle, CGFloat = 0.3)
    public static let buttonTap = impact(.soft, 0.5)
  }
  public var generate: @MainActor @Sendable (Feedback) -> GeneratorProtocol = { _ in EmptyGenerator.generator }
}

extension DependencyValues {
  public var feedbackGenerator: FeedbackGenerator {
    get { self[FeedbackGenerator.self] }
    set { self[FeedbackGenerator.self] = newValue }
  }
}

// MARK: - TestKey

extension FeedbackGenerator: TestDependencyKey {
  public static let previewValue = Self.noop
  public static let testValue = Self()
  
  public static let noop = Self()
}
