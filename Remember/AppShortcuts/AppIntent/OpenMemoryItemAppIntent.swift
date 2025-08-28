import AppIntents
import ComposableArchitecture
import RememberCore

public struct OpenMemoryItemAppIntent: AppIntent {
  public static var title: LocalizedStringResource = "Show Memory with Item"
  public static var description = IntentDescription("Shows details of the memory containing the item in HippoCam.")
  public static var parameterSummary: some ParameterSummary {
    Summary("Show me \(\.$item) in HippoCam")
  }
  public static var openAppWhenRun = true
  public static var isDiscoverable = true
  
  @Parameter(title: "Memorised Item")
  public var item: MemoryItemAppEntity
  let store = MainApp.mainStore
  public init(item: IntentParameter<MemoryItemAppEntity>) {
    _item = item
  }
  
  public init() {
  }
  
  @MainActor
  public func perform() async throws -> some IntentResult & ProvidesDialog {
    store.send(.openMemoryWithItem(item.id))
    return .result(dialog: "Here is \(item.title)")
  }
}

extension MemoryItem {
  func appIntent(memory: Memory) -> OpenMemoryItemAppIntent {
    let parameter = IntentParameter<MemoryItemAppEntity>(
      title: .init(stringLiteral: self.name)
    )
    parameter.wrappedValue = .init(memory: memory, item: self)
    return .init(item: parameter)
  }
}
