import SwiftUI
import HomeFeature
import ComposableArchitecture

@main
struct RememberApp: App {
  @Bindable var store: StoreOf<Home> = Store(
    initialState: Home.State()
  ) {
    Home()
  }
  
  var body: some Scene {
    WindowGroup {
      HomeView(store: store)
    }
  }
}
