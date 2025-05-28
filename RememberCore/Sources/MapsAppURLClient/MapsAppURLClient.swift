import Dependencies
import DependenciesMacros

public struct MapsLocation: Sendable {
  let lat: Double
  let long: Double
  let name: String
  public init(lat: Double, long: Double, name: String?) {
    self.lat = lat
    self.long = long
    self.name = name ?? "Memory"
  }
}

@DependencyClient
public struct MapsAppURLClient: Sendable {
  @DependencyEndpoint
  public var openLocationInMaps: @Sendable (MapsLocation) async -> Void
}

extension DependencyValues {
  public var mapsApp: MapsAppURLClient {
    get { self[MapsAppURLClient.self] }
    set { self[MapsAppURLClient.self] = newValue }
  }
}

extension MapsAppURLClient: TestDependencyKey {
  public static let testValue = Self()
}

// MARK: - Live

import UIKit

extension MapsAppURLClient: DependencyKey {
  public static let liveValue: Self = MapsAppURLClient(
    openLocationInMaps: { location in
      let encodedName = location.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
         let coordinate = "\(location.lat),\(location.long)"
      let url = URL(string: "http://maps.apple.com/?ll=\(coordinate)&q=\(encodedName)")!

      let application = await UIApplication.shared

      guard application.canOpenURL(url) else {
        reportIssue("Can't open maps app url. Url: \(url)")
        return
      }
      await MainActor.run {
        application.open(url)
      }
    })
}
