import SwiftGodot

// Item database singleton - holds all item definitions
// This is registered as an autoload in Godot
@Godot
public class ItemDatabase: Node {
    // Singleton accessor - Godot manages threading
    nonisolated(unsafe) public static var shared: ItemDatabase!

    private var items: [String: Item] = [:]

    public override func _ready() {
        ItemDatabase.shared = self
        loadItems()
    }

    public func getItem(_ itemId: String) -> Item? {
        return items[itemId]
    }

    public func hasItem(_ itemId: String) -> Bool {
        return items[itemId] != nil
    }

    public func getAllItems() -> [String: Item] {
        return items
    }

    private func loadItems() {
        createSampleItems()
    }

    private func createSampleItems() {
        // Load placeholder icon
        let placeholderIcon = GD.load(path: "res://icon.svg") as? Texture2D

        // Basic sword
        let ironSword = Item(
            id: "iron_sword",
            name: "Iron Sword",
            description: "A sturdy iron sword. Good for combat.",
            stackable: false,
            maxStack: 1,
            itemType: .weapon,
            rarity: .common,
            value: 50
        )
        ironSword.icon = placeholderIcon
        items[ironSword.id] = ironSword

        // Health potion
        let healthPotion = Item(
            id: "health_potion",
            name: "Health Potion",
            description: "Restores health when consumed.",
            stackable: true,
            maxStack: 10,
            itemType: .consumable,
            rarity: .common,
            value: 25
        )
        healthPotion.icon = placeholderIcon
        items[healthPotion.id] = healthPotion

        // Leather armor
        let leatherArmor = Item(
            id: "leather_armor",
            name: "Leather Armor",
            description: "Basic protection made from leather.",
            stackable: false,
            maxStack: 1,
            itemType: .armor,
            rarity: .uncommon,
            value: 75
        )
        leatherArmor.icon = placeholderIcon
        items[leatherArmor.id] = leatherArmor

        // Magic gem
        let magicGem = Item(
            id: "magic_gem",
            name: "Magic Gem",
            description: "A mysterious gem that glows with inner light.",
            stackable: true,
            maxStack: 5,
            itemType: .misc,
            rarity: .rare,
            value: 200
        )
        magicGem.icon = placeholderIcon
        items[magicGem.id] = magicGem

        // Pickaxe tool
        let ironPickaxe = Item(
            id: "iron_pickaxe",
            name: "Iron Pickaxe",
            description: "A mining tool for gathering resources.",
            stackable: false,
            maxStack: 1,
            itemType: .tool,
            rarity: .common,
            value: 100
        )
        ironPickaxe.icon = placeholderIcon
        items[ironPickaxe.id] = ironPickaxe
    }

    public func addItemToDatabase(_ item: Item) -> Bool {
        guard !item.id.isEmpty else {
            GD.pushError("Cannot add item with empty ID to database")
            return false
        }

        if items[item.id] != nil {
            GD.pushWarning("Item with ID '\(item.id)' already exists in database. Overwriting.")
        }

        items[item.id] = item
        return true
    }

    public func removeItemFromDatabase(_ itemId: String) -> Bool {
        if items[itemId] != nil {
            items.removeValue(forKey: itemId)
            return true
        }
        return false
    }
}
