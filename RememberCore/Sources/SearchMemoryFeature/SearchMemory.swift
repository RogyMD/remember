import ComposableArchitecture
import RememberCore
import SwiftUI
import MemoryListFeature
import DatabaseClient

@Reducer
public struct SearchMemory {
  @ObservableState
  public struct State: Equatable {
    public var resultsList: MemoryList.State?
    public var isSearchPresented = false
    var query: String = ""
    var isLoading = false

    public init(
      resultsList: MemoryList.State? = nil,
      isSearchPresented: Bool = false,
      query: String = "",
      isLoading: Bool = false
    ) {
      self.resultsList = resultsList
      self.isSearchPresented = isSearchPresented
      self.query = query
      self.isLoading = isLoading
    }
  }
  
  @CasePathable
  public enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case resultsList(MemoryList.Action)
    case resultMemoryTapped(String)
    case updateSearchResults([Memory])
  }
  
  @Dependency(\.database) var database
  @Dependency(\.continuousClock) var continuousClock
  
  public init() {}
  enum SearchRequestID { case id }
    public var body: some ReducerOf<Self> {
      BindingReducer()
      Reduce { state, action in
        switch action {
        case .updateSearchResults(let results):
          state.resultsList = results
            .nonEmpty
            .map({ MemoryList.State(memories: $0, isDataLoaded: true, allowsDelete: false) })
          return .none
        case .binding(\.query):
          state.isLoading = true
          let trimmedQuery = state.query.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
          return .run { [continuousClock, database] send in
            try await continuousClock.sleep(for: .seconds(0.1))
            if let trimmedQuery {
              let results = try await database.searchMemories(trimmedQuery)
              await send(.updateSearchResults(results))
//              let resultsCount = templates.count
//              let announcement = resultsCount == 0 ? Localized.noSearchResults : Localized.searchResultsHeaderTitle.format(resultsCount)
//              await UIAccessibility.post(notification: .announcement, argument: announcement)
            } else {
              await send(.updateSearchResults([]))
            }
            await send(.binding(.set(\.isLoading, false)))
          }
          .cancellable(id: SearchRequestID.id, cancelInFlight: true)
        case .resultsList(let action):
          return resultsListAction(action, state: &state)
        case .binding:
          return .none
        case .resultMemoryTapped(_):
          return.none
        }
      }
      .ifLet(\.resultsList, action: \.resultsList) {
        MemoryList()
      }
    }
  
  private func resultsListAction(_ action: MemoryList.Action, state: inout State) -> EffectOf<Self> {
    return .none
//    switch action {
//    case .memoryForm(_):
//      <#code#>
//    case .memoryTapped(_):
//      <#code#>
//    case .closeButtonTapped:
//      <#code#>
//    case .settingsButtonTapped:
//      <#code#>
//    case .deleteRows(_, _):
//      <#code#>
//    case .addMemory(_):
//      <#code#>
//    case .loadDataIfNeeded:
//      <#code#>
//    case .updateMemories(_):
//      <#code#>
//    }
  }
}


// MARK: - SearchMemoryView

public struct SearchMemoryView<Content>: View where Content: View {
  @Bindable var store: StoreOf<SearchMemory>
  let content: () -> Content
  public init(
    store: StoreOf<SearchMemory>,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.store = store
    self.content = content
  }
  
  public var body: some View {
    IfLetStore(store.scope(state: \.resultsList, action: \.resultsList)) { store in
      Text("Found \(store.memories.count) memories")
        .font(.subheadline)
        .padding(.top)
        .foregroundStyle(.secondary)
        .accessibilityAddTraits(.isHeader)
      MemoryListView(store: store)
    } else: {
      if store.isSearchPresented, store.query.isEmpty == false {
        if store.isLoading {
          ProgressView()
            .progressViewStyle(.circular)
        } else {
          Text("No results for '\(store.query)'")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical)
            .accessibilityAddTraits(.isHeader)
        }
      }
      content()
    }
    .searchable(
      text: $store.query,
      isPresented: $store.isSearchPresented,
      prompt: "Search items, tags or notes"
    )
  }
}

//extension SearchMemoryView {
//  var a11yID: A11yID { .ids }
//  struct A11yID {
//    static let ids = A11yID()
//    let main: String
//    <#let cancelButton: String#>
//    <#let function: (String) -> String#>
//    in
//  }
//}

#if DEBUG

// MARK: Previews

public extension SearchMemory.State {
  @MainActor
  static let preview = Self()
}

#Preview {
  SearchMemoryView(
    store: Store(
      initialState: .preview,
      reducer: { SearchMemory() }
    )) {
      List {
        Text("I'm a row")
      }
    }
}

#endif
