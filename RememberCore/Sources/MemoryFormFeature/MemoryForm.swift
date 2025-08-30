import ComposableArchitecture
import RememberCore
import SwiftUI
import MemoryItemPickerFeature
import CoreLocationUI
import MapKit
import LocationClient
import IssueReporting
import MemoryTagsPickerFeature
import MapsAppURLClient
import BuyMeTeaFeature

@Reducer
public struct MemoryForm: Sendable {
  @ObservableState
  public struct State: Equatable {
    public var memory: Memory
    public var isNew: Bool
    public var previewImage: Image
    public var memoryItemPicker: MemoryItemPicker.State?
    public var buyMeTea: BuyMeTea.State = .init()
    @Presents var tagsPicker: MemoryTagsPicker.State?
    var locationInProgress: Bool = false
    var isDeleteConfirmationAlertShown = false
    public init(memory: Memory, isNew: Bool, previewImage: Image? = nil, memoryItemPicker: MemoryItemPicker.State? = nil) {
      self.memory = memory
      self.isNew = isNew
      self.previewImage = previewImage ?? .init(uiImage: memory.previewImage)
      self.memoryItemPicker = memoryItemPicker
    }
    
    
    public init() {
      self.init(
        memory: .init(),
        isNew: true,
        previewImage: .init(systemName: "heart")
      )
    }
  }
  
