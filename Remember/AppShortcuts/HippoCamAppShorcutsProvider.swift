import AppIntents

public struct HippoCamAppShorcutsProvider: AppShortcutsProvider {
  @AppShortcutsBuilder
  public static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: OpenMemoryItemAppIntent(),
      phrases: [
        "Find \(\.$item) in \(.applicationName)",
        "Find in \(.applicationName)",
        "Show in \(.applicationName)",
        "Look up in \(.applicationName)",
        "Search in \(.applicationName)",
        "Open \(\.$item) in \(.applicationName)",
        "Open the \(\.$item) in \(.applicationName)",
        "Open my \(\.$item) in \(.applicationName)",
        "Find the \(\.$item) in \(.applicationName)",
        "Find my \(\.$item) in \(.applicationName)",
        "Look for \(\.$item) in \(.applicationName)",
        "Look for the \(\.$item) in \(.applicationName)",
        "Look for my \(\.$item) in \(.applicationName)",
        "Look up the \(\.$item) in \(.applicationName)",
        "Look up my \(\.$item) in \(.applicationName)",
        "Look up \(\.$item) in \(.applicationName)",
        "Show \(\.$item) in \(.applicationName)",
        "Show the \(\.$item) in \(.applicationName)",
        "Show my \(\.$item) in \(.applicationName)",
        "Show me \(\.$item) in \(.applicationName)",
        "Show me the \(\.$item) in \(.applicationName)",
        "Show me \(\.$item) in \(.applicationName)",
        "Show me where last time I put \(\.$item) in \(.applicationName)",
        "Show me where last time I put my \(\.$item) in \(.applicationName)",
        "Show me where last time I put the \(\.$item) in \(.applicationName)",
        "Show me where is \(\.$item) in \(.applicationName)",
        "Show me where is \(\.$item) in \(.applicationName)",
        "Show me where is \(\.$item) in \(.applicationName)",
        "Show the memory with \(\.$item) in \(.applicationName)",
        "Where’s my \(\.$item) in \(.applicationName)",
        "Where’s the \(\.$item) in \(.applicationName)",
        "Where’s \(\.$item) in \(.applicationName)",
        "Where is my \(\.$item) in \(.applicationName)",
        "Where is the \(\.$item) in \(.applicationName)",
        "Where is \(\.$item) in \(.applicationName)",
      ],
      shortTitle: "Show Memory with Item",
      systemImageName: "info.circle"
    )
  }
}
