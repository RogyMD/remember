//
//  ContentView.swift
//  Remember
//
//  Created by Igor Bidiniuc on 14/03/2025.
//

import SwiftUI
import CameraView
import MemoryItemPickerFeature
import ComposableArchitecture
import MemoryFormFeature
import MemoryListFeature

public struct CapturedImage: Equatable, Identifiable {
  public var id: CGPoint { point }
  let image: UIImage
  let point: CGPoint
}

@Reducer
public struct Demo {
  @ObservableState
  public struct State: Equatable {
    var memoryList: MemoryList.State
    var memoryForm: MemoryForm.State?
//    @Presents var <#attribute#>: <#State#>?
    init(memoryList: MemoryList.State, memoryForm: MemoryForm.State? = nil) {
      self.memoryList = memoryList
      self.memoryForm = memoryForm
    }
    public init() {
      self.init(memoryList: .init())
    }
  }
  
  @CasePathable
//  public enum Action: Equatable, BindableAction {
  public enum Action: Equatable {
//    case binding(BindingAction<State>)
    case capturedImage(CapturedImage)
    case memoryForm(MemoryForm.Action)
    case memoryList(MemoryList.Action)
  }
  
  public init() {}
  
    public var body: some ReducerOf<Self> {
//      BindingReducer()
      
      Scope(state: \.memoryList, action: \.memoryList) {
        MemoryList()
      }
      
      Reduce { state, action in
        switch action {
        case .memoryForm(.doneButtonTapped):
          let memory = state.memoryForm?.memory
          state.memoryForm = nil
          return memory.map({ .send(.memoryList(.addMemory($0))) }) ?? .none
        case .capturedImage(let image):
//          state.memoryForm = .init(
//            memory: .init(
//            id: UUID().uuidString,
//            items: [.init(id: UUID().uuidString, name: "", center: image.point)],
//            tags: [],
//            location: nil
//          ),
//                                   isNew: true)
          return .none
        case .memoryForm, .memoryList:
          return .none
        }
      }
      .ifLet(\.memoryForm, action: \.memoryForm) {
        MemoryForm()
          }
    }
  
//  private func <#action#>Action(_ action: Action.<#Action#>, state: inout State) -> EffectOf<Self> {
//    switch action {
//    case .<#action#>:
//      return .none
//    }
//  }
}

struct ContentView: View {
  @State var timeInterval: TimeInterval = .zero
  @State var image: CapturedImage?
  @Bindable var store: StoreOf<Demo> = Store(initialState: .init()) {
    Demo()
  }
  @State var detent: PresentationDetent = .fraction(0.12)
  @State var isPresented: Bool = true
  
  var body: some View {
    ZStack {
      IfLetStore(store.scope(state: \.memoryForm, action: \.memoryForm)) { store in
        NavigationStack {
          MemoryFormView(store: store)
          .transition(.opacity)
        }
      } else: {
        CameraView { image, point in
          let center = CGPoint(x: point.x * UIScreen.main.bounds.width, y: point.y * UIScreen.main.bounds.height - 64)
//          store.send(.capturedImage(.init(image: .init(uiImage: image), point: center)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
      }
      
      MemoryListView(store: store.scope(state: \.memoryList, action: \.memoryList))
        .background(.regularMaterial)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: .cornerRadius, topTrailingRadius: .cornerRadius))
        .zIndex(1)
//        .offset(.init(width: .zero, height: 500))
    }
  }
}


//struct ContentView: View {
//    @Environment(\.modelContext) private var modelContext
//    @Query private var items: [Item]
//
//    var body: some View {
//        NavigationSplitView {
//            List {
//                ForEach(items) { item in
//                    NavigationLink {
//                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
//                    } label: {
//                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
//                    }
//                }
//                .onDelete(perform: deleteItems)
//            }
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    EditButton()
//                }
//                ToolbarItem {
//                    Button(action: addItem) {
//                        Label("Add Item", systemImage: "plus")
//                    }
//                }
//            }
//        } detail: {
//            Text("Select an item")
//        }
//    }
//
//    private func addItem() {
//        withAnimation {
//            let newItem = Item(timestamp: Date())
//            modelContext.insert(newItem)
//        }
//    }
//
//    private func deleteItems(offsets: IndexSet) {
//        withAnimation {
//            for index in offsets {
//                modelContext.delete(items[index])
//            }
//        }
//    }
//}
//
//#Preview {
//    ContentView()
//        .modelContainer(for: Item.self, inMemory: true)
//}
