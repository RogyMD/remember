import Foundation
import Sharing
import IssueReporting

private extension String {
  static let lastReviewRequestTimeInterval = "lastReviewRequestTimeInterval"
}

//extension UserDefaults {
//  public static let live: UserDefaults = {
//    let userDefaults = UserDefaults.standard
//    userDefaults.register(defaults: [:
//      .isOnboardingEnabled: true,
//      .showsTimixGPTSuggestion: true,
//      .showsTimerDurationCameraInput: true,
//      .isRunningInBackgroundEnabled: true,
//      .isDuckOthersEnabled: true,
//    ])
//    return userDefaults
//  }()
//}

//public extension SharedKey where Self == AppStorageKey<Bool>.Default {
//  static var isOnboardingEnabled: Self {
//    Self[.appStorage(.isOnboardingEnabled, store: .live), default: true]
//  }
//}

public extension SharedKey where Self == AppStorageKey<TimeInterval>.Default {
  static var lastReviewRequestTimeInterval: Self {
    Self[.appStorage(.lastReviewRequestTimeInterval), default: .zero]
  }
}
