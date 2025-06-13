import ComposableArchitecture
import RememberCore
import SwiftUI

@Reducer
public struct SettingsForm {
  public struct State: Equatable {
    public init() {}
  }
  
  @CasePathable
  public enum Action: Equatable {
    case writeReviewRowTapped
    case learnMoreRowTapped
    case closeButtonTapped
    case appSettingsTapped
  }
  
  @Dependency(\.openURL) var openURL
  @Dependency(\.dismiss) var dismiss
  
  public init() {}
  
  public func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .writeReviewRowTapped:
      return .none
    case .learnMoreRowTapped:
      return .none
    case .appSettingsTapped:
      return .none
    case .closeButtonTapped:
      return .run { [dismiss] _ in await dismiss() }
    }
  }
}


// MARK: - SettingsFormView

public struct SettingsFormView: View {
  let store: StoreOf<SettingsForm>
  
  public init(store: StoreOf<SettingsForm>) {
    self.store = store
  }
  
  public var body: some View {
    Form {
      Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
        Label("Open Remember Settings", systemImage: "gear")
      }
      .listRowBackground(Color.clear.background(.thinMaterial))
      
      Section("🫶 Thank You for Helping Remember") {
        Link(destination: AppConfig.writeReviewURL) {
          Label("Write a Review", systemImage: "star.fill")
            .foregroundStyle(Color(uiColor: .systemYellow))
        }
        
        ShareLink(
          item: AppConfig.appStoreURL,
          subject: Text("Download Remember on the App Store"),
          message: Text("Here’s the link to download Remember, the Brain Add-On I was telling you about!")
        ) {
          Label("Spread the Word", systemImage: "megaphone.fill")
            .symbolRenderingMode(.multicolor)
        }
        
        Link(destination: AppConfig.homeURL) {
          Label("Learn more", systemImage: "graduationcap.fill")
            .foregroundStyle(Color(uiColor: .systemGreen))
        }
      }
      .listRowBackground(Color.clear.background(.thinMaterial))
    }
    .scrollContentBackground(.hidden)
    .navigationTitle("Settings")
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Close") {
          store.send(.closeButtonTapped)
        }
      }
    }
  }
}

#if DEBUG

// MARK: Previews

public extension SettingsForm.State {
  @MainActor
  static let preview = Self()
}

#Preview {
  NavigationStack {
    SettingsFormView(
      store: Store(
        initialState: .preview,
        reducer: { SettingsForm() }
      )
    )
  }
}

#endif
