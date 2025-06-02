import Dependencies
import DependenciesMacros

@DependencyClient
public struct <#Example#>: Sendable {
  @DependencyEndpoint
  public var <#api#>: @Sendable (<#params#>) <#async#> <#throws#> -> <#Void#>
}

extension DependencyValues {
  public var <#Example#>: <#Example#> {
    get { self[<#Example#>.self] }
    set { self[<#Example#>.self] = newValue }
  }
}

extension <#Example#>: TestDependencyKey {
  public static let testValue = Self()
}

// MARK: - Live

extension <#Example#>: DependencyKey {
  public static let liveValue: Self = Self(<#api#>: <#value#>)
}
