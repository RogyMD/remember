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
      return .run { [openURL] _ in await openURL(AppConfig.writeReviewURL) }
    case .learnMoreRowTapped:
      return .run { [openURL] _ in await openURL(AppConfig.homeURL) }
    case .appSettingsTapped:
      return .run { [openURL] _ in await openURL(URL(string: UIApplication.openSettingsURLString)!) }
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
      Button {
        store.send(.appSettingsTapped)
      } label: {
        Label("Open Remember Settings", systemImage: "gear")
      }
      
      Section("🫶 Thank You for Helping Remember") {
        Button {
          store.send(.writeReviewRowTapped)
        } label: {
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
        
        
        Button {
          store.send(.learnMoreRowTapped)
        } label: {
          Label("Learn more", systemImage: "graduationcap.fill")
            .foregroundStyle(Color(uiColor: .systemGreen))
        }
      }
    }
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
