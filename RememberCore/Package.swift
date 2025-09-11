// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RememberCore",
    platforms: [
      .iOS(.v18),
    ],
    products: [
        .library(name: "RememberCore", targets: ["RememberCore"]),
        .library(name: "RememberSharedKeys", targets: ["RememberSharedKeys"]),
        // Features
        .library(name: "CameraView", targets: ["CameraView"]),
        .library(name: "MemoryItemPickerFeature", targets: ["MemoryItemPickerFeature"]),
        .library(name: "MemoryFormFeature", targets: ["MemoryFormFeature"]),
        .library(name: "MemoryTagsPickerFeature", targets: ["MemoryTagsPickerFeature"]),
        .library(name: "MemoryListFeature", targets: ["MemoryListFeature"]),
        .library(name: "RememberCameraFeature", targets: ["RememberCameraFeature"]),
        .library(name: "SearchMemoryFeature", targets: ["SearchMemoryFeature"]),
        .library(name: "HomeFeature", targets: ["HomeFeature"]),
        .library(name: "SettingsFormFeature", targets: ["SettingsFormFeature"]),
        .library(name: "BuyMeTeaFeature", targets: ["BuyMeTeaFeature"]),
//        .library(name: "Localized", targets: ["Localized"]),
        
        // Clients
        .library(name: "LocationClient", targets: ["LocationClient"]),
        .library(name: "DatabaseClient", targets: ["DatabaseClient"]),
        .library(name: "MapsAppURLClient", targets: ["MapsAppURLClient"]),
        .library(name: "RequestStoreReview", targets: ["RequestStoreReview"]),
        .library(name: "SharingKeys", targets: ["SharingKeys"]),
        .library(name: "FileClient", targets: ["FileClient"]),
        .library(name: "TextRecognizerClient", targets: ["TextRecognizerClient"]),
        .library(name: "FeedbackGenerator", targets: ["FeedbackGenerator"]),
        .library(name: "SpotlightClient", targets: ["SpotlightClient"]),
    ],
    dependencies: [
      .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.19.1"),
      .package(url: "https://github.com/RogyMD/ZoomableImage", exact: "1.0.1"),
      .package(url: "https://github.com/pointfreeco/swift-navigation", exact: "2.4.2"),
//      .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.5.2"),
//      .package(url: "https://github.com/pointfreeco/swift-issue-reporting", from: "1.5.2"),
      //    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.15.3"),
      //        .package(url: "https://github.com/apple/swift-async-algorithms", exact: "1.0.0"),  // AsyncAlgorithms
    ],
    targets: [
        .target(
            name: "RememberCore",
            dependencies: [
              .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
//              "CameraTimerRecognizer",
            ]),
          .target(
            name: "RememberSharedKeys",
            dependencies: [
              .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
//              "CameraTimerRecognizer",
            ]),
        .target(
            name: "BuyMeTeaFeature",
            dependencies: [
              .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
              "RememberSharedKeys",
            ],
        ),
//        .target(
//            name: "AppStoreClient",
//            dependencies: [
//              .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
//            ]),
        .testTarget(
            name: "RememberCoreTests",
            dependencies: ["RememberCore"]
        ),
        .target(
          name: "CameraView",
          dependencies: [
//            .product(name: "IssueReporting", package: "swift-issue-reporting"),
          ],
          resources: []
        ),
        .target(
          name: "MemoryItemPickerFeature",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            .product(name: "ZoomableImage", package: "ZoomableImage"),
            "RememberCore",
            "TextRecognizerClient",
            "RememberSharedKeys",
            "FeedbackGenerator",
          ]
        ),
        .target(
          name: "MemoryFormFeature",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            "RememberCore",
            "MemoryItemPickerFeature",
            "LocationClient",
            "MemoryTagsPickerFeature",
            "MapsAppURLClient",
            "BuyMeTeaFeature",
          ]
        ),
        .target(
          name: "MemoryTagsPickerFeature",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            "RememberCore",
            "DatabaseClient",
          ]
        ),
        .target(
          name: "MemoryListFeature",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            "RememberCore",
            "MemoryFormFeature",
            "DatabaseClient",
          ]
        ),
        .target(
          name: "SearchMemoryFeature",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            "RememberCore",
            "MemoryListFeature",
            "DatabaseClient",
          ]
        ),
        .target(
          name: "RememberCameraFeature",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            "RememberCore",
            "CameraView",
          ]
        ),
        .target(
          name: "SettingsFormFeature",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            "RememberCore",
            "DatabaseClient",
            "FileClient",
            "BuyMeTeaFeature",
          ]
        ),
        .target(
          name: "HomeFeature",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            "RememberCore",
            "MemoryFormFeature",
            "MemoryListFeature",
            "DatabaseClient",
            "SearchMemoryFeature",
            "RequestStoreReview",
            "SharingKeys",
            "SettingsFormFeature",
          ]
        ),
        // MARK: Clients
        .target(
          name: "LocationClient",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
          ]
        ),
        .target(
          name: "MapsAppURLClient",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
          ]
        ),
        .target(
          name: "RequestStoreReview",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
          ]
        ),
        .target(
          name: "SharingKeys",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
          ]
        ),
        .target(
          name: "DatabaseClient",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            "RememberCore",
            "FileClient",
          ],
          resources: [.copy("README.txt")]
        ),
        .target(
          name: "FileClient",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
          ]
        ),
        .target(
          name: "TextRecognizerClient",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
          ]
        ),
        .target(
          name: "FeedbackGenerator",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
          ]
        ),
        .target(
          name: "SpotlightClient",
          dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
          ]
        ),
//    .target(
//          name: "Localized",
//          dependencies: [],
//          resources: [.copy("Resources/Localizable.xcstrings")]
//        ),
    ]
)