  @CasePathable
  public enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case memoryItemPicker(MemoryItemPicker.Action)
    case tagsPicker(PresentationAction<MemoryTagsPicker.Action>)
    case buyMeTea(BuyMeTea.Action)
    case imageRowTapped
    case tagsRowTapped
    case locationRowTapped
    case receivedCurrentLocation(LocationCoordinates)
    case doneButtonTapped
    case cancelButtonTapped
    case forgetButtonTapped
    case shareButtonTapped
    case deleteButtonTapped
    case deleteConfirmationAlertButtonTapped
    case openInMapsButtonTapped
    case removeLocationButtonTapped
    case removeRecognizedTextButtonTapped
    case onAppear
  }
  
  public init() {}
  
  @Dependency(\.locationClient) var locationClient
  @Dependency(\.mapsApp) var mapsApp
  @Dependency(\.date.now) var now
  
  public var body: some ReducerOf<Self> {
    BindingReducer()
    Scope(state: \.buyMeTea, action: \.buyMeTea) {
      BuyMeTea()
    }
    Reduce {
      state,
      action in
      switch action {
      case .removeRecognizedTextButtonTapped:
        state.memory.recognizedText = nil
        state.memory.modified = now
        return .none
      case .removeLocationButtonTapped:
        state.memory.modified = now
        return .send(.binding(.set(\.memory.location, nil)))
      case .openInMapsButtonTapped:
        guard let memoryLocation = state.memory.location else {
          return .none
        }
        let location = MapsLocation(lat: memoryLocation.lat, long: memoryLocation.long, name: state.memory.name)
        return .run { [mapsApp] send in
          await mapsApp.openLocationInMaps(location)
        }
      case .shareButtonTapped:
        return .none
      case .deleteButtonTapped:
        state.isDeleteConfirmationAlertShown = true
        return .none
      case .onAppear:
        if state.isNew {
          state.memoryItemPicker = .init(imageURL: state.memory.previewImageURL, image: state.previewImage, items: state.memory.items, recognizedText: state.memory.recognizedText, isNew: true)
        }
        return .none
      case .doneButtonTapped, .cancelButtonTapped, .forgetButtonTapped:
        return .none
      case .imageRowTapped:
        state.memoryItemPicker = .init(imageURL: state.memory.previewImageURL, image: state.previewImage, items: state.memory.items, recognizedText: state.memory.recognizedText, isNew: false)
        return .none
      case .tagsRowTapped:
        state.tagsPicker = .init(selectedTags: Set(state.memory.tags.ids))
        return .none
      case .locationRowTapped:
        state.locationInProgress = true
        return .run { send in
          do {
            let coordinates = try await locationClient.requestCurrentLocation()
            await send(.receivedCurrentLocation(coordinates))
          } catch {
            reportIssue(error)
          }
          await send(.set(\.locationInProgress, false))
        }
      case .receivedCurrentLocation(let coordinates):
        state.memory.location = .init(lat: coordinates.lat, long: coordinates.long)
        state.memory.modified = now
        return .none
      case .binding(\.memory):
        state.memory.modified = now
        return .none
      case .tagsPicker(.presented(let action)):
        return tagsPickerAction(action, state: &state)
      case .memoryItemPicker(let action):
        return memoryItemPickerAction(action, state: &state)
      case .binding, .tagsPicker, .deleteConfirmationAlertButtonTapped, .buyMeTea:
        return .none
      }
    }
    .ifLet(\.memoryItemPicker, action: \.memoryItemPicker) {
      MemoryItemPicker()
    }
    .ifLet(\.$tagsPicker, action: \.tagsPicker) {
      MemoryTagsPicker()
    }
  }
  
  private func tagsPickerAction(_ action: MemoryTagsPicker.Action, state: inout State) -> EffectOf<Self> {
    switch action {
    case .doneButtonTapped:
      if let tags = state.tagsPicker?.selectedTags, tags != Set(state.memory.tags.ids) {
        state.memory.tags = .init(uniqueElements: tags.map(MemoryTag.init).sorted(by: <))
        state.memory.modified = Date()
      }
      return .send(.tagsPicker(.dismiss))
    case .cancelButtonTapped:
      return .send(.tagsPicker(.dismiss))
    case .binding:
      return .none
    case .tagTapped:
      return .none
    case .addTagAndSelect:
      return .none
    case .primaryButtonTapped, .loadTagsIfNeeded:
      return .none
    }
  }
  private func memoryItemPickerAction(_ action: MemoryItemPicker.Action, state: inout State) -> EffectOf<Self> {
    switch action {
    case .doneButtonTapped:
      let newItems = (state.memoryItemPicker?.items.filter({ $0.name.trimmingCharacters(in: .whitespaces).isEmpty == false }) ?? []).identified
      let newRecognizedText = state.memoryItemPicker?.recognizedText
      if newItems != state.memory.items {
        state.memory.items = newItems
        state.memory.modified = now
      }
      if state.memory.recognizedText != newRecognizedText {
        state.memory.recognizedText = newRecognizedText
        state.memory.modified = now
      }
      state.memoryItemPicker = nil
      return .none
    case .cancelButtonTapped:
      let hasItems = state.memoryItemPicker?.items.filter({ $0.name.isEmpty == false }).isEmpty == false
      state.memoryItemPicker = nil
      if state.isNew && hasItems == false  {
        return .run { send in
          await send(.forgetButtonTapped)
        }
      }
      return .none
    case .binding(_):
      return .none
    case .tappedImage(_):
      return .none
    case .tappedItem(_):
      return .none
    case .textFieldChanged(_, _):
      return .none
    case .labelVisibilityButtonTapped:
      return .none
    case .zoomedOut:
      return .none
    case .onAppear, .deleteItemButtonTapped:
      return .none
    case .recognizeTextButtonTapped:
      return .none
    case .recognizedTextTapped(_):
      return .none
    }
  }
}


// MARK: - MemoryFormView

public struct MemoryFormView: View {
  @Namespace var image
  @Bindable var store: StoreOf<MemoryForm>
  
  public init(store: StoreOf<MemoryForm>) {
    self.store = store
  }
  
