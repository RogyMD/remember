import ComposableArchitecture
import RememberCore
import SwiftUI
import MemoryFormFeature
import DatabaseClient
import IssueReporting

extension Date {
  var startOfDay: Date {
    Calendar.current.startOfDay(for: self)
  }
}

@Reducer
public struct MemoryList {
  @ObservableState
  public struct State: Equatable {
    public static var empty: State { .init(memories: [], isDataLoaded: nil, allowsDelete: true) }
    public var memories: IdentifiedArrayOf<Memory>
    @Presents var memoryForm: MemoryForm.State?
    var isDataLoaded: Bool?
    var dataSource: [Date: [Memory.ID]]
    var rememberedDays: [Date]
    var allowsDelete: Bool
    
    public init(memories: [Memory], isDataLoaded: Bool? = nil, allowsDelete: Bool = true) {
      let memories = memories.identified
      self.memories = memories
      self.isDataLoaded = isDataLoaded
      self.allowsDelete = allowsDelete
      let dataSource: [Date: [Memory.ID]] = .init(grouping: memories.ids, by: { memoryID in
        let memory = memories[id: memoryID]!
        return memory.created.startOfDay
      })
      self.dataSource = dataSource
      self.rememberedDays = dataSource.keys.sorted(by: >)
    }
    
    public init() {
      self.init(
        memories: [
          .init(
            created: Date().addingTimeInterval(-Double.random(in: 1...1_000_000)),
            items: [.init(
              id: UUID().uuidString,
              name: "Car",
              center: .init(x: 100, y: 100)
            )],
            tags: [.init(label: "car")],
            location: .init(lat: .zero, long: .zero)
          ),
        ],
        isDataLoaded: true
      )
    }
  }
  
  @CasePathable
//  public enum Action: Equatable, BindableAction {
  public enum Action: Equatable {
//    case binding(BindingAction<State>)
    case memoryForm(PresentationAction<MemoryForm.Action>)
    case memoryTapped(Memory.ID)
    case closeButtonTapped
    case settingsButtonTapped
    case deleteRows(Date, IndexSet)
    case addMemory(Memory)
    case loadDataIfNeeded
    case updateMemories([Memory])
  }
  
  public init() {}
  
  @Dependency(\.database) var database
  
    public var body: some ReducerOf<Self> {
//      BindingReducer()
      Reduce {
        state,
        action in
        switch action {
        case .loadDataIfNeeded:
          guard state.isDataLoaded == nil else { return .none }
          state.isDataLoaded = false
          return .run { [database] send in
            do {
              let memories = try await database.fetchMemories()
              await send(.updateMemories(memories))
            } catch {
              reportIssue(error)
            }
          }
        case .updateMemories(let memories):
          state.isDataLoaded = true
          state.updateMemories(memories)
          return .none
        case .memoryTapped(let id):
          guard let memory = state.memories[id: id] else { return .none }
          state.memoryForm = .init(
            memory: memory,
            isNew: false,
            previewImage: .init(uiImage: memory.previewImage)
          )
          return .none
        case let .deleteRows(date, indices):
          guard let id = indices.first.flatMap({ index in state.dataSource[date]?.remove(at: index) }) else { return .none }
          state.memories.remove(id: id)
          return .run { [database] _ in
            do {
              try await database.deleteMemory(id)
            } catch {
              reportIssue(error)
            }
          }
        case .addMemory(let memory):
          state.memories.updateOrAppend(memory)
          state.dataSource[memory.created.startOfDay, default: []].insert(memory.id, at: .zero)
          state.rememberedDays = state.dataSource.keys.sorted(by: >)
          return .none
        case .memoryForm(.presented(let action)):
          return memoryFormAction(action, state: &state)
        case .memoryForm,
            .closeButtonTapped,
            .settingsButtonTapped:
          return .none
        }
      }
      .ifLet(\.$memoryForm, action: \.memoryForm) {
        MemoryForm()
      }
    }
  
  private func memoryFormAction(_ action: MemoryForm.Action, state: inout State) -> EffectOf<Self> {
    switch action {
    case .doneButtonTapped:
      let updatedMemory: Memory?
      if let memory = state.memoryForm?.memory,
          let existing = state.memories[id: memory.id],
          memory.modified != existing.modified {
        updatedMemory = memory
        state.memories.updateOrAppend(memory)
      } else {
        updatedMemory = nil
      }
      return .run { [database] send in
          await send(.memoryForm(.dismiss))
        guard let updatedMemory else { return }
        do {
          try await database.updateOrInsertMemory(updatedMemory)
        } catch {
          reportIssue(error)
        }
      }
    case .cancelButtonTapped:
      return .send(.memoryForm(.dismiss))
    case .deleteConfirmationAlertButtonTapped:
      guard let memory = state.memoryForm?.memory, let index = state.memories.index(id: memory.id) else { return .none }
      return .run { send in
        await send(.deleteRows(memory.created.startOfDay, .init(integer: index)))
        await send(.memoryForm(.dismiss))
      }
    case .binding(_):
      return .none
    case .memoryItemPicker(_):
      return .none
    case .tagsPicker(_):
      return .none
    case .imageRowTapped:
      return .none
    case .tagsRowTapped:
      return .none
    case .locationRowTapped:
      return .none
    case .receivedCurrentLocation(_):
      return .none
    case .forgetButtonTapped, .shareButtonTapped, .deleteButtonTapped, .openInMapsButtonTapped, .removeLocationButtonTapped:
      return .none
    case .onAppear:
      return .none
    }
  }
}

