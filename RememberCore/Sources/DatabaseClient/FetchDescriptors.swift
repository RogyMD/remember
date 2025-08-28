import Foundation
import SwiftData

extension FetchDescriptor where T == MemoryModel {
  static func descriptor(
    predicate: Predicate<T>? = nil,
    sortBy: [SortDescriptor<T>] = []
  ) -> Self {
    var descriptor = FetchDescriptor(predicate: predicate, sortBy: sortBy)
    descriptor.relationshipKeyPathsForPrefetching = [\.items, \.tags, \.location]
    descriptor.propertiesToFetch = [\.id, \.created, \.modified, \.notes]
    return descriptor
  }
  
  static var memories: Self {
    descriptor(sortBy: [
      SortDescriptor(\.created, order: .reverse),
    ])
  }
  
  static func memory(id: String) -> Self {
    descriptor(
      predicate: #Predicate { memory in
        memory.id == id
      }
    )
  }
  
  static func memories(itemId: String) -> Self {
    descriptor(
      predicate: #Predicate { memory in
        memory.items.contains(where: { item in
          item.id == itemId
        })
      }
    )
  }
  
  static func searchMemoriesWithItems(itemName: String) -> Self {
    descriptor(
      predicate: #Predicate { memory in
        memory.items.contains(where: { item in
          item.name.localizedStandardContains(itemName)
        })
      }
    )
  }
  
  static func search(_ query: String) -> Self {
    let regex = try! NSRegularExpression(pattern: "\\p{L}+", options: [])
    let range = NSRange(query.startIndex..<query.endIndex, in: query)
    let words: [String] = regex.matches(in: query, options: [], range: range).compactMap {
      guard let range = Range($0.range, in: query) else {
        return nil
      }
      return String(query[range]).lowercased()
    }
    let perWordPredicates: [Predicate<MemoryModel>] = words.map { word in
      #Predicate<MemoryModel> { memory in
        memory.tags.contains(where: { tag in
          tag.label.localizedStandardContains(word)
        }) ||
        memory.items.contains(where: { item in
          item.name.localizedStandardContains(word)
        }) ||
        memory.notes.localizedStandardContains(word) ||
        memory.recognizedText?.text.localizedStandardContains(word) ?? false
      }
    }
    // searching if the query is included in any of the properties
    let basePredicate: Predicate<MemoryModel> = #Predicate { memory in
      memory.tags.contains(where: { item in
        item.label.localizedStandardContains(query)
      }) ||
      memory.items.contains(where: { item in
        item.name.localizedStandardContains(query)
      }) ||
      memory.notes.localizedStandardContains(query)
    }
    // Now combine with AND (all words must match somewhere)
    let searchPredicate: Predicate<MemoryModel>? = perWordPredicates.reduce(nil) { acc, next in
      if let acc {
        #Predicate { memory in
          acc.evaluate(memory) && next.evaluate(memory)
        } as Predicate<MemoryModel>
      } else {
        next
      }
    }
    // combine the sum of results
    let combinedPredicate: Predicate<MemoryModel> = {
      if let searchPredicate {
        return #Predicate<MemoryModel> { memory in
          basePredicate.evaluate(memory) || searchPredicate.evaluate(memory)
        }
      } else {
        return basePredicate
      }
    }()
    
    return descriptor(
      predicate: combinedPredicate,
      sortBy: [
        SortDescriptor(\.created, order: .reverse),
      ]
    )
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
