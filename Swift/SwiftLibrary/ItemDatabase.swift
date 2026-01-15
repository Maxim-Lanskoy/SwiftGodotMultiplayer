import SwiftGodot

/// Singleton database containing all item definitions.
///
/// This class is registered as an Engine singleton and provides centralized access
/// to item data throughout the game. Items are loaded at startup and can be
/// queried by their unique ID.
///
/// ## Usage
/// ```swift
/// if let sword = ItemDatabase.shared?.getItem("iron_sword") {
///     inventory.addItem(sword, quantity: 1)
/// }
/// ```
///
/// ## Registration
/// Configure as Godot Autoload in Project Settings.
@Godot
public class ItemDatabase: Node {
    // MARK: - Singleton

    /// Shared instance. Set when added as Godot Autoload.
    /// Use optional chaining for safe access: `ItemDatabase.shared?.getItem(...)`.
    nonisolated(unsafe) public static var shared: ItemDatabase?

    // MARK: - Private State

    private var items: [String: Item] = [:]

    // MARK: - Lifecycle

    public override func _ready() {
        ItemDatabase.shared = self
        loadItems()
        GD.print("ItemDatabase: Loaded \(items.count) items")
    }

    public override func _exitTree() {
        if ItemDatabase.shared === self {
            ItemDatabase.shared = nil
        }
    }

    // MARK: - Public API

    /// Retrieves an item by its unique ID.
    /// - Parameter itemId: The item's unique identifier.
    /// - Returns: The item if found, nil otherwise.
    public func getItem(_ itemId: String) -> Item? {
        return items[itemId]
    }

    /// Checks if an item exists in the database.
    /// - Parameter itemId: The item's unique identifier.
    /// - Returns: True if the item exists.
    public func hasItem(_ itemId: String) -> Bool {
        return items[itemId] != nil
    }

    /// Returns all items in the database.
    /// - Returns: Dictionary of all items keyed by ID.
    public func getAllItems() -> [String: Item] {
        return items
    }

    /// Adds a new item to the database.
    /// - Parameter item: The item to add.
    /// - Returns: True if added successfully.
    public func addItemToDatabase(_ item: Item) -> Bool {
        guard !item.id.isEmpty else {
            GD.pushError("ItemDatabase: Cannot add item with empty ID")
            return false
        }

        if items[item.id] != nil {
            GD.pushWarning("ItemDatabase: Item '\(item.id)' already exists, overwriting")
        }

        items[item.id] = item
        return true
    }

    /// Removes an item from the database.
    /// - Parameter itemId: The item's unique identifier.
    /// - Returns: True if the item was removed.
    public func removeItemFromDatabase(_ itemId: String) -> Bool {
        if items[itemId] != nil {
            items.removeValue(forKey: itemId)
            return true
        }
        return false
    }

    // MARK: - Private Methods

    private func loadItems() {
        createSampleItems()
    }

    private func createSampleItems() {
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
}
