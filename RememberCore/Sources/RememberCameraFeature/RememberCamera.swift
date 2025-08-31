import ComposableArchitecture
import RememberCore
import SwiftUI
import CameraView
import PhotosUI

public struct CapturedImage: Equatable, Identifiable, Sendable {
  public var id: Int { image.hashValue }
  public let image: UIImage
  public let point: CGPoint
  public let created: Date
  public let location: MemoryLocation?
  public let caption: String?
  
  init(image: UIImage, point: CGPoint, created: Date = Date(), location: MemoryLocation? = nil, caption: String? = nil) {
    self.image = image
    self.point = point
    self.location = location
    self.caption = caption
    self.created = created
  }
}

@Reducer
public struct RememberCamera {
  @ObservableState
  public struct State: Equatable {
    var pickedItem: PhotosPickerItem? = nil
    
    public init() {
    }
  }
  
  @CasePathable
  public enum Action: Equatable, BindableAction {
    //  public enum Action: Equatable {
    case binding(BindingAction<State>)
    case capturedImage(CapturedImage)
    case importImage(Data)
    case pickedFile(URL)
    case settingsButtonTapped
    case clipboardButtonTapped
  }
  
  @Dependency(\.date.now) var now
  
  public init() {}
  
  public var body: some ReducerOf<Self> {
    BindingReducer()
    
    Reduce {
      state,
      action in
      switch action {
      case .clipboardButtonTapped:
        return .run { send in
          guard let imageData = UIPasteboard.general.image?.pngData() else {
            return
          }
          await send(.importImage(imageData))
        }
      case .importImage(let data):
        return .run { [now] send in
          guard let uiImage = UIImage(data: data) else { return }
          let point = CGPoint(x: uiImage.size.width / 2, y: uiImage.size.height / 2)
          let metadata = extractMetadata(from: data)
          await send(
            .capturedImage(
              .init(
                image: uiImage,
                point: point,
                created: metadata.created ?? now,
                location: metadata.location,
                caption: metadata.caption
              )
            )
          )
        }
      case .pickedFile(let url):
        return .run { send in
          guard url.startAccessingSecurityScopedResource() else {
            reportIssue("Can't access file at: \(url)")
            return
          }
          defer {
            url.stopAccessingSecurityScopedResource()
          }
          let data = try Data(contentsOf: url)
          await send(.importImage(data))
        }
      case .binding(\.pickedItem):
        guard let item = state.pickedItem else { return .none }
        state.pickedItem = nil
        return .run { send in
          if let data = try await item.loadTransferable(type: Data.self) {
            await send(.importImage(data))
          }
        }
      case .binding, .capturedImage, .settingsButtonTapped:
        return .none
      }
    }
    ////    ._printChanges()
  }
}


// MARK: - RememberCameraView

public struct RememberCameraView: View {
  @Bindable var store: StoreOf<RememberCamera>
  @Namespace var list
  
  @State private var isPhotosPresented: Bool = false
  @State private var isFilesPresented: Bool = false
  
  public init(store: StoreOf<RememberCamera>) {
    self.store = store
  }
  
  public var body: some View {
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
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ignoresSafeArea()
    .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Menu {
          Button {
            isPhotosPresented = true
          } label: {
            Label("Photos", systemImage: "photo.on.rectangle.angled")
          }
          Button {
            isFilesPresented = true
          } label: {
            Label("Files", systemImage: "folder")
          }
          Button {
            store.send(.clipboardButtonTapped)
          } label: {
            Label("Get Pasteboard", systemImage: "clipboard")
          }
          Button {
            store.send(.settingsButtonTapped)
          } label: {
            Label("Settings", systemImage: "gear")
          }
        } label: {
          Image(systemName: "ellipsis")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(10)
            .frame(width: 44, height: 44, alignment: .center)
            .background(.thinMaterial)
            .clipShape(Circle())
        }
        .foregroundStyle(.primary)
      }
    }
    .photosPicker(
      isPresented: $isPhotosPresented,
      selection: $store.pickedItem,
      matching: .images
    )
    .fileImporter(isPresented: $isFilesPresented, allowedContentTypes: [.image]) { result in
      do {
        store.send(.pickedFile(try result.get()))
      } catch {
        reportIssue(error)
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
