import CoreLocation

actor LocationManager {
  let locationManager: CLLocationManager = CLLocationManager()
  private let delegate = LocationManagerDelegate()
  var authorizationStatus: CLAuthorizationStatus {
    locationManager.authorizationStatus
  }
  var location: CLLocation? {
    locationManager.location
  }
  
  init() {
    locationManager.delegate = delegate
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
  }
  
  func authorizationStatus(request: Bool) async -> CLAuthorizationStatus {
    guard request, authorizationStatus == .notDetermined else { return authorizationStatus }
    return await withCheckedContinuation { continuation in
      delegate.authorizationContinuation = continuation
      locationManager.requestWhenInUseAuthorization()
    }
  }
  
  func requestCurrentLocation() async throws -> LocationCoordinates {
    for try await update in CLLocationUpdate.liveUpdates(.default) {
      if let location = update.location.map({ LocationCoordinates(lat: $0.coordinate.latitude, long: $0.coordinate.longitude) }) {
        return location
      } else if update.authorizationDenied || update.authorizationRequestInProgress {
        break
      }
    }
    
      throw NSError(domain: "location manager", code: 0)
  }
}

final class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
  var locationContinuation: CheckedContinuation<LocationCoordinates, Error>?
  var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let location = locations.first {
      locationContinuation?.resume(returning: LocationCoordinates(lat: location.coordinate.latitude, long: location.coordinate.longitude))
      locationContinuation = nil
    }
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    locationContinuation?.resume(throwing: error)
    locationContinuation = nil
    authorizationContinuation?.resume(returning: manager.authorizationStatus)
    authorizationContinuation = nil
  }
  
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    authorizationContinuation?.resume(returning: manager.authorizationStatus)
    authorizationContinuation = nil
  }
}

extension CLAuthorizationStatus {
  var isAuthorized: Bool {
    switch self {
    case .notDetermined, .restricted, .denied:
      return false
    case .authorizedAlways,
        .authorizedWhenInUse,
        .authorized:
      return true
    @unknown default:
      return true
    }
  }
}
