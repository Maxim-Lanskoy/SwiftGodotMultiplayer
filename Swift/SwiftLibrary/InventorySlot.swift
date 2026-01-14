import SwiftGodot

// Inventory slot data model
public class InventorySlot {
    public var itemId: String = ""
    public var quantity: Int = 0

    public init() {}

    public init(itemId: String, quantity: Int) {
        self.itemId = itemId
        self.quantity = quantity
    }

    public func isEmpty() -> Bool {
        return itemId.isEmpty || quantity <= 0
    }

    public func canAddItem(_ item: Item, amount: Int = 1) -> Bool {
        if isEmpty() {
            return true
        }
        if itemId == item.id && item.stackable {
            return quantity + amount <= item.maxStack
        }
        return false
    }

    // Returns remaining amount that couldn't be added
    public func addItem(_ item: Item, amount: Int = 1) -> Int {
        if isEmpty() {
            itemId = item.id
            quantity = min(amount, item.maxStack)
            return amount - quantity
        } else if itemId == item.id && item.stackable {
            let spaceAvailable = item.maxStack - quantity
            let amountToAdd = min(amount, spaceAvailable)
            quantity += amountToAdd
            return amount - amountToAdd
        }
        return amount
    }

    // Returns amount actually removed
    public func removeItem(amount: Int = 1) -> Int {
        let removed = min(amount, quantity)
        quantity -= removed
        if quantity <= 0 {
            clear()
        }
        return removed
    }

    public func clear() {
        itemId = ""
        quantity = 0
    }

    public func toDict() -> VariantDictionary {
        let dict = VariantDictionary()
        dict["item_id"] = Variant(itemId)
        dict["quantity"] = Variant(quantity)
        return dict
    }

    public func fromDict(_ data: VariantDictionary) {
        if let idVar = data["item_id"], let idStr = String(idVar) {
            itemId = idStr
        } else {
            itemId = ""
        }
        if let qtyVar = data["quantity"], let qtyInt = Int(qtyVar) {
            quantity = qtyInt
        } else {
            quantity = 0
        }
    }
}
