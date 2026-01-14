import SwiftGodot

#initSwiftExtension(
    cdecl: "swift_entry_point",
    types: [
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
)
