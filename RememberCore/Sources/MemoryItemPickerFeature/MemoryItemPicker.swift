import ComposableArchitecture
import RememberCore
import SwiftUI
import ZoomableImage

@Reducer
public struct MemoryItemPicker {
  @ObservableState
  public struct State: Equatable {
    var image: Image
    public var items: IdentifiedArrayOf<MemoryItem>
    var focusedMemoryItem: MemoryItem.ID?
    var shouldFocusItem: Bool = true
    var showsItems: Bool = true
    
    public init(image: Image, items: IdentifiedArrayOf<MemoryItem> = []) {
      self.image = image
      self.items = items
      self.shouldFocusItem = items.count == 1 && items.first?.name.isEmpty == true
    }
    
    public init() {
      self.init(
        image: Image(systemName: "car"),
        items: [.init(
          id: UUID().uuidString,
          name: "lele",
          center: .init(x: 100, y: 100)
        )]
      )
    }
  }
  
  @CasePathable
  public enum Action: Equatable, BindableAction {
    case binding(_ action: BindingAction<State>)
    case tappedImage(CGPoint)
    case tappedItem(MemoryItem.ID)
    case textFieldChanged(MemoryItem.ID, String)
    case doneButtonTapped
    case cancelButtonTapped
    case labelVisibilityButtonTapped
    case zoomedOut
    case onAppear
  }
  
  public init() {}
  
  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .labelVisibilityButtonTapped:
        state.showsItems.toggle()
        return .none
      case .onAppear:
        guard state.shouldFocusItem else { return .none }
        state.shouldFocusItem = false
        let id = state.items.first?.id
        return .run { send in
          try await Task.sleep(for: .milliseconds(300))
          await send(.binding(.set(\.focusedMemoryItem, id)))
        }
      case .tappedImage(let point):
        let intersectsItem = state.items.first { (item: MemoryItem) in
          let padding = Double.padding * 4
          var size = NSAttributedString(
            string: item.name,
            attributes: [.font: UIFont.item]
          ).size()
          size.width += padding
          size.height += padding
          let itemFrame = CGRect(center: item.center, size: size)
          return itemFrame.contains(point)
        }
        state.showsItems = true
        if let intersectsItem {
          return .send(.tappedItem(intersectsItem.id))
        } else {
          let item = MemoryItem(id: UUID().uuidString, name: "", center: point)
          state.items.append(item)
          state.focusedMemoryItem = item.id
          return .none
        }
      case .tappedItem(_):
        return .none
      case let .textFieldChanged(id, text):
        let shouldRemove = text.isEmpty && id != state.focusedMemoryItem
        if shouldRemove {
          state.items.remove(id: id)
        } else {
          state.items[id: id]?.name = text
        }
        return .none
      case .binding(\.focusedMemoryItem):
        return state.items
          .filter(\.name.isEmpty)
          .map({ Effect.send(.textFieldChanged($0.id, $0.name)) })
          .reduce(.none, { $0.concatenate(with: $1) })
      case .zoomedOut:
        return .send(.doneButtonTapped, animation: .linear)
      case .doneButtonTapped:
        return .none
      case .cancelButtonTapped:
        return .none
      case .binding:
        return .none
      }
    }
  }
}


// MARK: - MemoryItemPickerView

public struct MemoryItemPickerView: View {
  private static let dismissDragTranslationThresholder: CGFloat = 60
  @Bindable var store: StoreOf<MemoryItemPicker>
  @State var magnification: CGFloat?
  @FocusState var focusedItem: MemoryItem.ID?
  @GestureState var dragValue: DragGesture.Value?
  private var isDismissable: Bool {
    guard let dragValue else { return false }
    return abs(dragValue.predictedEndTranslation.width) > Self.dismissDragTranslationThresholder || abs(dragValue.predictedEndTranslation.height) > Self.dismissDragTranslationThresholder
  }
  
  public init(store: StoreOf<MemoryItemPicker>) {
    self.store = store
  }
  
  func position(for item: MemoryItem) -> CGPoint {
    var adjustedCenter = item.center
    adjustedCenter.y += 120
    guard item.id == focusedItem, keyboardFrame != .zero, keyboardFrame.contains(adjustedCenter) else { return item.center }
    return .init(x: item.center.x, y: keyboardFrame.minY - 120)
  }
  
  var offset: CGSize {
    dragValue?.translation ?? .zero
  }
  
