import ComposableArchitecture
import RememberCore
import SwiftUI

@Reducer
public struct Example {
  @ObservableState
  public struct State: Equatable {
    var <#attribute#>
//    @Presents var <#attribute#>: <#State#>?
    
    //        public init() {
    //            self.ini
    //        }
  }
  
  @CasePathable
//  public enum Action: Equatable, BindableAction {
  public enum Action: Equatable {
//    case binding(BindingAction<State>)
    case <#action#>
  }
  
  @Dependency(\.<#dependency#>) var <#dependency#>
  
  public init() {}
  
  public func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .<#action#>:
      return .none
    }
  }
  
  //  public var body: some ReducerOf<Self> {
  //    BindingReducer()
  //    Reduce { state, action in
  //      switch action {
  //      case .<#action#>:
  //        return .none
  //      case .binding:
  //        return .none
  //      }
  //    }
  //  }
  
//  private func <#action#>Action(_ action: Action.<#Action#>, state: inout State) -> EffectOf<Self> {
//    switch action {
//    case .<#action#>:
//      return .none
//    }
//  }
}


// MARK: - ExampleView

public struct ExampleView: View {
  @Bindable var store: StoreOf<Example>
  
  public init(store: StoreOf<Example>) {
    self.store = store
  }
  
  public var body: some View {
    <#body#>
  }
}

//extension ExampleView {
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
    category: "Example"
)

#if DEBUG

// MARK: Previews

public extension Example.State {
  @MainActor
  static let preview = Self()
}

#Preview {
  ExampleView(
    store: Store(
      initialState: .preview,
      reducer: { Example() }
    )
  )
}

#endif
