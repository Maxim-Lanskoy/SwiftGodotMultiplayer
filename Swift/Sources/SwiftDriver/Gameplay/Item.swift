//
//  Item.swift
//  SwiftGodotMultiplayer
//
// Item data model with type (weapon/armor/consumable/tool/misc),
// rarity (common-legendary), stacking rules, and serialization.

import SwiftGodot

// MARK: - Item Type

/// Categories of items in the game.
public enum ItemType: Int, CaseIterable {
    case weapon = 0
    case armor = 1
    case consumable = 2
    case tool = 3
    case misc = 4
}

// MARK: - Item Rarity

/// Rarity levels for items, affecting value and appearance.
public enum ItemRarity: Int, CaseIterable {
    case common = 0
    case uncommon = 1
    case rare = 2
    case epic = 3
    case legendary = 4
}

// MARK: - Item

/// Item definition containing all properties for an item type.
///
/// This is a pure Swift data class used internally for item definitions.
/// Items are stored in `ItemDatabase` and referenced by ID in inventory slots.
public class Item {
    // MARK: - Properties

    /// Unique identifier for the item.
    public var id: String = ""
    /// Display name shown in UI.
    public var name: String = ""
    /// Description text shown in tooltips.
    public var itemDescription: String = ""
    /// Icon texture for UI display.
    public var icon: Texture2D?

    /// Whether multiple items can occupy the same slot.
    public var stackable: Bool = true
    /// Maximum quantity per stack (if stackable).
    public var maxStack: Int = 99

    /// Category of the item.
    public var itemType: ItemType = .misc
    /// Rarity level affecting UI color and value.
    public var rarity: ItemRarity = .common
    /// Base gold value for trading.
    public var value: Int = 0

    // MARK: - Initialization

    /// Creates an empty item.
    public init() {}

    /// Creates an item with the specified properties.
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - name: Display name.
    ///   - description: Tooltip description.
    ///   - stackable: Whether items can stack.
    ///   - maxStack: Maximum stack size.
    ///   - itemType: Item category.
    ///   - rarity: Rarity level.
    ///   - value: Base gold value.
    public init(id: String, name: String, description: String = "", stackable: Bool = true, maxStack: Int = 99, itemType: ItemType = .misc, rarity: ItemRarity = .common, value: Int = 0) {
        self.id = id
        self.name = name
        self.itemDescription = description
        self.stackable = stackable
        self.maxStack = maxStack
        self.itemType = itemType
        self.rarity = rarity
        self.value = value
    }

    // MARK: - Serialization

    /// Converts the item to a dictionary for network transmission.
    /// - Returns: A VariantDictionary containing all item properties.
    public func toDict() -> VariantDictionary {
        let dict = VariantDictionary()
        dict["id"] = Variant(id)
        dict["name"] = Variant(name)
        dict["description"] = Variant(itemDescription)
        dict["stackable"] = Variant(stackable)
        dict["max_stack"] = Variant(maxStack)
        dict["item_type"] = Variant(itemType.rawValue)
        dict["rarity"] = Variant(rarity.rawValue)
        dict["value"] = Variant(value)
        return dict
    }

    /// Populates item properties from a dictionary.
    /// - Parameter data: A VariantDictionary containing item properties.
    public func fromDict(_ data: VariantDictionary) {
        if let idVar = data["id"], let idStr = String(idVar) {
            id = idStr
        }
        if let nameVar = data["name"], let nameStr = String(nameVar) {
            name = nameStr
        }
        if let descVar = data["description"], let descStr = String(descVar) {
            itemDescription = descStr
        }
        if let stackVar = data["stackable"], let stackBool = Bool(stackVar) {
            stackable = stackBool
        }
        if let maxVar = data["max_stack"], let maxInt = Int(maxVar) {
            maxStack = maxInt
        }
        if let typeVar = data["item_type"], let typeInt = Int(typeVar) {
            itemType = ItemType(rawValue: typeInt) ?? .misc
        }
        if let rarityVar = data["rarity"], let rarityInt = Int(rarityVar) {
            rarity = ItemRarity(rawValue: rarityInt) ?? .common
        }
        if let valueVar = data["value"], let valueInt = Int(valueVar) {
            value = valueInt
        }
    }

    // MARK: - Utility

    /// Checks if this item can stack with another item.
    /// - Parameter other: The other item to check.
    /// - Returns: True if both items are stackable and have the same ID.
    public func canStackWith(_ other: Item) -> Bool {
        return stackable && other.stackable && id == other.id
    }
}
