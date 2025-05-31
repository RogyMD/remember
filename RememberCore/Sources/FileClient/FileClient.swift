import Dependencies
import DependenciesMacros

@DependencyClient
public struct FileClient: Sendable {
  @DependencyEndpoint
  public var save: @Sendable (<#params#>) <#async#> <#throws#> -> <#Void#> = { <#_ in#> }
}

extension DependencyValues {
  public var FileClient: FileClient {
    get { self[FileClient.self] }
    set { self[FileClient.self] = newValue }
  }
}

extension FileClient: TestDependencyKey {
  public static let testValue = Self()
}

// MARK: - Live

extension FileClient: DependencyKey {
  public static let liveValue: Self = Self(<#api#>: <#value#>)
}
