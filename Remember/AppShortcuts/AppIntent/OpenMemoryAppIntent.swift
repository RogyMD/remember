import AppIntents
import ComposableArchitecture
import RememberCore

public struct OpenMemoryAppIntent: AppIntent {
  public static var title: LocalizedStringResource = "Show Memory Details"
  public static var description = IntentDescription("Shows Memory Details in HippoCam")
  public static var parameterSummary: some ParameterSummary {
    Summary("Show details of the memory with \(\.$memory)")
  }
  public static var openAppWhenRun = true
  public static var isDiscoverable = true
  
  @Parameter(title: "Memory")
  public var memory: MemoryAppEntity
  let store = MainApp.mainStore
  public init(memory: IntentParameter<MemoryAppEntity>) {
    _memory = memory
  }
  
  public init() {
  }
  
  @MainActor
  public func perform() async throws -> some IntentResult & ProvidesDialog {
    store.send(.openMemory(memory.id))
    return .result(dialog: "Here is \(memory.title)")
  }
}

extension Memory {
  var appIntent: OpenMemoryAppIntent {
    let parameter = IntentParameter<MemoryAppEntity>(
      title: .init(stringLiteral: self.displayTitle)
    )
    parameter.wrappedValue = .init(memory: self)
    return .init(memory: parameter)
  }
}
