import SwiftUI
import RememberCameraFeature
import ComposableArchitecture

@main
struct RememberApp: App {
  @Bindable var store: StoreOf<RememberCamera> = Store(
    initialState: RememberCamera.State()
  ) {
    RememberCamera()
  }
  
  var body: some Scene {
    WindowGroup {
      RememberCameraView(store: store)
    }
  }
}
