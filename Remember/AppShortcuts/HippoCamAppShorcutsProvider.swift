import AppIntents

public struct HippoCamAppShorcutsProvider: AppShortcutsProvider {
  public static var shortcutTileColor: ShortcutTileColor { .blue }
  @AppShortcutsBuilder
  public static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: OpenMemoryItemAppIntent(),
      phrases: [
        "Show in \(.applicationName)",
        "Show \(\.$item) in \(.applicationName)",
        "Show me \(\.$item) in \(.applicationName)",
        "Show my \(\.$item) in \(.applicationName)",
        "Show the \(\.$item) in \(.applicationName)",
        "Show me the \(\.$item) in \(.applicationName)",
        "Reveal in \(.applicationName)",
        "Reveal \(\.$item) in \(.applicationName)",
        "Reveal my \(\.$item) in \(.applicationName)",
        "Reveal the \(\.$item) in \(.applicationName)",
        "Open \(\.$item) in \(.applicationName)",
        "Open the \(\.$item) in \(.applicationName)",
        "Open my \(\.$item) in \(.applicationName)",
        "Where’s my \(\.$item) in \(.applicationName)",
        "Where’s the \(\.$item) in \(.applicationName)",
        "Where’s \(\.$item) in \(.applicationName)",
        "Where is my \(\.$item) in \(.applicationName)",
        "Where is the \(\.$item) in \(.applicationName)",
        "Where is \(\.$item) in \(.applicationName)",
      ],
      shortTitle: "Show Memory with Item",
      systemImageName: "photo"
    )
    
    AppShortcut(
      intent: CreateMemoryFromFileIntent(),
      phrases: [
        "Import to \(.applicationName)",
        "Import image to \(.applicationName)",
        "Import an image to \(.applicationName)",
        "Import the image to \(.applicationName)",
        "Import a file to \(.applicationName)",
        "Import file to \(.applicationName)",
        "Create a memory in \(.applicationName)",
        "Save with \(.applicationName)",
        "Save in \(.applicationName)",
      ],
      shortTitle: "Import in HippoCam",
      systemImageName: "photo.badge.arrow.down"
    )
  }
}