  public var body: some View {
    ZStack {
      Form {
        Section("  ") {
          Button {
            store.send(.imageRowTapped, animation: .linear)
          } label: {
            if store.memoryItemPicker == nil {
              ZStack(alignment: .bottomTrailing) {
                store.previewImage
                  .resizable()
                  .aspectRatio(contentMode: .fill)
                  .frame(height: 180, alignment: store.memory.imageAligment)
                  .frame(maxWidth: .infinity)
                  .cornerRadius(.cornerRadius)
                  .matchedGeometryEffect(id: "image", in: image)
                if store.memory.recognizedText?.isEmpty == false {
                  Image(systemName: "text.viewfinder")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(10)
                    .background(.thinMaterial)
                    .clipShape(Circle())
                    .frame(width: 44, height: 44, alignment: .center)
                    .foregroundStyle(Color(uiColor: .label))
                    .zIndex(1)
                    .padding([.bottom, .trailing], 8)
                }
              }
            }
          }
          .animation(.linear, value: store.memoryItemPicker == nil)
          
          Button {
            store.send(.imageRowTapped, animation: .linear)
          } label: {
            // FIXME: do not have this map  here.
            Text(store.memory.displayTitle.nonEmpty ?? "Tap to label items")
              .font(.body)
              .fontWeight(.semibold)
              .multilineTextAlignment(.leading)
              .lineLimit(0)
              .foregroundStyle(Color.label)
          }
          
          Toggle(isOn: $store.memory.isPrivate) {
            Label("Private Memory", systemImage: store.memory.isPrivate ? "lock.fill" : "lock.open.fill")
              .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer), options: .nonRepeating))
          }
        }
        
        Section("Tags") {
          Button {
            store.send(.tagsRowTapped)
          } label: {
              MemoryTagsPickerView(store: Store(initialState: MemoryTagsPicker.State(tags: store.memory.tags, selectedTags: Set(store.memory.tags.ids)), reducer: {
                MemoryTagsPicker()
              }))
              .tagsSection
              .allowsHitTesting(false)
          }
        }
        
