import ComposableArchitecture
import RememberCore
import SwiftUI
import ZoomableImage
import TextRecognizerClient
import RememberSharedKeys

@Reducer
public struct MemoryItemPicker {
  @ObservableState
  public struct State: Equatable {
    var imageURL: URL
    var image: Image
    public var items: IdentifiedArrayOf<MemoryItem>
    var focusedMemoryItem: MemoryItem.ID?
    var shouldFocusItem: Bool = true
    var showsItems: Bool = true
    var showsRecognizedText: Bool = false
    var isBarsHidden: Bool = false
    public var recognizedText: RecognizedText?
    var displayTextFrames: [TextFrame]?
    @Shared(.isAutoTextDetectionEnabled) var isAutoTextDetectionEnabled
    var isNew: Bool
    
    public init(
      imageURL: URL,
      image: Image,
      items: IdentifiedArrayOf<MemoryItem> = [],
      recognizedText: RecognizedText? = nil,
      isNew: Bool
    ) {
      self.imageURL = imageURL
      self.image = image
      self.items = items
      self.isNew = isNew
      self.recognizedText = recognizedText
      self.shouldFocusItem = items.count == 1 && items.first?.name.isEmpty == true && recognizedText == nil
    }
    
    public init() {
      self.init(
        imageURL: URL(string: "image.url")!,
        image: Image(systemName: "car"),
        items: [.init(
          id: UUID().uuidString,
          name: "lele",
          center: .init(x: 100, y: 100)
        )],
        isNew: false
      )
    }
  }
  
  @CasePathable
  public enum Action: Equatable, BindableAction {
    case binding(_ action: BindingAction<State>)
    case tappedImage(CGPoint)
    case tappedItem(MemoryItem.ID)
    case deleteItemButtonTapped(MemoryItem.ID)
    case textFieldChanged(MemoryItem.ID, String)
    case doneButtonTapped
    case cancelButtonTapped
    case labelVisibilityButtonTapped
    case zoomedOut
    case recognizeTextButtonTapped
    case recognizedTextTapped(TextFrame)
    case onAppear
  }
  
  public init() {}
  
