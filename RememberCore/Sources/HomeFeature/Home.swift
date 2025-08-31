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
    @Presents public var searchMemory: SearchMemory.State?
    @Presents public var settingsForm: SettingsForm.State?
    var memoryList: MemoryList.State?
    var camera: RememberCamera.State = .init()
    
    public init(memoryForm: MemoryForm.State? = nil, memoryList: MemoryList.State? = nil) {
      self.memoryForm = memoryForm
      self.memoryList = memoryList
    }
  }
  
  @CasePathable
  public enum Action: Equatable {
    case memoryForm(MemoryForm.Action)
    case memoryList(MemoryList.Action)
    case camera(RememberCamera.Action)
    case searchMemory(PresentationAction<SearchMemory.Action>)
    case settingsForm(PresentationAction<SettingsForm.Action>)
    case createMemory(Memory, UIImage)
    case listButtonTapped
    case swipeDown
    case requestStoreReview
    case onOpenURL(URL)
  }
  
  @Dependency(\.uuid) var uuid
  @Dependency(\.database) var database
  @Dependency(\.date.now) var now
  
  public init() {}
  
  public var body: some ReducerOf<Self> {
    //      BindingReducer()
    Scope(state: \.camera, action: \.camera) {
      RememberCamera()
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
      case .listButtonTapped:
        state.memoryList = .empty
        state.searchMemory = .init()
        return .none
      case .swipeDown:
        state.memoryList = .empty
        state.searchMemory = .init(isSearchPresented: true)
        return .none
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
        let memoryId = state.memoryForm?.memory.id
        state.memoryForm = nil
        return .run { [database] _ in
          guard let memoryId else { return }
          try await database.deleteMemory(memoryId)
        }
      case .memoryList(.closeButtonTapped):
        return .send(.searchMemory(.dismiss))
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
      case .searchMemory(.presented(.resultMemoryTapped)):
        return .send(.requestStoreReview)
      case .camera(.settingsButtonTapped):
        state.settingsForm = .init()
        return .none
      case .memoryForm,
          .memoryList,
          .searchMemory,
          .camera,
          .settingsForm:
        return .none
      }
    }
    .ifLet(\.memoryForm, action: \.memoryForm) {
      MemoryForm()
    }
    .ifLet(\.$searchMemory, action: \.searchMemory) {
      SearchMemory()
    }
    .ifLet(\.$settingsForm, action: \.settingsForm) {
      SettingsForm()
    }
    .ifLet(\.memoryList, action: \.memoryList) {
      MemoryList()
    }
//    .ifLet(\.camera, action: \.camera) {
//      RememberCamera()
//    }
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
    let cropped = await image.croppedToScreen() ?? UIImage()
    let screenSize = await MainActor.run {
      UIScreen.main.bounds.size
    }
    return (cropped, point.convertPoint(from: image.size, to: .init(origin: .zero, size: screenSize)))
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
          .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
              .onEnded { value in
                if value.velocity.height < -500 {
                  store.send(.listButtonTapped)
                } else if value.velocity.height > 500 {
                  store.send(.swipeDown)
                }
              }
          )
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button {
                store.send(.listButtonTapped)
              } label: {
                Image(systemName: "photo.stack")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .padding(10)
                  .background(.thinMaterial)
                  .clipShape(Circle())
                  .frame(width: 44, height: 44, alignment: .center)
              }
              .foregroundStyle(.primary)
              .accessibilityLabel("HippoCam Library")
            }
          }
      }
    }
    .onOpenURL { url in
      store.send(.onOpenURL(url))
    }
    .sheet(store: store.scope(state: \.$searchMemory, action: \.searchMemory)) { store in
      NavigationStack {
        SearchMemoryView(store: store) {
          IfLetStore(self.store.scope(state: \.memoryList, action: \.memoryList)) { store in
            MemoryListView(store: store)
          } else: {
            EmptyView()
          }
        }
        .presentationBackground(.thinMaterial)
      }
    }
    .sheet(store: store.scope(state: \.$settingsForm, action: \.settingsForm)) { store in
      NavigationStack {
        SettingsFormView(store: store)
        .presentationBackground(.thinMaterial)
      }
    }
  }
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
