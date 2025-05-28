import Dependencies
import StoreKit

extension RequestStoreReview: DependencyKey {
  public static let liveValue = Self {
#if canImport(UIKit.UIApplication)
    guard let scene = await UIApplication.shared.keyWindowScene else {
      assertionFailure("Can't find key window.")
      return
    }
#if !DEBUG
    await AppStore.requestReview(in: scene)
#else
    _ = scene
#endif
#endif
  }
}

#if canImport(UIKit.UIApplication)
extension UIApplication {
  public var keyWindowScene: UIWindowScene? {
    connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first(where: { scene in scene.windows.contains(where: \.isKeyWindow) })
  }
  public var topViewController: UIViewController? {
    keyWindowScene?.keyWindow?.rootViewController
  }
}
#endif
