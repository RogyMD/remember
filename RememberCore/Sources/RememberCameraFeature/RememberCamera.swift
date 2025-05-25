import ComposableArchitecture
import RememberCore
import SwiftUI
import CameraView
import MemoryListFeature
import MemoryFormFeature
import DatabaseClient
import SearchMemoryFeature
import LocationClient
import PhotosUI

public struct CapturedImage: Equatable, Identifiable, Sendable {
  public var id: Int { image.hashValue }
  let image: UIImage
  let point: CGPoint
  let location: MemoryLocation?
  let caption: String?
  let created: Date?
  init(image: UIImage, point: CGPoint, location: MemoryLocation? = nil, caption: String? = nil, created: Date? = nil) {
    self.image = image
    self.point = point
    self.location = location
    self.caption = caption
    self.created = created
  }
  
  func previewImageAndPoint() async -> (UIImage, CGPoint) {
    let cropped = await image.croppedToScreen() ?? UIImage()
    let screenSize = await MainActor.run {
      UIScreen.main.bounds.size
    }
    return (cropped, point.convertPoint(from: image.size, to: .init(origin: .zero, size: screenSize)))
  }
}

@Reducer
public struct RememberCamera {
  @ObservableState
  public struct State: Equatable {
    var memoryForm: MemoryForm.State?
    @Presents public var searchMemory: SearchMemory.State?
    var memoryList: MemoryList.State?
    var pickedItem: PhotosPickerItem? = nil
    
    public init(memoryForm: MemoryForm.State? = nil, memoryList: MemoryList.State? = nil) {
      self.memoryForm = memoryForm
      self.memoryList = memoryList
    }
    //        public init() {
    //            self.ini
    //        }
  }
  
  @CasePathable
  public enum Action: Equatable, BindableAction {
    //  public enum Action: Equatable {
    case binding(BindingAction<State>)
    case capturedImage(CapturedImage)
    case memoryForm(MemoryForm.Action)
    case createMemory(Memory, UIImage)
    case memoryList(MemoryList.Action)
    case searchMemory(PresentationAction<SearchMemory.Action>)
    case listButtonTapped
    case swipeDown
  }
  
  @Dependency(\.uuid) var uuid
  @Dependency(\.database) var database
  @Dependency(\.date.now) var now
  
  public init() {}
  
