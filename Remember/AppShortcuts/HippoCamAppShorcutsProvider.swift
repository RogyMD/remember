import AppIntents

public struct HippoCamAppShorcutsProvider: AppShortcutsProvider {
  @AppShortcutsBuilder
  public static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: OpenMemoryAppIntent(),
      phrases: [
        "Find \(\.$memory) in \(.applicationName)",
        "Find my \(\.$memory) in \(.applicationName)",
        "Look for \(\.$memory) in \(.applicationName)",
        "Look for my \(\.$memory) in \(.applicationName)",
        "Look up my \(\.$memory) in \(.applicationName)",
        "Look up \(\.$memory) in \(.applicationName)",
        "Show my \(\.$memory) in \(.applicationName)",
        "Show me \(\.$memory) in \(.applicationName)",
        "Show me where last time I put \(\.$memory) in \(.applicationName)",
        "Show the memory of \(\.$memory) in \(.applicationName)",
        "Where’s my \(\.$memory) in \(.applicationName)",
        "Where’s the \(\.$memory) in \(.applicationName)",
        "Where’s \(\.$memory) in \(.applicationName)"
      ],
      shortTitle: "Show memory details",
      systemImageName: "info.circle"
    )
  }
}
