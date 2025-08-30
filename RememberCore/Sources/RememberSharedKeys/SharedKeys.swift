import Foundation
import Sharing
import IssueReporting

private extension String {
  static let isAutoTextDetectionEnabled = "isAutoTextDetectionEnabled"
  static let isTeaPurchased = "isTeaPurchased"
  static let isSpotlightIndexed = "isSpotlightIndexed"
}

extension UserDefaults {
  nonisolated(unsafe) static var isRegistered = false
  public static func live() -> UserDefaults {
    let userDefaults = UserDefaults.standard
    if isRegistered == false {
      isRegistered = true
      userDefaults.register(defaults: [
        .isAutoTextDetectionEnabled: true,
      ])
    }
    return userDefaults
  }
}


public extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var isAutoTextDetectionEnabled: Self {
    Self[.appStorage(.isAutoTextDetectionEnabled, store: .live()), default: true]
  }
  static var isTeaPurchased: Self {
    Self[.appStorage(.isTeaPurchased, store: .live()), default: false]
  }
  static var isSpotlightIndexed: Self {
    Self[.appStorage(.isSpotlightIndexed, store: .live()), default: false]
  }
}
