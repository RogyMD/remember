import ComposableArchitecture
import _AppIntents_SwiftUI
import RememberCore
import SwiftUI
import HomeFeature
import DatabaseClient
import MemoryFormFeature
import OSLog
import SpotlightClient
import CoreSpotlight
import SharingKeys
import Sharing

@Reducer
public struct MainAppReducer {
  @ObservableState
  public struct State: Equatable {
    var home: Home.State = .init()
    @Shared(.isSpotlightIndexed) var isSpotlightIndexed
    @Shared(.isSiriTipHidden) var isSiriTipHidden
    var isSiriTipVisible: Bool = false
    var siriTipMemory: Memory?
  }
  
  @CasePathable
  public enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case home(Home.Action)
    case openMemory(Memory.ID)
    case openMemoryWithItem(MemoryItem.ID)
    case onContinueSearchableItemAction(NSUserActivity)
    case createMemory(Data)
    case startApp
  }
  
  @Dependency(\.database) var database
  @Dependency(\.spotlightClient) var spotlight
  
  public init() {}
  
    public var body: some ReducerOf<Self> {
      BindingReducer()
      
      Scope(state: \.home, action: \.home) {
        Home()
      }
      
      // TODO: Move to a separate AppIntentReducer
      Reduce { state, action in
        switch action {
        case .createMemory(let data):
          state.home.searchMemory = nil
          state.home.settingsForm = nil
          return .send(.home(.camera(.importImage(data))))
        case .openMemory(let id):
          return .run { send in
            guard let memory = try await database.fetchMemory(id) else {
              return reportIssue("Can't find memory with id: \(id)")
            }
            await send(.home(.createMemory(memory, memory.previewImage)))
          }
        case .openMemoryWithItem(let id):
          state.home.searchMemory = nil
          state.home.settingsForm = nil
          return .run { send in
            guard let memory = try await database.fetchMemoryWithItem(id) else {
              return reportIssue("Can't find memory with item id: \(id)")
            }
            await send(.home(.createMemory(memory, memory.previewImage)))
          }
        case .startApp:
          return .run { send in
            await database.configure()
#if DEBUG
            HippoCamAppShorcutsProvider.updateAppShortcutParameters()
#endif
          }
        case .home(.memoryList(.addMemory)),
            .home(.memoryList(.updateMemory)),
            .home(.memoryForm(.doneButtonTapped)),
            .home(.memoryForm(.deleteConfirmationAlertButtonTapped)),
            .home(.memoryForm(.forgetButtonTapped)),
            .home(.memoryList(.memoryForm(.presented(.doneButtonTapped)))),
            .home(.memoryList(.memoryForm(.presented(.deleteConfirmationAlertButtonTapped)))),
            .home(.memoryList(.memoryForm(.presented(.forgetButtonTapped)))),
            .home(.settingsForm(.presented(.syncFinished))),
            .home(.memoryList(.deleteRows)):
          return .run { send in
            HippoCamAppShorcutsProvider.updateAppShortcutParameters()
          }
        case .binding(\.isSiriTipVisible):
          let isSiriTipVisible = state.isSiriTipVisible
          guard state.isSiriTipHidden == false, isSiriTipVisible == false else { return .none }
          return .run { [isSiriTipHidden = state.$isSiriTipHidden] send in
            await send(.set(\.siriTipMemory, nil))
            isSiriTipHidden.withLock { $0 = true }
          }
        case .home, .onContinueSearchableItemAction, .binding:
          return .none
        }
      }
      
      // TODO: Move to a separate SpotlightReducer
      Reduce { state, action in
        switch action {
        case .home(.memoryList(.addMemory(let memory))), .home(.memoryList(.updateMemory(let memory))):
          return .run { [spotlight, isSiriTipHidden = state.isSiriTipHidden, siriTipMemory = state.siriTipMemory] send in
            guard let searchableItems = memory.searchableItems else { return }
            try await spotlight.upsert(searchableItems)
            
            guard isSiriTipHidden == false, memory.isPrivate == false, siriTipMemory == nil else { return }
            await send(.set(\.siriTipMemory, memory))
            await send(.set(\.isSiriTipVisible, true))
          }
        case .home(.memoryList(.deletedMemories(let ids))):
          return .run { [spotlight] _ in
            try await spotlight.remove(ids)
          }
        case .onContinueSearchableItemAction(let activity):
          guard activity.activityType == CSSearchableItemActionType,
                let itemID = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return .none }
          return .send(.openMemoryWithItem(itemID))
        case .startApp:
          guard state.isSpotlightIndexed == false else { return .none }
          return .run { [database, spotlight, isSpotlightIndexed = state.$isSpotlightIndexed] send in
            isSpotlightIndexed.withLock({ $0 = true })
            HippoCamAppShorcutsProvider.updateAppShortcutParameters()
            let searchableItems = try await database.fetchMemories()
              .compactMap(\.searchableItems)
              .flatMap({ $0 })
            try await spotlight.upsert(searchableItems)
          }
        case .home, .openMemory, .openMemoryWithItem, .createMemory, .binding:
          return .none
        }
      }
    }
}

extension Memory {
  var searchableItems: [CSSearchableItemAttributeSet]? {
    guard isPrivate == false else { return nil }
    return items
      .filter({ $0.name.trimmingCharacters(in: .whitespaces).isEmpty == false })
      .nonEmpty?
      .map { item in
        MemoryItemAppEntity(memory: self, item: item).attributeSet
    }
  }
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
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
          store.send(.onContinueSearchableItemAction(activity))
        }
      
      if let siriTipAppIntent = store.siriTipAppIntent {
        SiriTipView(intent: siriTipAppIntent, isVisible: $store.isSiriTipVisible)
          .siriTipViewStyle(.automatic)
          .scenePadding()
          .transition(.move(edge: .bottom).animation(.bouncy))
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

extension MainAppReducer.State {
  var siriTipAppIntent: OpenMemoryItemAppIntent? {
    guard isSiriTipHidden == false, let siriTipMemory else { return nil }
    return siriTipMemory.items.first?.appIntent(memory: siriTipMemory)
  }
}

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
