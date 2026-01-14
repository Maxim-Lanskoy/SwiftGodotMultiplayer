import SwiftGodot

// All SwiftGodot classes that need to be registered with Godot
public let godotTypes: [Object.Type] = [
    // Singletons (autoloads)
    Network.self,
    ItemDatabase.self,

    // Gameplay classes
    Level.self,
    Character.self,
    Body.self,
    SpringArmCharacter.self,

    // UI classes
    MainMenuUI.self,
    MultiplayerChatUI.self,
    InventoryUI.self,
    InventorySlotUI.self,
]

#initSwiftExtension(cdecl: "swift_entry_point", types: godotTypes)
