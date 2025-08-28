import ComposableArchitecture
import RememberCore
import SwiftUI
import HomeFeature
import DatabaseClient
import MemoryFormFeature
import OSLog

@Reducer
public struct MainAppReducer {
  @ObservableState
  public struct State: Equatable {
    var home: Home.State = .init()
//    @Presents var <#attribute#>: <#State#>?
    
    //        public init() {
    //            self.ini
    //        }
  }
  
  @CasePathable
  public enum Action: Equatable, BindableAction {
//  public enum Action: Equatable {
    case binding(BindingAction<State>)
    case home(Home.Action)
    case openMemory(Memory.ID)
    case startApp
  }
  
  @Dependency(\.database) var database
  
  public init() {}
  
    public var body: some ReducerOf<Self> {
      Scope(state: \.home, action: \.home) {
        Home()
      }
      
      Reduce { state, action in
        switch action {
        case .openMemory(let id):
          return .run { send in
            guard let memory = try await database.fetchMemory(id) else {
              return reportIssue("Can't find memory with id: \(id)")
            }
            await send(.home(.createMemory(memory, memory.previewImage)))
          }
//        case .home(.):
//          return .none
        case .startApp:
          return .run { send in
            await database.configure()
          }
        case .home(.memoryList(.addMemory)),
            .home(.memoryForm(.doneButtonTapped)),
            .home(.memoryForm(.deleteConfirmationAlertButtonTapped)),
            .home(.memoryForm(.forgetButtonTapped)),
            .home(.memoryList(.memoryForm(.presented(.doneButtonTapped)))),
            .home(.memoryList(.memoryForm(.presented(.deleteConfirmationAlertButtonTapped)))),
            .home(.memoryList(.memoryForm(.presented(.forgetButtonTapped)))),
            .home(.memoryList(.deleteRows)):
          return .run { send in
            HippoCamAppShorcutsProvider.updateAppShortcutParameters()
          }
        case .home, .binding:
          return .none
        }
      }
    }
  
//  private func <#action#>Action(_ action: Action.<#Action#>, state: inout State) -> EffectOf<Self> {
//    switch action {
//    case .<#action#>:
//      return .none
//    }
//  }
}


// MARK: - MainAppView
@main
public struct MainApp: App {
  public static let mainStore = StoreOf<MainAppReducer>(initialState: MainAppReducer.State()) {
    MainAppReducer()
  }
  
  @Bindable var store: StoreOf<MainAppReducer>
  @Dependency(\.database) var database
  
  public init() {
    self.store = Self.mainStore
  }
  
  public var body: some Scene {
    WindowGroup {
      HomeView(store: store.scope(state: \.home, action: \.home))
        .task {
          store.send(.startApp)
        }
    }
  }
}

//extension MainAppView {
//  var a11yID: A11yID { .ids }
//  struct A11yID {
//    static let ids = A11yID()
//    let main: String
//    <#let cancelButton: String#>
//    <#let function: (String) -> String#>
//    in
//  }
//}

private let logger = Logger(
    subsystem: "Remember",
    category: "MainApp"
)

#if DEBUG

// MARK: Previews

public extension MainAppReducer.State {
  @MainActor
  static let preview = Self()
}

//#Preview {
//  MainApp(
//    store: Store(
//      initialState: .preview,
//      reducer: { MainAppReducer() }
//    )
//  )
//}

#endif