  @Dependency(\.textRecognizer) var textRecognizer
  @Dependency(\.uuid) var uuid
  
  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .recognizedTextTapped(let textFrame):
        let item = MemoryItem(id: uuid().uuidString, name: textFrame.text, center: textFrame.frame.center)
        state.items.append(item)
        state.displayTextFrames?.removeAll(where: { textFrame == $0 })
        state.isBarsHidden = false
        state.showsItems = true
        return .none
      case .recognizeTextButtonTapped:
        if state.showsRecognizedText {
          state.showsRecognizedText = false
          state.displayTextFrames = nil
          return .none
        } else {
          state.showsRecognizedText = true
          if let recognizedText = state.recognizedText {
            return .send(.set(\.displayTextFrames, recognizedText.textFrames), animation: .bouncy)
          } else {
            return .run { [imageURL = state.imageURL, textRecognizer, uuid] send in
              let data = try Data(contentsOf: imageURL)
              let image = UIImage(data: data) ?? UIImage()
              let result = try await textRecognizer.recognizeTextInImage(image)
              let recognizedText = RecognizedText(uuid: { uuid().uuidString }, result: result)
              await send(.set(\.recognizedText, recognizedText))
              await send(.set(\.displayTextFrames, recognizedText.textFrames), animation: .bouncy)
            }
          }
        }
      case .labelVisibilityButtonTapped:
        state.showsItems.toggle()
        return .none
      case .onAppear:
        if state.isAutoTextDetectionEnabled && state.isNew {
          state.isNew = false
          state.shouldFocusItem = false
          return .send(.recognizeTextButtonTapped)
        } else if state.shouldFocusItem {
          state.shouldFocusItem = false
          let id = state.items.first?.id
          return .run { send in
            try await Task.sleep(for: .milliseconds(300))
            await send(.binding(.set(\.focusedMemoryItem, id)))
          }
        } else {
          return .none
        }
      case .tappedImage(let point):
        if state.showsItems == false {
          state.isBarsHidden.toggle()
          return .none
        } else {
          let intersectsItem = state.items.first { (item: MemoryItem) in
            var itemFrame = item.name.itemFrame(center: item.center)
            itemFrame.size.width += 12
            itemFrame.origin.y -= 12
            itemFrame.size.height += 12
            return itemFrame.contains(point)
          }
          let intersectsRecognizedText =
          if let recognizedText = state.recognizedText {
            recognizedText.textFrames.contains(where: { $0.frame.offsetBy(dx: .zero, dy: 88).contains(point) })
          } else {
            false
          }
          state.showsItems = true
          if let intersectsItem {
            return .send(.tappedItem(intersectsItem.id))
          } else if intersectsRecognizedText == false {
            let item = MemoryItem(id: UUID().uuidString, name: "", center: point)
            state.items.append(item)
            state.focusedMemoryItem = item.id
            return .none
          } else {
            return .none
          }
        }
      case .deleteItemButtonTapped(let id):
        var items = state.items
        items.remove(id: id)
        return .run { [items] send in
          await Task.yield()
          await send(.set(\.items, items), animation: .easeOut)
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

extension String {
  func itemFrame(center: CGPoint) -> CGRect {
    let padding = Double.padding * 3
    var size = NSAttributedString(
      string: self,
      attributes: [.font: UIFont.item]
    ).size()
    size.width += padding
    size.height += padding
    let itemFrame = CGRect(center: center, size: size)
    return itemFrame
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
    return false
    //    guard let dragValue else { return false }
    //    return abs(dragValue.predictedEndTranslation.width) > Self.dismissDragTranslationThresholder || abs(dragValue.predictedEndTranslation.height) > Self.dismissDragTranslationThresholder
  }
  
  public init(store: StoreOf<MemoryItemPicker>) {
    self.store = store
  }
  
  func position(for item: MemoryItem) -> CGPoint {
    guard item.id == focusedItem, keyboardFrame != .zero, keyboardFrame.contains(item.center) else { return item.center }
    let itemHeight = item.name.itemFrame(center: .zero).height
    return .init(x: item.center.x, y: keyboardFrame.minY - itemHeight / 2)
  }
  
  var offset: CGSize {
    .zero//dragValue?.translation ?? .zero
  }
  
  var isDragging: Bool {
    offset != .zero
  }
  
  public var body: some View {
    ZStack {
      ZoomableImage(image: store.image, contentMode: .fill, magnification: $magnification)
        .background(Color.clear)
        .simultaneousGesture(
          DragGesture(minimumDistance: .zero)
            .updating($dragValue, body: { value, state, _ in
              state = value
            })
        )
        
      
      if store.showsItems && isZooming == false {
        ForEach(store.items) { item in
          itemCell(for: item)
        }
      }
      
      if store.showsRecognizedText, let textFrames = store.displayTextFrames, isZooming == false {
        ForEach(textFrames) { textFrame in
          Button {
            store.send(.recognizedTextTapped(textFrame), animation: .bouncy)
          } label: {
            if store.state.isRecognitionIntersectingOthers(textFrame) {
              Circle()
                .fill(Color(uiColor: .systemGreen))
                .stroke(Color.white.opacity(0.5), style: .init(lineWidth: 3))
                .frame(width: 12, height: 12)
                .padding(12)
                .contentShape(Circle())
            } else {
              Text(textFrame.text)
                .padding(8)
                .lineLimit(0)
                .background(Color.accentColor.opacity(0.8), in: Capsule())
                .foregroundStyle(Color.primary)
            }
            
          }
          .position(textFrame.frame.center)
          .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
      }
    }
    .ignoresSafeArea()
//    .offset(offset)
//    .scaleEffect(isDismissable ? 0.9 : 1.0, anchor: .center)
//    .animation(.bouncy(duration: 0.25, extraBounce: 0.1), value: offset)
//    .animation(.easeOut, value: isDismissable)
//    .gesture(DragGesture(minimumDistance: 0)
//      .updating($dragValue, body: { value, state, _ in
//        state = value
//      }))
//    .simultaneousGesture(
//      DragGesture(minimumDistance: .zero)
//        .updating($dragValue, body: { value, state, _ in
//          state = value
//        })
//    )
    .onAppear {
      store.send(.onAppear)
    }
    .onChange(of: magnification) { oldValue, newValue in
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
    .navigationTitle(store.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackgroundVisibility(.visible, for: .navigationBar, .bottomBar)
    .toolbarVisibility(toolbarsHidden ? .hidden : .visible, for: .navigationBar, .bottomBar)
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
        HStack {
          Button {
            store.send(.labelVisibilityButtonTapped, animation: .linear)
          } label: {
            Image(systemName: store.showsItems ? "capsule.fill" : "capsule")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .padding(10)
              .when(
                store.showsItems,
                then: { $0.background(Color.accentColor) },
                else: { $0.background(.thinMaterial) }
              )
              .clipShape(Circle())
              .frame(width: 44, height: 44, alignment: .center)
              .foregroundStyle(Color(uiColor: .label))
          }
          
          Spacer()
          
          textScanButton
        }
      }
    }
    .modifier(KeyboardAdaptive(keyboardFrame: $keyboardFrame))
  }
  
  private var textScanButton: some View {
    Button {
      store.send(.recognizeTextButtonTapped, animation: .linear)
    } label: {
      ZStack {
        Image(systemName: store.recognizedText?.isEmpty == true ? "text.page.slash.fill" : "text.viewfinder")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer), options: .nonRepeating))
          .padding(10)
          .when(
            store.showsRecognizedText,
            then: { $0.background(Color.accentColor) },
            else: { $0.background(.thinMaterial) }
          )
          .clipShape(Circle())
          .frame(width: 44, height: 44, alignment: .center)
          .foregroundStyle(Color(uiColor: .label))
        
        if store.isTextRecognitionInProgress {
          ProgressView()
            .progressViewStyle(.circular)
        }
      }
    }
    .disabled(store.disabledTextScanButton)
  }
  
