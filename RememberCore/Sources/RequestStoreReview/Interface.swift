import Dependencies
import DependenciesMacros

@DependencyClient
public struct RequestStoreReview: Sendable {
  @DependencyEndpoint
  public var request: @Sendable () async -> Void
  public func callAsFunction() async {
    await request()
  }
}

extension DependencyValues {
  public var storeReview: RequestStoreReview {
    get { self[RequestStoreReview.self] }
    set { self[RequestStoreReview.self] = newValue }
  }
}

// MARK: - TestKey

extension RequestStoreReview: TestDependencyKey {
  public static let testValue = Self()
}
