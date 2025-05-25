import Foundation
import SwiftData

extension FetchDescriptor where T == MemoryModel {
  static func descriptor(
    predicate: Predicate<T>? = nil,
    sortBy: [SortDescriptor<T>] = []
  ) -> Self {
    var descriptor = FetchDescriptor(predicate: predicate, sortBy: sortBy)
    descriptor.relationshipKeyPathsForPrefetching = [\.items, \.tags, \.location]
    descriptor.propertiesToFetch = [\.id, \.created, \.modified]
    return descriptor
  }
  
  static var memories: Self {
    descriptor(sortBy: [
      SortDescriptor(\.created, order: .reverse),
    ])
  }
  
  static func search(_ query: String) -> Self {
    descriptor(
      predicate: #Predicate { memory in
        memory.tags.contains(where: { item in
          item.label.localizedStandardContains(query)
        }) ||
        memory.items.contains(where: { item in
          item.name.localizedStandardContains(query)
        }) ||
        memory.notes.localizedStandardContains(query)
      },
      sortBy: [
        SortDescriptor(\.created, order: .reverse),
      ])
  }
}

extension FetchDescriptor where T == ItemModel {
  static func descriptor(
    predicate: Predicate<T>? = nil,
    sortBy: [SortDescriptor<T>] = []
  ) -> Self {
    var descriptor = FetchDescriptor(predicate: predicate, sortBy: sortBy)
    descriptor.relationshipKeyPathsForPrefetching = [\.memory]
    descriptor.propertiesToFetch = [\.id, \.created, \.modified]
    return descriptor
  }
  
  static var items: Self {
    descriptor()
  }
}

extension FetchDescriptor where T == TagModel {
  static func descriptor(
    predicate: Predicate<T>? = nil,
    sortBy: [SortDescriptor<T>] = []
  ) -> Self {
    var descriptor = FetchDescriptor(predicate: predicate, sortBy: sortBy)
    descriptor.relationshipKeyPathsForPrefetching = [\.memories]
    descriptor.propertiesToFetch = [\.label]
    return descriptor
  }
  
  static var tags: Self {
    descriptor(sortBy: [
      SortDescriptor(\.label),
    ])
  }
}