  @State var keyboardFrame: CGRect = .zero
  
  var toolbarsHidden: Bool {
    store.isBarsHidden || isZooming
  }
  
  var isZooming: Bool {
    magnification != nil
  }
  
  func itemCell(for item: MemoryItem) -> some View {
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
    .overlay(alignment: .topTrailing) {
      Button {
        store.send(.deleteItemButtonTapped(item.id))
      } label: {
        Image(systemName: "minus.circle.fill")
          .symbolRenderingMode(.multicolor)
          .resizable()
          .scaledToFill()
      }
      .frame(width: 24, height: 24)
      .offset(x: 12, y: -12)
      .padding(4)
      .zIndex(1)
    }
    .position(position(for: item))
    .zIndex(1)
    .focused($focusedItem, equals: item.id)
    .animation(.linear(duration: 0.4), value: store.showsItems)
    .transition(.opacity) // TODO: combine with animation using .scale(anchor:
  }
}

extension MemoryItemPicker.State {
  var title: String {
    let name = items.map(\.name).joined(separator: ", ")
    return name.isEmpty ? "Label items" : name
  }
  var disabledTextScanButton: Bool {
    isTextRecognitionInProgress || recognizedText?.isEmpty == true
  }
  var isTextRecognitionInProgress: Bool {
    showsRecognizedText && recognizedText == nil
  }
  func isRecognitionIntersectingOthers(_ recognition: TextFrame) -> Bool {
    guard let textFrames = recognizedText?.textFrames else {
      return false
    }
    let recognitionFrame = recognition.itemFrame
    for textFrame in textFrames where textFrame != recognition {
      if recognitionFrame.intersects(textFrame.itemFrame) {
        return true
      }
    }
    return false
  }
}

extension TextFrame {
  var itemFrame: CGRect {
    text.itemFrame(center: frame.center)
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

extension RecognizedText {
  init(uuid: () -> String, result: TextRecognizerClient.Result) {
    self.init(id: uuid(), text: result.text, textFrames: result.textFrames.map({ TextFrame(text: $0.text, frame: $0.frame) }))
  }
}

extension CGRect {
  var center: CGPoint {
    .init(x: midX, y: midY)
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
