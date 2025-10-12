import ComposableArchitecture
import RememberCore
import SwiftUI
import DatabaseClient
import IssueReporting

@Reducer
public struct MemoryTagsPicker {
  @ObservableState
  public struct State: Equatable {
    var tags: IdentifiedArrayOf<MemoryTag>
    var displayTags: [MemoryTag] = []
    public var selectedTags: Set<MemoryTag.ID>
    var newTag: String
    var isDataLoaded: Bool

    public init(
      tags: IdentifiedArrayOf<MemoryTag> = [],
      selectedTags: Set<MemoryTag.ID> = [],
      newTag: String = ""
    ) {
      self.tags = tags
      self.displayTags = tags.elements
      self.selectedTags = selectedTags
      self.newTag = newTag
      self.isDataLoaded = tags.isEmpty == false
    }
    
    
    public init() {
      self.init(
        tags: [
          .init(label: "jellow"),
          .init(label: "world")
        ],
        selectedTags: ["world"]
      )
    }
  }
  
  @CasePathable
  public enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case tagTapped(MemoryTag.ID)
    case addTagAndSelect(String)
    case primaryButtonTapped
    case doneButtonTapped
    case cancelButtonTapped
    case loadTagsIfNeeded
  }
  
  public init() {}
    
  @Dependency(\.database) var database
  
    public var body: some ReducerOf<Self> {
      BindingReducer()
      Reduce { state, action in
        switch action {
        case .loadTagsIfNeeded:
          guard state.isDataLoaded == false else { return .none }
          state.isDataLoaded = true
          return .run { [database] send in
            let tags = try await database.fetchTags().sorted(by: <)
            await send(.binding(.set(\.tags, tags.identified)))
            await send(.binding(.set(\.displayTags, tags)))
          }
        case .tagTapped(let tag):
          if state.selectedTags.contains(tag) {
            state.selectedTags.remove(tag)
          } else {
            state.selectedTags.insert(tag)
          }
          return .none
        case .addTagAndSelect(let tag):
          guard tag.isEmpty == false else { return .none }
          state.selectedTags.insert(tag)
          guard state.tags.ids.contains(tag) == false else { return .none }
          let tag = MemoryTag(label: tag)
          state.tags.updateOrAppend(tag)
          state.tags.sort(by: <)
          state.displayTags = state.tags.elements
          return .run { [database] _ in
            do {
              try await database.insertTag(tag)
            } catch {
              reportIssue(error)
            }
          }
        case .primaryButtonTapped:
          return .run { [tag = state.newTag] send in
            let trimmed = tag.trimmingCharacters(in: .whitespaces)
            let newTag = tag.components(separatedBy: .whitespaces).first ?? trimmed
            await send(.binding(.set(\.newTag, "")))
            await send(.addTagAndSelect(newTag))
          }
        case .binding(\.newTag):
          let newTag = state.newTag
          guard newTag.isEmpty == false else {
            state.displayTags = state.tags.elements
            return .none
          }
          let trimmed = newTag.trimmingCharacters(in: .whitespaces)
          if newTag != trimmed {
            if trimmed.isEmpty {
              return .run { send in
                try await Task.sleep(for: .milliseconds(50))
                await send(.binding(.set(\.newTag, "")))
              }
            } else {
              return .send(.primaryButtonTapped)
            }
          } else {
            let allTags = state.tags
            let filterTags = trimmed.isEmpty ? allTags.elements :  allTags.filter({ $0.label.localizedStandardContains(newTag) })
            let selectedTags = state.selectedTags.compactMap({ allTags[id: $0] })
            let displayTags = Set(filterTags + selectedTags)
            return .send(.set(\.displayTags, displayTags.sorted(by: <)))
          }
        case .binding, .cancelButtonTapped, .doneButtonTapped:
          return .none
        }
      }
    }
}

// MARK: - MemoryTagsPickerView

public struct MemoryTagsPickerView: View {
  @Bindable var store: StoreOf<MemoryTagsPicker>
  @FocusState var newTagFocused: Bool
  
  public init(store: StoreOf<MemoryTagsPicker>) {
    self.store = store
  }
  
  public var body: some View {
    Form {
      Section {
        if store.displayTags.isEmpty && store.newTag.isEmpty == false {
          Text("Tap 'Space' or 'Done' on keyboard to add the tag #\(store.newTag)")
        } else {
          tagsSection
        }
      }
      
      Section {
        TextField("Add new tag...", text: $store.newTag)
          .autocorrectionDisabled()
          .submitLabel(.done)
          .onSubmit {
            store.send(.primaryButtonTapped)
            newTagFocused = true
          }
          .focused($newTagFocused)
      }
    }
    .onAppear {
      newTagFocused = true
      store.send(.loadTagsIfNeeded)
    }
    .navigationTitle(Text("Tags"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        CancelButton {
          store.send(.cancelButtonTapped, animation: .linear)
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        DoneButton {
          store.send(.doneButtonTapped, animation: .linear)
        }
      }
    }
  }
  
  @ViewBuilder
  public var tagsSection: some View {
    if store.tags.isEmpty {
      HStack {
        Image(systemName: "tag")
        Text("Add tags")
      }
    } else {
      FlowLayout {
        ForEach(store.displayTags) { tag in
          Button {
            store.send(.tagTapped(tag.id))
          } label: {
            Text("#" + tag.label)
          }
          .buttonStyle(DynamicButtonStyle(
            isSelected: store.selectedTags.contains(tag.id)
          ))
          .fontWeight(.semibold)
        }
      }
    }
  }
}


struct DynamicButtonStyle: PrimitiveButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        if isSelected {
            BorderedProminentButtonStyle()
                .makeBody(configuration: configuration)
        } else {
          BorderedButtonStyle()
            .makeBody(configuration: configuration)
            .foregroundStyle(.secondary)
        }
    }
}

//extension MemoryTagsPickerView {
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

public extension MemoryTagsPicker.State {
  @MainActor
  static let preview = Self()
}

#Preview {
  NavigationStack {
    MemoryTagsPickerView(
      store: Store(
        initialState: .preview,
        reducer: { MemoryTagsPicker() }
      )
    )
  }
}

#endif