extension MemoryList.State {
  mutating func updateMemories(_ memories: [Memory]) {
    let memories = memories.identified
    self.memories = memories
    self.isDataLoaded = true
    let dataSource: [Date: [Memory.ID]] = .init(grouping: memories.ids, by: { memoryID in
      let memory = memories[id: memoryID]!
      return memory.created.startOfDay
    })
    self.dataSource = dataSource
    self.rememberedDays = dataSource.keys.sorted(by: >)
  }
}


// MARK: - MemoryListView

public struct MemoryListView: View {
  @Bindable var store: StoreOf<MemoryList>
  
  public init(store: StoreOf<MemoryList>) {
    self.store = store
  }
  
  public var body: some View {
    List {
      if store.isDataLoaded == true {
        if store.rememberedDays.isEmpty {
          Text("No recorded memories")
            .multilineTextAlignment(.center)
            .listRowBackground(Color.clear)
        } else {
          ForEach(store.rememberedDays, id: \.self) { day in
            if let memories = store.dataSource[day]?.compactMap({ store.memories[id: $0] }) {
              Section(day.displayDate) {
                ForEach(memories) { memory in
                  memoryRow(for: memory)
                }
                .onDelete(perform: store.allowsDelete ? { indices in
                  store.send(.deleteRows(day, indices), animation: .default)
                } : nil)
              }
            }
          }
        }
      } else {
        ProgressView()
          .progressViewStyle(.circular)
          .listRowBackground(Color.clear)
      }
      
//      Button {
//        store.send(.settingsButtonTapped)
//      } label: {
//        HStack {
//          Image(systemName: "gear")
//          Text("Settings")
//        }
//      }
//        .listRowBackground(Color.clear)
    }
    .listStyle(.plain)
    .navigationTitle(Text("Memories"))
    .toolbar(content: {
      ToolbarItem(placement: .topBarTrailing) {
        EditButton()
      }
      
      ToolbarItem(placement: .topBarLeading) {
        Button("Close") {
          store.send(.closeButtonTapped)
        }
      }
    })
    .onAppear {
      store.send(.loadDataIfNeeded)
    }
    .fullScreenCover(store: store.scope(state: \.$memoryForm, action: \.memoryForm)) { store in
      NavigationStack {
        MemoryFormView(store: store)
      }
    }
  }
  
  private func memoryRow(for memory: Memory) -> some View {
    Button {
      store.send(.memoryTapped(memory.id))
    } label: {
      HStack {
        Image(uiImage: memory.thumbnailImage)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: CGSize.thumbnailSize.width, height: CGSize.thumbnailSize.height, alignment: memory.imageAligment)
          .cornerRadius(.cornerRadius)
        
        VStack(alignment: .leading, spacing: 4) {
          if memory.items.isEmpty == false {
            Text(memory.name)
              .foregroundStyle(.primary)
          }
          
          if memory.tags.isEmpty == false {
            Text(memory.displayTags)
              .multilineTextAlignment(.leading)
              .lineLimit(0)
              .font(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(.tint)
          }
          
          if memory.location != nil {
            HStack {
              Image(systemName: "mappin.and.ellipse")
              Text("Location")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
          }
          
          HStack {
            Image(systemName: "camera")
            Text(memory.created.displayTime)
          }
          .font(.caption2)
          .foregroundStyle(.secondary)
          
          if let notes = memory.notes.nonEmpty?.prefix(150) {
            HStack {
              Image(systemName: "pencil.and.list.clipboard")
              
              Text(notes)
                .lineLimit(1)
            }
            .font(.caption2)
            .italic()
            .bold()
            .foregroundStyle(.tertiary)
          }
        }
      }
    }
    .listRowBackground(Color.clear)
  }
}

extension Date {
  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
  }()
  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .medium
    return formatter
  }()
  var displayDate: String {
    Date.dateFormatter.string(from: startOfDay)
  }
  var displayTime: String {
    Date.timeFormatter.string(from: self)
  }
}

extension Memory {
  var displayTags: String {
    tags.map { "#" + $0.label }.joined(separator: " ")
  }
}

//extension MemoryListView {
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

public extension MemoryList.State {
  @MainActor
  static let preview = Self(memories: [
    .init(
      created: Date().addingTimeInterval(-Double.random(in: 1...1_000_000)),
      items: [.init(
        id: UUID().uuidString,
        name: "Car",
        center: .init(x: 100, y: 100)
      )],
      tags: [.init(label: "car")],
      location: .init(lat: .zero, long: .zero)
    ),
    .init(
      created: Date().addingTimeInterval(-Double.random(in: 1...1_000_000)),
      items: [.init(
        name: "Wallet",
        center: .init(x: 100, y: 100)
      )],
      tags: [.init(label: "wallet")],
      location: .init(lat: .zero, long: .zero)
    ),
    .init(
      created: Date().addingTimeInterval(-Double.random(in: 1...1_000_000)),
      items: [.init(
        name: "Charger",
        center: .init(x: 100, y: 100)
      )],
      tags: [.init(label: "charger")],
      location: .init(lat: .zero, long: .zero)
    ),
    .init(
      created: Date().addingTimeInterval(-Double.random(in: 1...1_000_000)),
      items: [.init(
        name: "Backpack",
        center: .init(x: 100, y: 100)
      )],
      tags: [.init(label: "backpack")],
      location: .init(lat: .zero, long: .zero)
    ),
    .init(
      created: Date().addingTimeInterval(-Double.random(in: 1...1_000_000)),
      items: [.init(
        name: "Notebook",
        center: .init(x: 100, y: 100)
      )],
      tags: [.init(label: "notebook")],
      location: .init(lat: .zero, long: .zero)
    )
  ])
}

#Preview {
//  NavigationStack {
    MemoryListView(
      store: Store(
        initialState: .preview,
        reducer: { MemoryList() }
      )
    )
//  }
}

#endif
