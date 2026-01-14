import SwiftGodot

// Item type categories
public enum ItemType: Int, CaseIterable {
    case weapon = 0
    case armor = 1
    case consumable = 2
    case tool = 3
    case misc = 4
}

// Item rarity levels
public enum ItemRarity: Int, CaseIterable {
    case common = 0
    case uncommon = 1
    case rare = 2
    case epic = 3
    case legendary = 4
}

// Item data class - represents an item definition
public class Item {
    public var id: String = ""
    public var name: String = ""
    public var itemDescription: String = ""
    public var icon: Texture2D?

    public var stackable: Bool = true
    public var maxStack: Int = 99

    public var itemType: ItemType = .misc
    public var rarity: ItemRarity = .common
    public var value: Int = 0

    public init() {}

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

    public func canStackWith(_ other: Item) -> Bool {
        return stackable && other.stackable && id == other.id
    }
}
