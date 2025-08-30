/*
import AppIntents
import ComposableArchitecture
import RememberCore

enum CaptureMode: String, AppEnum, Sendable {
  case photo

  static var typeDisplayRepresentation: TypeDisplayRepresentation { .init(name: "Capture Mode") }
  static var caseDisplayRepresentations: [CaptureMode: DisplayRepresentation] {
    [
      .photo: .init(stringLiteral: "Photo"),
    ]
  }
}

enum CameraDevice: String, AppEnum, Sendable {
  case back

  static var typeDisplayRepresentation: TypeDisplayRepresentation { .init(name: "Camera Device") }
  static var caseDisplayRepresentations: [CameraDevice: DisplayRepresentation] {
    [
      .back: .init(stringLiteral: "Back"),
    ]
  }
}

struct HippoCamAppContext: Codable {
  
}

//@AssistantIntent(schema: .camera.startCapture)
struct CameraCaptureImageIntent: CameraCaptureIntent {
  typealias AppContext = HippoCamAppContext
  static var title: LocalizedStringResource = "Capture Memory"
  static var description = IntentDescription("Capture a photo and send it to HippoCam.")
  static var openAppWhenRun: Bool = true
  static var isDiscoverable: Bool = true
  
  let store = MainApp.mainStore

//  @Parameter
//  var captureMode: CaptureMode = CaptureMode.photo
//
//  @Parameter
//  var device: CameraDevice = CameraDevice.back
//
//  @Parameter(title: "Timer Duration")
//  var timerDuration: Measurement<UnitDuration>? = Measurement<UnitDuration>(value: .zero, unit: .seconds)

  @MainActor
  func perform() async throws -> some IntentResult {
    // Convert timer to seconds if provided
//    let seconds: Double? = timerDuration?.converted(to: .seconds).value

    // Send an app-intent action to your TCA store (implement this action in your reducer)
//    store.send(.startCameraCaptureIntent(captureMode: captureMode, device: device, timerSeconds: seconds))
    store.send(.)
    return .result()
  }
}
*/
