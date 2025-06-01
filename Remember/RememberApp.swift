import SwiftUI
import HomeFeature
import ComposableArchitecture
import DatabaseClient

@main
struct RememberApp: App {
  @Bindable var store: StoreOf<Home> = Store(
    initialState: Home.State()
  ) {
    Home()
  }
  @Dependency(\.database) var database
  
  var body: some Scene {
    WindowGroup {
      HomeView(store: store)
        .task {
          await database.configure()
        }
    }
  }
}