        Section("Location") {
          currentLocationButton
          
          if store.memory.location != nil {
            Button(role: .destructive) {
              store.send(.removeLocationButtonTapped)
            } label: {
              Text("Remove Location")
            }
          }
          
          if let location = store.memory.location {
            let coordinate = CLLocationCoordinate2D(latitude: location.lat, longitude: location.long)
            Map {
              Marker(store.memory.name, coordinate: coordinate)
                .tint(.blue)
            }
            .mapControls({
              MapScaleView()
              MapUserLocationButton()
            })
            .mapControlVisibility(.visible)
            .frame(height: 150)
            .cornerRadius(.cornerRadius)
            
            
            Button {
              store.send(.openInMapsButtonTapped)
            } label: {
              HStack {
                Image(systemName: "mappin.and.ellipse")
                Text("Open in Maps")
              }
            }
          }
        }
        Section(header: Text("Notes")) {
          TextEditor(text: $store.memory.notes)
            .padding(.vertical)
            .frame(minHeight: 100)
        }
        if let recognizedText = store.memory.recognizedText, recognizedText.isEmpty == false {
          Section(header: Text("Detected Text in Photo")) {
            Button("Remove Detected Text", systemImage: "text.viewfinder", role: .destructive) {
              store.send(.removeRecognizedTextButtonTapped)
            }
            .foregroundStyle(.red)
            TextEditor(text: .init(
              get: { recognizedText.text },
              set: { newValue in store.memory.recognizedText?.text = newValue })
            )
            .frame(minHeight: 50)
            .padding(.vertical)
          }
        }
        if store.buyMeTea.isPurchased == false {
          Section("Support the App") {
            BuyMeTeaView(store: store.scope(state: \.buyMeTea, action: \.buyMeTea))
              .padding(8)
              .listRowBackground(Color.clear.background(.thinMaterial))
          }
        }
      }
      .scrollDismissesKeyboard(.interactively)
      
      IfLetStore(store.scope(state: \.memoryItemPicker, action: \.memoryItemPicker)) { store in
        NavigationStack {
          MemoryItemPickerView(store: store)
            .matchedGeometryEffect(id: "image", in: image)
        }
      }
      .zIndex(1)
    }
    .onAppear(perform: {
      store.send(.onAppear)
    })
    .toolbar(
      content: {
        if store.memoryItemPicker == nil {
          toolbarContent
        }
    })
    .toolbarBackgroundVisibility(.visible, for: .bottomBar)
    .navigationTitle(Text(store.memory.name))
    .sheet(store: store.scope(state: \.$tagsPicker, action: \.tagsPicker)) { store in
      NavigationStack {
        MemoryTagsPickerView(store: store)
      }
    }
    .alert("Delete memory?", isPresented: $store.isDeleteConfirmationAlertShown) {
      Button("Delete", role: .destructive) {
        store.send(.deleteConfirmationAlertButtonTapped)
      }
    }
  }
  
  var currentLocationButton: some View {
    ZStack {
      HStack {
        LocationButton(.currentLocation) {
          store.send(.locationRowTapped)
        }
        .symbolVariant(.fill)
        .labelStyle(.iconOnly)
        .foregroundStyle(.primary)
        .cornerRadius(.cornerRadius)
        .font(Font.item)
        
        Text("Use Current Location")
          .foregroundStyle(.tint)
      }
      
      if store.locationInProgress {
        ProgressView()
          .zIndex(1)
      }
    }
  }
  
  @ToolbarContentBuilder
  var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      Button("Done") {
        store.send(.doneButtonTapped, animation: .linear)
      }
      .bold()
    }
    ToolbarItem(placement: .topBarLeading) {
      if store.isNew {
        Button("Delete") {
          store.send(.forgetButtonTapped, animation: .linear)
        }
        .foregroundStyle(.red)
      } else {
        Button("Cancel", role: .cancel) {
          store.send(.cancelButtonTapped, animation: .linear)
        }
        .accessibilityAction(.escape) {
          store.send(.cancelButtonTapped, animation: .linear)
        }
      }
      
    }
    ToolbarItem(placement: .bottomBar) {
      HStack {
        if store.isNew == false {
          Button {
            store.send(.deleteButtonTapped)
          } label: {
            Image(systemName: "trash")
              .resizable()
          }
          .foregroundStyle(.red)
        }
        
        Spacer()
        
        ShareLink(
          item: store.memory,
          preview: SharePreview(store.memory.name, image: store.previewImage, icon: Image(uiImage: store.memory.thumbnailImage))
        )
    }
  }
}
}

extension Memory: Transferable {
  public static var transferRepresentation: some TransferRepresentation {
    ProxyRepresentation { item in
      guard let image = UIImage(data: try Data(contentsOf: item.originalImageURL)) else {
        throw NSError(domain: "app.rogy.Remember", code: 3)
      }
      return Image(uiImage: image)
    }
    .suggestedFileName({ $0.name + ".png" })
  }
}

extension CGFloat {
  public static let cornerRadius: CGFloat = 10
}

//extension MemoryFormView {
//  var a11yID: A11yID { .ids }
//  struct A11yID {
//    static let ids = A11yID()
//    let main: String
//    <#let cancelButton: String#>
//    <#let function: (String) -> String#>
//    in
//  }
//}

extension MemoryForm.State {
  var isRememberButtonDisabled: Bool {
    memory.name.isEmpty
  }
}

extension Memory {
  public var name: String {
    displayTitle.nonEmpty ?? "No items"
  }
  @MainActor
  public var imageAligment: Alignment {
    guard let center = items.first?.center else { return .center }
    let screenSize = UIScreen.main.bounds.size.height
    if center.y < screenSize / 3 {
      return .top
    } else if center.y < screenSize * (2/3) {
      return .center
    } else {
      return .bottom
    }
  }
}

extension Color {
  static let label = Color(cgColor: UIColor.label.cgColor)
}

#if DEBUG

// MARK: Previews

public extension MemoryForm.State {
  @MainActor
  static let preview = Self()
}

#Preview {
  MemoryFormView(
    store: Store(
      initialState: .preview,
      reducer: { MemoryForm() }
    )
  )
}

#endif
