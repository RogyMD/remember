import ComposableArchitecture
import RememberCore
import RememberCameraFeature
import MemoryListFeature
import MemoryFormFeature
import DatabaseClient
import RequestStoreReview
import SharingKeys
import SearchMemoryFeature
import SwiftUI
import SettingsFormFeature

@Reducer
public struct Home {
  @ObservableState
  public struct State: Equatable {
    public var memoryForm: MemoryForm.State?
    var presentationDetent: PresentationDetent = .bottom
    public var searchMemory: SearchMemory.State
    @Presents public var settingsForm: SettingsForm.State?
    var memoryList: MemoryList.State
    var camera: RememberCamera.State = .init()
    
    public init(memoryForm: MemoryForm.State? = nil, memoryList: MemoryList.State? = nil) {
      self.memoryForm = memoryForm
      self.memoryList = .empty
      self.searchMemory = .init(isSearchPresented: false)
    }
  }
  
  @CasePathable
  public enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case memoryForm(MemoryForm.Action)
    case memoryList(MemoryList.Action)
    case camera(RememberCamera.Action)
    case searchMemory(SearchMemory.Action)
    case settingsForm(PresentationAction<SettingsForm.Action>)
    case createMemory(Memory, UIImage)
    case requestStoreReview
    case onOpenURL(URL)
  }
  
  @Dependency(\.uuid) var uuid
  @Dependency(\.database) var database
  @Dependency(\.date.now) var now
  
  public init() {}
  
  public var body: some ReducerOf<Self> {
    BindingReducer()
    
    Scope(state: \.camera, action: \.camera) {
      RememberCamera()
    }
    
    Scope(state: \.searchMemory, action: \.searchMemory) {
      SearchMemory()
    }
    
    Scope(state: \.memoryList, action: \.memoryList) {
      MemoryList()
    }
    
    Reduce { state, action in
      switch action {
      case .onOpenURL(let url):
        return .run { send in
          guard url.startAccessingSecurityScopedResource() else {
            return reportIssue("Can't access file on url: \(url)")
          }
          defer { url.stopAccessingSecurityScopedResource() }
          do {
            let data = try Data(contentsOf: url)
            await send(.camera(.importImage(data)))
          } catch {
            reportIssue(error)
          }
        }
      case .requestStoreReview:
        return .run { _ in
          try? await Self.requestReviewAsync()
        }
      case .memoryForm(.doneButtonTapped):
        let memory = state.memoryForm?.memory
        state.memoryForm = nil
        return .run { [database] send in
          guard let memory else { return }
          if memory.items.count > 1, memory.tags.isEmpty == false || memory.location != nil || memory.notes.isEmpty == false || memory.recognizedText?.isEmpty == false {
            await send(.requestStoreReview)
          }
          try await database.updateMemory(memory)
          await send(.memoryList(.updateMemory(memory)))
        }
      case .memoryForm(.cancelButtonTapped):
        state.memoryForm = nil
        return .none
      case .memoryForm(.forgetButtonTapped), .memoryForm(.deleteConfirmationAlertButtonTapped):
        guard let memoryId = state.memoryForm?.memory.id else { return .none }
        state.memoryForm = nil
        state.memoryList.remove(memoryId)
        return .run { [database] _ in
          try await database.deleteMemory(memoryId)
        }
      case .memoryList(.closeButtonTapped):
        state.presentationDetent = .bottom
        return .none
      case .createMemory(let memory, let previewImage):
        state.memoryForm = .init(
          memory: memory,
          isNew: memory.isNew,
          previewImage: .init(uiImage: previewImage)
        )
        return .none
      case .camera(.capturedImage(let image)):
        return .run { [database, uuid] send in
          let (croppedImage, point) = await image.previewImageAndPoint()
          let memory = Memory(
            id: uuid().uuidString,
            created: image.created,
            notes: image.caption ?? "",
            items: [
              .init(
                id: uuid().uuidString,
                name: "",
                center: point
              )
            ],
            tags: [],
            location: image.location
          )
          await send(.createMemory(memory, croppedImage))
          try await database.saveMemory(memory, image.image, croppedImage)
        }
      case .searchMemory(.resultMemoryTapped):
        return .send(.requestStoreReview)
      case .searchMemory(.binding(\.isSearchPresented)):
        guard state.searchMemory.isSearchPresented else { return .none }
        state.presentationDetent = .large
        return .none
      case .binding(\.presentationDetent):
        guard state.presentationDetent == .bottom else { return .none }
        state.searchMemory.isSearchPresented = false
        return .none
      case .camera(.settingsButtonTapped):
        state.settingsForm = .init()
        return .none
      case .memoryForm,
          .memoryList,
          .searchMemory,
          .camera,
          .settingsForm,
          .binding:
        return .none
      }
    }
    .ifLet(\.memoryForm, action: \.memoryForm) {
      MemoryForm()
    }
    .ifLet(\.$settingsForm, action: \.settingsForm) {
      SettingsForm()
    }
  }
  
  static func requestReviewAsync() async throws  {
    @Dependency(\.storeReview) var requestReview
    @Dependency(\.mainRunLoop) var mainRunLoop
    @Dependency(\.database) var database
    @Shared(.lastReviewRequestTimeInterval) var lastReviewRequestTimeInterval
    
    let hasRequestedReviewBefore = lastReviewRequestTimeInterval != .zero
    let timeSinceLastReviewRequest = mainRunLoop.now.date.timeIntervalSince1970 - lastReviewRequestTimeInterval
    let weekInSeconds: Double = 60 * 60 * 24 * 7
    
    let shouldRequestReview = try await database.hasMemories()
    
    if shouldRequestReview
        && (!hasRequestedReviewBefore || timeSinceLastReviewRequest >= weekInSeconds)
    {
      await requestReview()
      $lastReviewRequestTimeInterval.withLock {
        $0 = mainRunLoop.now.date.timeIntervalSince1970
      }
    }
  }
  
  //  private func memoryFormAction(_ action: MemoryForm.Action, state: inout State) -> EffectOf<Self> {
  //      switch action {
  //      case .<#action#>:
  //        return .none
  //      }
  //    }
}

