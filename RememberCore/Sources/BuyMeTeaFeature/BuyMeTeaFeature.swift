import ComposableArchitecture
import SwiftUI
import StoreKit
import OSLog
import UIKit
import RememberSharedKeys

@Reducer
public struct BuyMeTea {
  @ObservableState
  public struct State: Equatable {
    @Shared(.isTeaPurchased) var isTeaPurchased
    public var isPurchased: Bool = false
    public var taskState: ProductTaskState
    public init(isPurchased: Bool = false, taskState: ProductTaskState = .loading) {
      self.isPurchased = isPurchased
      self.taskState = taskState
      if isTeaPurchased {
        self.isPurchased = true
      }
    }
  }
  
  @CasePathable
  public enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case inAppPurchaseStarted(Product)
    case inAppPurchaseCompleted(Product, ProductPurchaseResult)
    case productStateChaged(ProductTaskState)
    case onAppear
  }
  
  public init() {}
  
    public var body: some ReducerOf<Self> {
      BindingReducer()
      Reduce { state, action in
        switch action {
        case .productStateChaged(let taskState):
          return .run { [isTeaPurchased = state.$isTeaPurchased] send in
            defer {
              DispatchQueue.main.async {
                send(.set(\.taskState, taskState), animation: .bouncy(extraBounce: 0.3))
              }
            }
            guard let product = taskState.product else {
              await send(.set(\.isPurchased, false))
              return
            }
            guard let result = await product.latestTransaction else {
              await send(.set(\.isPurchased, false))
              return
            }
            switch result {
            case .unverified(_, let verificationError):
              logger.fault("Verification Failed. Error: \(String(describing: verificationError))")
              await send(.set(\.isPurchased, false))
            case .verified:
              isTeaPurchased.withLock { $0 = true }
              await send(.set(\.isPurchased, true), animation: .bouncy(extraBounce: 0.3))
            }
          }
        case .binding, .onAppear, .inAppPurchaseStarted:
          return .none
        case .inAppPurchaseCompleted(_, let result):
          let isPurchased = result == .succes
          return .run { [isTeaPurchased = state.$isTeaPurchased] send in
            isTeaPurchased.withLock { $0 = isPurchased }
            await send(.set(\.isPurchased, isPurchased), animation: .bouncy(extraBounce: 0.3))
          }
        }
      }
    }
}

public let BuyMeTeaProductId = "app.rogy.remember.buymetea1"

@CasePathable
public enum ProductTaskState: Equatable, Sendable {
  case loading
  case failed
  case product(Product)
  
  var product: Product? {
    switch self {
    case .failed, .loading: nil
    case .product(let product): product
    }
  }
  
  init(_ state: Product.TaskState) {
    switch state {
    case .loading:
      self = .loading
    case .unavailable, .failure:
      self = .failed
    case .success(let product):
      self = .product(product)
    @unknown default:
      self = .failed
    }
  }
}

public enum ProductPurchaseResult: Sendable {
  case succes
  case userCancalled
  case failed
  init(_ result: Result<Product.PurchaseResult, Error>) {
    switch result {
    case .success(let success):
      switch success {
      case .success, .pending:
        self = .succes
      case .userCancelled:
        self = .userCancalled
      @unknown default:
        self = .succes
      }
    case .failure:
      self = .failed
    }
  }
}


// MARK: - BuyMeTeaView

public struct BuyMeTeaView: View {
  @State private var heartScale: CGFloat = 1
  
  @Bindable var store: StoreOf<BuyMeTea>

  public init(store: StoreOf<BuyMeTea>) {
    self.store = store
  }
  
  public var body: some View {
    Group {
      if store.isPurchased == false {
        productView
      } else {
        thankYouView
      }
    }
    .onAppear {
      store.send(.onAppear)
    }
  }
  
  var thankYouView: some View {
    HStack {
      Spacer()
      VStack(alignment: .center) {
        Text("Thank You!\nYou're Awesome!")
          .lineLimit(nil)
        Text("❤️")
          .font(.system(size: 45 * heartScale))
      }
      Spacer()
    }
    .animation(.bouncy(extraBounce: 0.3), value: heartScale)
    .font(.title)
    .multilineTextAlignment(.center)
    .font(.largeTitle)
    .onTapGesture {
      let increment: CGFloat = {
        switch heartScale {
        case ..<2: return 0.1
        case ..<4: return 0.05
        case ..<6: return 0.01
        case ..<8: return 0.05
        default:   return 0
        }
      }()
      heartScale += increment
      UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
  }
  
  var productView: some View {
    ProductView(id: BuyMeTeaProductId) {
      buyMeTeaIconPurchased
    }
    .productViewStyle(.regular)
    .storeProductTask(for: BuyMeTeaProductId) { state in
      store.send(.productStateChaged(.init(state)))
    }
    .onInAppPurchaseStart { product in
      store.send(.inAppPurchaseStarted(product))
    }
    .onInAppPurchaseCompletion { product, result in
      store.send(.inAppPurchaseCompleted(product, .init(result)))
    }
  }
  
  var buyMeTeaIconPurchased: some View {
    Image(systemName: "cup.and.heat.waves.fill")
      .symbolRenderingMode(.palette)
      .resizable()
      .scaledToFit()
      .foregroundStyle(Color(uiColor: .label), Color.accentColor)
      .padding()
      .background {
        Circle()
          .fill(Material.thin)
          .background { Circle().fill(Color.accentColor) }
      }
  }
}

//extension BuyMeTeaView {
//  var a11yID: A11yID { .ids }
//  struct A11yID {
//    static let ids = A11yID()
//    let main: String
//    <#let cancelButton: String#>
//    <#let function: (String) -> String#>
//    in
//  }
//}

private let logger = Logger(
    subsystem: "Remember",
    category: "BuyMeTea"
)

#if DEBUG

// MARK: Previews

public extension BuyMeTea.State {
  @MainActor
  static let preview = Self()
}

#Preview {
  BuyMeTeaView(
    store: Store(
      initialState: .preview,
      reducer: { BuyMeTea() }
    )
  )
}

#endif
