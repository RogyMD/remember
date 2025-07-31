import Foundation
import SwiftData
import RememberCore
import FileClient
import Dependencies

@ModelActor
actor DatabaseService {
  static var shared: DatabaseService = DatabaseService(modelContainer: .appModelContainer)
  
  func fetch<T: PersistentModel, V>(
    _ descriptor: FetchDescriptor<T>,
    compactMap: (T) -> V?
  ) throws -> [V] {
    try modelContext.fetch(descriptor).compactMap(compactMap)
  }
  func fetchCount<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> Int {
    try modelContext.fetchCount(descriptor)
  }
  func hasMemories() throws -> Bool {
    try fetchCount(.memories) > .zero
  }
  func updateOrInsertMemory(_ memory: Memory) throws {
    guard let existingMemory = try existingMemory(id: memory.id) else {
      try insert(MemoryModel(memory))
      return
    }
    let oldLocation = existingMemory.location
    let oldRecognizedText = existingMemory.recognizedText
    existingMemory.update(memory)
    if let oldLocation, oldLocation != existingMemory.location {
      modelContext.delete(oldLocation)
    }
    if let oldRecognizedText, oldRecognizedText != existingMemory.recognizedText {
      modelContext.delete(oldRecognizedText)
    }
    try modelContext.save()
  }
  func updateItem(_ item: MemoryItem) throws {
    guard let existingItem = try existingItem(id: item.id) else {
      assertionFailure("Trying to update nonexisting item")
      return
    }
    existingItem.update(item)
    try modelContext.save()
  }
  func insertTag(_ tag: MemoryTag) throws {
    guard try existingTag(label: tag.label) == nil else { return }
    try insert(TagModel(tag))
  }
  func deleteMemory(id: String) throws {
    guard let model = try existingMemory(id: id) else { return }
    try delete(model)
  }
  func deleteItem(id: String) throws {
    guard let model = try existingItem(id: id) else { return }
    try delete(model)
  }
  
  func removeAllData() async throws {
    @Dependency(\.fileClient) var fileClient
    if #available(watchOS 11, iOS 18, *) {
      try modelContainer.erase()
    } else {
      modelContainer.deleteAllData()
    }
    try fileClient.removeItem(.memoryDirectory)
    ModelContainer.appModelContainer = try setupModelContainer(url: .storeURL)
    Self.shared = .init(modelContainer: .appModelContainer)
  }
  
  private func model<T: PersistentModel>(id: PersistentIdentifier) throws -> T? {
    try modelContext.existingModel(for: id)
  }
  func existingMemory(id: String) throws -> MemoryModel? {
    try modelContext.first(for: .init(predicate: #Predicate<MemoryModel> { $0.id == id }))
  }
  func existingItem(id: String) throws -> ItemModel? {
    try modelContext.first(for: .init(predicate: #Predicate<ItemModel> { $0.id == id }))
  }
  func existingTag(label: String) throws -> TagModel? {
    try modelContext.first(for: .init(predicate: #Predicate<TagModel> { $0.label == label }))
  }
  
  private func insert(_ model: any PersistentModel, save: Bool = true) throws {
    modelContext.insert(model)
    if save { try modelContext.save() }
  }
  
  private func delete(_ model: any PersistentModel & Identifiable) throws {
    modelContext.delete(model)
    try modelContext.save()
  }
}

extension MemoryModel {
  convenience init(_ memory: Memory) {
    self.init(
      id: memory.id,
      created: memory.created,
      modified: memory.modified,
      notes: memory.notes,
      isPrivate: memory.isPrivate,
      items: memory.items.map(ItemModel.init),
      tags: memory.tags.map(TagModel.init),
      location: memory.location.map(LocationModel.init),
      recognizedText: memory.recognizedText.map(RecognizedTextModel.init)
    )
  }
  
  func update(_ memory: Memory) {
    guard id == memory.id, modified != memory.modified else { return }
    modified = memory.modified
    isPrivate = memory.isPrivate
    notes = memory.notes
    let newItems = memory.items.map(ItemModel.init)
    let newRecognizedText = memory.recognizedText.map(RecognizedTextModel.init)
    let newTags = memory.tags.map(TagModel.init)
    let newLocation = memory.location.map(LocationModel.init)
    if location != newLocation {
      location = newLocation
    }
    if recognizedText != newRecognizedText {
      recognizedText = newRecognizedText
    }
    if newItems != items {
      let updatedItems = newItems.map { item in
        if let existing = items.first(where: { $0.id == item.id }), let memoryItem = memory.items[id: item.id] {
          existing.update(memoryItem)
          return existing
        } else {
          return item
        }
      }
      items.replaceSubrange(0..<items.count, with: updatedItems)
    }
    if newTags != tags {
      tags.replaceSubrange(0..<tags.count, with: newTags)
    }
  }
}

extension ItemModel {
  convenience init(_ item: MemoryItem) {
    self.init(
      id: item.id,
      name: item.name,
      center: .init(item.center)
    )
  }
  
  func update(_ item: MemoryItem) {
    let itemCenter = LabelPoint(item.center)
    guard id == item.id && (name != item.name || center != itemCenter) else { return }
    modified = Date()
    name = item.name
    center = itemCenter
  }
}

extension TagModel {
  convenience init(_ tag: MemoryTag) {
    self.init(label: tag.label)
  }
}

extension LocationModel {
  convenience init(_ location: MemoryLocation) {
    self.init(
      latitude: location.lat,
      longitude: location.long
    )
  }
}

extension RecognizedTextModel {
  convenience init(_ recognizedText: RecognizedText) {
    self.init(
      id: recognizedText.id,
      text: recognizedText.text,
      textFrames: recognizedText.textFrames.map(TextFrameModel.init)
    )
  }
}

extension TextFrameModel {
  convenience init(_ textFrame: TextFrame) {
    self.init(
      text: textFrame.text,
      frame: textFrame.frame
    )
  }
}
