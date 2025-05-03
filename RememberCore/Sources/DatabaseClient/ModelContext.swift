import Foundation
import SwiftData

extension ModelContext {
  func first<T>(for descriptor: FetchDescriptor<T>) throws -> T? {
    try fetch(descriptor).first
  }
  func existingModel<T: PersistentModel>(for objectID: PersistentIdentifier) throws -> T? {
    if let registered: T = registeredModel(for: objectID) {
      return registered
    }
    
    let fetchDescriptor = FetchDescriptor<T>(
      predicate: #Predicate { $0.persistentModelID == objectID })
    
    return try fetch(fetchDescriptor).first
  }
}