extension CapturedImage {
  func previewImageAndPoint() async -> (UIImage, CGPoint) {
    let preview = await image.previewImage() ?? UIImage()
    return (preview, point)
  }
}

// MARK: - HomeView

public struct HomeView: View {
  @Bindable var store: StoreOf<Home>
  
  public init(store: StoreOf<Home>) {
    self.store = store
  }
  
  public var body: some View {
    NavigationStack {
      IfLetStore(store.scope(state: \.memoryForm, action: \.memoryForm)) { store in
        MemoryFormView(store: store)
      } else: {
        RememberCameraView(store: store.scope(state: \.camera, action: \.camera))
      }
    }
    .onOpenURL { url in
      store.send(.onOpenURL(url))
    }
    .sheet(isPresented: .constant(store.showsSearchBar)) {
      NavigationStack {
        if #available(iOS 26.0, *), #available(watchOS 26.0, *) {
          searchMemoryView
        } else {
          searchMemoryView
            .presentationBackground(.thinMaterial)
        }
      }
      .presentationDragIndicator(.visible)
      .interactiveDismissDisabled(true)
      .presentationBackgroundInteraction(.enabled)
      .presentationDetents(
        [.bottom, .large],
        selection: $store.presentationDetent
      )
      .sheet(item: $store.scope(state: \.settingsForm, action: \.settingsForm)) { store in
        NavigationStack {
          if #available(iOS 26.0, *), #available(watchOS 26.0, *) {
            SettingsFormView(store: store)
          } else {
            SettingsFormView(store: store)
              .presentationBackground(.thinMaterial)
          }
        }
      }
    }
  }
  
  var searchMemoryView: some View {
    SearchMemoryView(store: store.scope(state: \.searchMemory, action: \.searchMemory)) {
      MemoryListView(
        store: store.scope(
          state: \.memoryList,
          action: \.memoryList
        )
      )
      .when(store.presentationDetent == .large) {
        $0.toolbar(content: {
          ToolbarItem(placement: .topBarTrailing) {
            EditButton()
          }
          
          ToolbarItem(placement: .topBarLeading) {
            CancelButton(title: "Close") {
              store.send(.memoryList(.closeButtonTapped))
            }
          }
        })
      }
    }
  }
}

extension Home.State {
  var showsSearchBar: Bool {
    memoryForm == nil && camera.isFilesPresented == false
  }
}

extension PresentationDetent {
  static let bottom = PresentationDetent.height(78)
}

//extension HomeView {
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

public extension Home.State {
  @MainActor
  static let preview = Self()
}

#Preview {
  HomeView(
    store: Store(
      initialState: .preview,
      reducer: { Home() }
    )
  )
}

#endif