  public var body: some ReducerOf<Self> {
    BindingReducer()
    
    Reduce {
      state,
      action in
      switch action {
      case .binding(\.pickedItem):
        guard let item = state.pickedItem else { return .none }
        state.pickedItem = nil
        return .run { send in
          if let data = try? await item.loadTransferable(type: Data.self),
             let uiImage = UIImage(data: data) {
            let point = CGPoint(x: uiImage.size.width / 2, y: uiImage.size.height / 2)
            let metadata = extractMetadata(from: data)
            await send(
              .capturedImage(
                .init(
                  image: uiImage,
                  point: point,
                  location: metadata.location,
                  caption: metadata.caption,
                  created: metadata.created
                )
              )
            )
          }
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
          try await database.updateOrInsertMemory(memory)
        }
      case .memoryForm(.cancelButtonTapped):
        state.memoryForm = nil
        return .none
      case .memoryForm(.forgetButtonTapped):
        let memoryId = state.memoryForm?.memory.id
        state.memoryForm = nil
        return .run { [database] _ in
          guard let memoryId else { return }
          try await database.deleteMemory(memoryId)
        }
      case .memoryList(.closeButtonTapped):
        return .send(.searchMemory(.dismiss))
      case .capturedImage(let image):
        return .run { [database, uuid, now] send in
          let (croppedImage, point) = await image.previewImageAndPoint()
          let memory = Memory(
            id: uuid().uuidString,
            created: image.created ?? now,
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
      case .createMemory(let memory, let previewImage):
        state.memoryForm = .init(
          memory: memory,
          isNew: true,
          previewImage: .init(uiImage: previewImage)
        )
        return .none
      case .memoryForm,
          .memoryList,
          .searchMemory,
          .binding:
        return .none
      }
    }
    .ifLet(\.memoryForm, action: \.memoryForm) {
      MemoryForm()
    }
    .ifLet(\.$searchMemory, action: \.searchMemory) {
      SearchMemory()
    }
    .ifLet(\.memoryList, action: \.memoryList) {
      MemoryList()
    }
    ////    ._printChanges()
  }
  
  //  private func <#action#>Action(_ action: Action.<#Action#>, state: inout State) -> EffectOf<Self> {
  //    switch action {
  //    case .<#action#>:
  //      return .none
  //    }
  //  }
}


// MARK: - RememberCameraView

public struct RememberCameraView: View {
  @Bindable var store: StoreOf<RememberCamera>
  @Namespace var list
  
  @State private var isPhotosPresented: Bool = false
  
  public init(store: StoreOf<RememberCamera>) {
    self.store = store
  }
  
  public var body: some View {
    NavigationStack {
      IfLetStore(store.scope(state: \.memoryForm, action: \.memoryForm)) { store in
        MemoryFormView(store: store)
      } else: {
        Group(content: {
#if targetEnvironment(simulator)
          VStack {
            Spacer()
            Button("Remember") {
              store.send(.capturedImage(.init(image: UIImage(systemName: "star")!, point: .zero)))
            }
            Spacer()
          }
#else
          CameraView { image, point in
            store.send(.capturedImage(.init(image: image, point: point)))
          }
#endif
        })
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              isPhotosPresented = true
            } label: {
              Image(systemName: "photo.on.rectangle.angled")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(10)
                .background(.thinMaterial)
                .clipShape(Circle())
                .frame(width: 44, height: 44, alignment: .center)
            }
            .foregroundStyle(.primary)
            .accessibilityLabel("Photos Library")
          }
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
            .accessibilityLabel("Memories Library")
          }
        }
        .photosPicker(
          isPresented: $isPhotosPresented,
          selection: $store.pickedItem,
          matching: .images
        )
      }
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
  }
}

//extension RememberCameraView {
//  var a11yID: A11yID { .ids }
//  struct A11yID {
//    static let ids = A11yID()
//    let main: String
//    <#let cancelButton: String#>
//    <#let function: (String) -> String#>
//    in
//  }
//}

import ImageIO
import CoreLocation

func extractMetadata(from imageData: Data) -> (location: MemoryLocation?, caption: String?, created: Date?) {
  guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
        let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
    return (nil, nil, nil)
  }
  
  var location: MemoryLocation? = nil
  var caption: String? = nil
  var created: Date?
  
  // GPS Metadata
  if let gps = metadata[kCGImagePropertyGPSDictionary] as? [CFString: Any],
     let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
     let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
     let longitude = gps[kCGImagePropertyGPSLongitude] as? Double,
     let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef] as? String {
    
    let lat = latitudeRef == "S" ? -latitude : latitude
    let lon = longitudeRef == "W" ? -longitude : longitude
    location = MemoryLocation(lat: lat, long: lon)
  }
  
  // Caption/Description Metadata
  if let tiff = metadata[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
     let imageDescription = tiff[kCGImagePropertyTIFFImageDescription] as? String {
    caption = imageDescription
  } else if let exif = metadata[kCGImagePropertyExifDictionary] as? [CFString: Any],
            let userComment = exif[kCGImagePropertyExifUserComment] as? String {
    caption = userComment
  }
  
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
  formatter.timeZone = TimeZone.current
  
  if let exif = metadata[kCGImagePropertyExifDictionary] as? [CFString: Any],
     let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
    created = formatter.date(from: dateString)
  } else if let tiff = metadata[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
            let dateString = tiff[kCGImagePropertyTIFFDateTime] as? String {
    created = formatter.date(from: dateString)
  }
  
  return (location, caption, created)
}

#if DEBUG

// MARK: Previews

public extension RememberCamera.State {
  @MainActor
  static let preview = Self()
}

#Preview {
  RememberCameraView(
    store: Store(
      initialState: .preview,
      reducer: { RememberCamera() }
    )
  )
}

#endif
