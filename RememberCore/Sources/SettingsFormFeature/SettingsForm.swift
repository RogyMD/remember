import ComposableArchitecture
import RememberCore
import SwiftUI
import DatabaseClient
import FileClient
import BuyMeTeaFeature

@Reducer
public struct SettingsForm {
  @ObservableState
  public struct State: Equatable {
    var syncResult: DatabaseClient.SyncResult?
    var isSyncing: Bool = false
    var buyMeTea: BuyMeTea.State = .init()
    public init() {}
  }
  
  @CasePathable
  public enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case buyMeTea(BuyMeTea.Action)
    case writeReviewRowTapped
    case learnMoreRowTapped
    case closeButtonTapped
    case appSettingsTapped
    case syncButtonTapped
    case syncFinished(DatabaseClient.SyncResult)
    case syncResultAlertClearButtonTapped
  }
  
  @Dependency(\.openURL) var openURL
  @Dependency(\.dismiss) var dismiss
  @Dependency(\.database) var database
  @Dependency(\.fileClient) var fileClient
  
  public init() {}
  
  
  
  public var body: some ReducerOf<Self> {
    BindingReducer()
    
    Scope(state: \.buyMeTea, action: \.buyMeTea) {
      BuyMeTea()
    }
    
    Reduce { state, action in
      switch action {
      case .writeReviewRowTapped:
        return .none
      case .learnMoreRowTapped:
        return .none
      case .appSettingsTapped:
        return .none
      case .closeButtonTapped:
        return .run { [dismiss] _ in await dismiss() }
      case .syncButtonTapped:
        state.isSyncing = true
        return .run { [database] send in
          let result = try await database.syncWithFileSystem()
          await send(.syncFinished(result))
        }
      case .syncFinished(let result):
        state.syncResult = result
        state.isSyncing = false
        return .none
      case .syncResultAlertClearButtonTapped:
        guard let result = state.syncResult else { return .none }
        state.syncResult = nil
        return .run { [fileClient, database] send in
          for orphan in result.orphanItems {
            try fileClient.removeItem(orphan)
          }
          for memoryId in result.invalidMemories {
            try await database.deleteMemory(memoryId)
          }
        }
      case .binding, .buyMeTea:
        return .none
      }
    }
  }
}


// MARK: - SettingsFormView

public struct SettingsFormView: View {
  @Bindable var store: StoreOf<SettingsForm>
  
  public init(store: StoreOf<SettingsForm>) {
    self.store = store
  }
  
  public var body: some View {
    Form {
      if store.displayBuyMeTeaOnTop {
        Section("Support the App") {
          BuyMeTeaView(store: store.scope(state: \.buyMeTea, action: \.buyMeTea))
            .padding(8)
            .listRowBackground(Color.clear.background(.thinMaterial))
        }
      }
      
      Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
        Label("Open HippoCam Settings", systemImage: "gear")
      }
      .listRowBackground(Color.clear.background(.thinMaterial))
      
      Section("Data") {
        Button {
          store.send(.syncButtonTapped, animation: .linear)
        } label: {
          Label("Sync File System", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
        }
        .listRowBackground(Color.clear.background(.thinMaterial))
        .disabled(store.isSyncing)
      }
      
      Section {
        Link(destination: AppConfig.helpURL) {
          Label("Get Started", systemImage: "graduationcap.fill")
            .foregroundStyle(Color(uiColor: .systemGreen))
        }
        
        Link(destination: AppConfig.writeReviewURL) {
          Label("Write a Review", systemImage: "star.fill")
            .foregroundStyle(Color(uiColor: .systemTeal))
        }
        
        ShareLink(
          item: AppConfig.appStoreURL,
          subject: Text("Download HippoCam on the App Store"),
          message: Text("Here’s the link to download HippoCam, the app I was telling you about!")
        ) {
          Label("Spread the Word", systemImage: "megaphone.fill")
            .symbolRenderingMode(.multicolor)
        }
        
        Link(destination: AppConfig.homeURL) {
          Label("About", systemImage: "info.circle.fill")
            .foregroundStyle(Color(uiColor: .label))
        }
      } header: {
        Text("🫶 Thank You for Using HippoCam")
      } footer: {
#if BETA
        Text("You're using HippoCam Beta")
#else
        EmptyView()
#endif
      }
      .listRowBackground(Color.clear.background(.thinMaterial))
      
      if store.displayBuyMeTeaOnBottom {
        Section(store.isLoadingTea ? "Loading" : "Tea Purchased") {
          BuyMeTeaView(
            store: store.scope(state: \.buyMeTea, action: \.buyMeTea)
          )
          .listRowBackground(Color.clear.background(.thinMaterial))
        }
      }
    }
    .alert(
      item: $store.syncResult,
      title: { _ in
        Text("Sync Report")
      },
      actions: { result in
        if result.orphanItems.isEmpty == false || result.invalidMemories.isEmpty == false {
          Button("Remove", role: .destructive) {
            store.send(.syncResultAlertClearButtonTapped)
          }
        }
      },
      message: { result in
        Text(result.reportMessage)
      })
    .scrollContentBackground(.hidden)
    .navigationTitle("Settings")
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        CancelButton(title: "Close") {
          store.send(.closeButtonTapped)
        }
      }
    }
  }
}

extension SettingsForm.State {
  var displayBuyMeTeaOnTop: Bool {
    buyMeTea.isPurchased == false && buyMeTea.taskState.is(\.product)
  }
  var displayBuyMeTeaOnBottom: Bool {
    buyMeTea.isPurchased || buyMeTea.taskState == .loading
  }
  var isLoadingTea: Bool {
    buyMeTea.taskState == .loading && buyMeTea.isPurchased == false
  }
}

extension DatabaseClient.SyncResult {
  var reportMessage: String {
    if orphanItems.isEmpty && invalidMemories.isEmpty {
      "All clear now"
    } else {
      "- \(invalidMemories.count) Invalid Memories\n- \(orphanItems.count) Invalid Memories Files\nDo you want to remove invalid memory files?"
    }
  }
}

#if DEBUG

// MARK: Previews

public extension SettingsForm.State {
  @MainActor
  static let preview = Self()
}

#Preview {
  NavigationStack {
    SettingsFormView(
      store: Store(
        initialState: .preview,
        reducer: { SettingsForm() }
      )
    )
  }
}

#endif