  var isDragging: Bool {
    offset != .zero
  }
  
  public var body: some View {
    ZStack {
      ZoomableImage(image: store.image, contentMode: .fill, magnification: $magnification)
        .background(Color(uiColor: .systemBackground))
        .ignoresSafeArea()
      
      if store.showsItems && isDragging == false {
        ForEach(store.items) { item in
          TextField(
            "",
            text: .init(
              get: { item.name },
              set: { store.send(.textFieldChanged(item.id, $0)) }
            ),
            prompt: Text("Enter a label")
          )
          .font(Font.item)
          .multilineTextAlignment(.center)
          .submitLabel(.done)
          .fixedSize()
          .padding(Double.padding)
          .background(.regularMaterial, in: Capsule())
          .position(position(for: item))
          .zIndex(1)
          .focused($focusedItem, equals: item.id)
          .animation(.linear(duration: 0.4), value: store.showsItems)
          .transition(.opacity) // TODO: combine with animation using .scale(anchor:
        }
      }
    }
    .offset(offset)
    .scaleEffect(isDismissable ? 0.9 : 1.0, anchor: .center)
    .animation(.bouncy(duration: 0.25, extraBounce: 0.1), value: offset)
    .animation(.easeOut, value: isDismissable)
    .simultaneousGesture(
      DragGesture(minimumDistance: 0)
        .updating($dragValue, body: { value, state, _ in
          state = value
        })
    )
    .onAppear {
      store.send(.onAppear)
    }
    .onChange(of: magnification) { oldValue, newValue in
      let showsItems = newValue == nil
      if store.showsItems != showsItems {
        store.send(.binding(.set(\.showsItems, showsItems)), animation: .linear)
      }
      if let oldValue, newValue == nil {
        if oldValue < 0.7 {
          store.send(.zoomedOut, animation: .linear)
        }
      }
    }
    .onChange(of: dragValue, { oldValue, newValue in
      // if user ended drag
      if let oldValue, newValue == nil {
        if oldValue.translation == .zero {
          store.send(.tappedImage(oldValue.location), animation: .linear)
        } else if abs(oldValue.predictedEndTranslation.width) > Self.dismissDragTranslationThresholder || abs(oldValue.predictedEndTranslation.height) > Self.dismissDragTranslationThresholder {
          store.send(.doneButtonTapped, animation: .linear)
        }
      }
    })
    .bind($store.focusedMemoryItem, to: $focusedItem)
    .navigationTitle(Text(store.title))
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackgroundVisibility(.visible, for: .navigationBar, .bottomBar)
    .toolbarVisibility((isZooming || isDragging) ? .hidden : .visible, for: .navigationBar, .bottomBar)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Cancel") {
          store.send(.cancelButtonTapped, animation: .linear)
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button("Done") {
          store.send(.doneButtonTapped, animation: .linear)
        }
        .bold()
      }
      ToolbarItem(placement: .bottomBar) {
        Button {
          store.send(.labelVisibilityButtonTapped, animation: .linear)
        } label: {
          Image(systemName: store.showsItems ? "capsule" : "capsule.fill")
        }
      }
    }
    .modifier(KeyboardAdaptive(keyboardFrame: $keyboardFrame))
  }
  
  @State var keyboardFrame: CGRect = .zero
  
  var isZooming: Bool {
    magnification != nil
  }
}

extension MemoryItemPicker.State {
  var title: String {
    let name = items.map(\.name).joined(separator: ", ")
    return name.isEmpty ? "Label items" : name
  }
}

extension Double {
  static let padding: Double = 10
}

extension CGRect {
  init(center: CGPoint, size: CGSize) {
    self.init(
      origin: .init(
        x: center.x - size.width / 2,
        y: center.y - size.height / 2
      ),
      size: size
    )
  }
}

extension Font {
  public static var item: Font {
    Font(UIFont.item)
  }
  
}
extension UIFont {
  static var item: UIFont {
    UIFont.preferredFont(forTextStyle: .body)
  }
}


//extension MemoryItemPickerView {
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

public extension MemoryItemPicker.State {
  @MainActor
  static let preview = Self()
}

#Preview {
  NavigationStack {
    MemoryItemPickerView(
      store: Store(
        initialState: .preview,
        reducer: { MemoryItemPicker() }
      )
    )
  }
}

#endif
