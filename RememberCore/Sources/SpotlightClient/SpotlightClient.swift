import Dependencies
import DependenciesMacros
import CoreSpotlight
import OSLog

@DependencyClient
public struct SpotlightClient: Sendable {
  @DependencyEndpoint
  public var upsert: @Sendable ([CSSearchableItemAttributeSet]) async throws -> Void

  @DependencyEndpoint
  public var remove: @Sendable ([String]) async throws -> Void

  @DependencyEndpoint
  public var removeAll: @Sendable () async throws -> Void
}

extension DependencyValues {
  public var spotlightClient: SpotlightClient {
    get { self[SpotlightClient.self] }
    set { self[SpotlightClient.self] = newValue }
  }
}

extension SpotlightClient: TestDependencyKey {
  public static let testValue = Self()
}

// MARK: - Live

extension SpotlightClient: DependencyKey {
  public static let liveValue: Self = Self(
    upsert: { sets in
      let searchables = sets.map { set in
        CSSearchableItem(
          uniqueIdentifier: set.identifier,
          domainIdentifier: set.domainIdentifier,
          attributeSet: set
        )
      }
      try await CSSearchableIndex.default().indexSearchableItems(searchables)
#if DEBUG
      logger.debug("SpotlightClient indexed \(searchables.count) items")
#endif
    },
    remove: { ids in
      try await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: Array(ids))
#if DEBUG
      logger.debug("SpotlightClient removed \(ids.count) items")
#endif
    },
    removeAll: {
      try await CSSearchableIndex.default().deleteAllSearchableItems()
#if DEBUG
      logger.debug("SpotlightClient removed all items")
#endif
    }
  )
}

let logger = Logger(
  subsystem: "Remember.SpotlightClient",
  category: "Live"
)
