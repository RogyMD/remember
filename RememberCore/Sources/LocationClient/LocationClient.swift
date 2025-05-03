import Dependencies
import DependenciesMacros

@DependencyClient
public struct LocationClient: Sendable {
  @DependencyEndpoint
  public var authorizationStatus: @Sendable (Bool) async -> Bool = { _ in false }
  @DependencyEndpoint
  public var requestCurrentLocation: @Sendable () async throws -> LocationCoordinates = { .zero }
}

extension DependencyValues {
  public var locationClient: LocationClient {
    get { self[LocationClient.self] }
    set { self[LocationClient.self] = newValue }
  }
}

extension LocationClient: TestDependencyKey {
  public static let testValue = Self()
}

// MARK: - Live

extension LocationClient: DependencyKey {
  static let manager = LocationManager()
  public static let liveValue: Self = Self(
    authorizationStatus: { request in
      await manager.authorizationStatus(request: request).isAuthorized
    },
    requestCurrentLocation: {
      try await manager.requestCurrentLocation()
    })
}
