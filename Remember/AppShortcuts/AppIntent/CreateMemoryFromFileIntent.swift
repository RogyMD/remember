import AppIntents
import UniformTypeIdentifiers

struct CreateMemoryFromFileIntent: AppIntent {
  static var title: LocalizedStringResource = "Save Image as Memory in Hippocam"
  static var description = IntentDescription("Imports an image into HippoCam and creates a memory.")
  static var openAppWhenRun: Bool = true
  
  @Parameter(title: "Image", supportedContentTypes: [.image])
  var file: IntentFile
  
  let store = MainApp.mainStore
  
  static var parameterSummary: some ParameterSummary {
    Summary("Create a memory from \(\.$file)")
  }
  
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let data = try await file.data(contentType: .image)
    await store.send(.createMemory(data))
    return .result(dialog: "Image has been imported. Feel free to add a label.")
  }
}
