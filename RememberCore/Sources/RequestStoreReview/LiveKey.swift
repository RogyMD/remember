import Dependencies
import StoreKit

extension RequestStoreReview: DependencyKey {
  public static let liveValue = Self {
#if !DEBUG && canImport(UIKit.UIApplication)
    guard let scene = await UIApplication.shared.keyWindowScene else {
      assertionFailure("Can't find key window.")
      return
    }
    SKStoreReviewController.requestReview(in: scene)
#endif
  }
}
