import AppIntents
import ComposableArchitecture
import RememberCore

struct OpenMemoryItemAppIntent: AppIntent {
  static var title: LocalizedStringResource = "Show Memory with Item"
  static var description = IntentDescription("Shows details of the memory containing the item in HippoCam.")
  static var parameterSummary: some ParameterSummary {
    Summary("Show the memory containing \(\.$item)")
  }
  static var openAppWhenRun = true
  
  @Parameter(title: "Saved Item")
  var item: MemoryItemAppEntity
  
  let store = MainApp.mainStore
  
  func perform() async throws -> some IntentResult & ProvidesDialog {
    await store.send(.openMemoryWithItem(item.id))
    return .result(dialog: "\(item.title ?? item.subtitle) is here")
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
