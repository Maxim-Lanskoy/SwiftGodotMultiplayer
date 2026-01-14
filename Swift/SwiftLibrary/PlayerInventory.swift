import SwiftGodot

// Player inventory system - manages a grid of inventory slots
public class PlayerInventory {
    public static let inventorySize = 20  // 4x5 grid
    public var slots: [InventorySlot] = []

    public init() {
        initializeSlots()
    }

    private func initializeSlots() {
        slots.removeAll()
        for _ in 0..<PlayerInventory.inventorySize {
            slots.append(InventorySlot())
        }
    }

    public func getSlot(_ index: Int) -> InventorySlot? {
        guard index >= 0 && index < slots.count else { return nil }
        return slots[index]
    }

    // Returns remaining quantity that couldn't be added
    public func addItem(_ item: Item, quantity: Int = 1) -> Int {
        var remaining = quantity

        // First, try to add to existing stacks
        if item.stackable {
            for slot in slots {
                if slot.itemId == item.id {
                    remaining = slot.addItem(item, amount: remaining)
                    if remaining <= 0 {
                        break
                    }
                }
            }
        }

        // Then, try to add to empty slots
        if remaining > 0 {
            for slot in slots {
                if slot.isEmpty() {
                    remaining = slot.addItem(item, amount: remaining)
                    if remaining <= 0 {
                        break
                    }
                }
            }
        }

        return remaining
    }

    // Returns amount actually removed
    public func removeItem(itemId: String, quantity: Int = 1) -> Int {
        var removed = 0
        for slot in slots {
            if slot.itemId == itemId {
                let slotRemoved = slot.removeItem(amount: quantity - removed)
                removed += slotRemoved
                if removed >= quantity {
                    break
                }
            }
        }
        return removed
    }

    public func moveItem(fromIndex: Int, toIndex: Int, quantity: Int = -1) -> Bool {
        guard let fromSlot = getSlot(fromIndex),
              let toSlot = getSlot(toIndex),
              !fromSlot.isEmpty() else {
            return false
        }

        // If quantity is -1, move entire stack
        var moveAmount = quantity > 0 ? quantity : fromSlot.quantity
        moveAmount = min(moveAmount, fromSlot.quantity)

        // Get item reference for validation
        guard let item = ItemDatabase.shared.getItem(fromSlot.itemId) else {
            return false
        }

        // Check if we can add to destination
        if toSlot.canAddItem(item, amount: moveAmount) {
            _ = fromSlot.removeItem(amount: moveAmount)
            _ = toSlot.addItem(item, amount: moveAmount)
            return true
        }

        // If can't stack in destination, try to stack in other available slots
        if toSlot.isEmpty() {
            _ = fromSlot.removeItem(amount: moveAmount)
            _ = toSlot.addItem(item, amount: moveAmount)
            return true
        } else {
            // Destination slot is occupied, try to stack in other available slots
            let remainingAfterStack = tryStackItem(item, quantity: moveAmount, excludeSlot: fromIndex)
            if remainingAfterStack < moveAmount {
                // Successfully stacked at least part of the item
                let movedAmount = moveAmount - remainingAfterStack
                _ = fromSlot.removeItem(amount: movedAmount)

                // If something remains, move to destination slot
                if remainingAfterStack > 0 {
                    _ = toSlot.addItem(item, amount: remainingAfterStack)
                }
                return true
            }
        }

        return false
    }

    public func swapItems(fromIndex: Int, toIndex: Int) -> Bool {
        guard let fromSlot = getSlot(fromIndex),
              let toSlot = getSlot(toIndex) else {
            return false
        }

        // If items are the same and stackable, try to stack them
        if fromSlot.itemId == toSlot.itemId && !fromSlot.isEmpty() && !toSlot.isEmpty() {
            if let item = ItemDatabase.shared.getItem(fromSlot.itemId), item.stackable {
                let totalQuantity = fromSlot.quantity + toSlot.quantity
                if totalQuantity <= item.maxStack {
                    // Can stack everything in one slot
                    toSlot.quantity = totalQuantity
                    fromSlot.clear()
                    return true
                } else {
                    // Stack as much as possible and leave the rest in origin slot
                    let spaceAvailable = item.maxStack - toSlot.quantity
                    let amountToMove = min(spaceAvailable, fromSlot.quantity)
                    toSlot.quantity += amountToMove
                    fromSlot.quantity -= amountToMove
                    if fromSlot.quantity <= 0 {
                        fromSlot.clear()
                    }
                    return true
                }
            }
        }

        // If can't stack, do normal swap
        let tempItemId = fromSlot.itemId
        let tempQuantity = fromSlot.quantity

        fromSlot.itemId = toSlot.itemId
        fromSlot.quantity = toSlot.quantity

        toSlot.itemId = tempItemId
        toSlot.quantity = tempQuantity

        return true
    }

    public func getItemCount(_ itemId: String) -> Int {
        var total = 0
        for slot in slots {
            if slot.itemId == itemId {
                total += slot.quantity
            }
        }
        return total
    }

    public func hasItem(_ itemId: String, quantity: Int = 1) -> Bool {
        return getItemCount(itemId) >= quantity
    }

    public func getFirstEmptySlot() -> Int {
        for i in 0..<slots.count {
            if slots[i].isEmpty() {
                return i
            }
        }
        return -1
    }

    public func getFreeSpaceForItem(_ item: Item) -> Int {
        var freeSpace = 0

        // Count space in existing stacks
        if item.stackable {
            for slot in slots {
                if slot.itemId == item.id {
                    freeSpace += item.maxStack - slot.quantity
                }
            }
        }

        // Count empty slots
        for slot in slots {
            if slot.isEmpty() {
                freeSpace += item.maxStack
            }
        }

        return freeSpace
    }

    public func tryStackItem(_ item: Item, quantity: Int, excludeSlot: Int = -1) -> Int {
        guard item.stackable else { return quantity }

        var remaining = quantity

        // First try to stack in existing slots (except origin slot)
        for i in 0..<slots.count {
            if i == excludeSlot {
                continue
            }

            let slot = slots[i]
            if slot.itemId == item.id && !slot.isEmpty() {
                let spaceAvailable = item.maxStack - slot.quantity
                if spaceAvailable > 0 {
                    let amountToStack = min(remaining, spaceAvailable)
                    slot.quantity += amountToStack
                    remaining -= amountToStack
                    if remaining <= 0 {
                        break
                    }
                }
            }
        }

        return remaining
    }

    public func toDict() -> VariantDictionary {
        let dict = VariantDictionary()
        let slotsArray = VariantArray()
        for slot in slots {
            slotsArray.append(Variant(slot.toDict()))
        }
        dict["slots"] = Variant(slotsArray)
        return dict
    }

    public func fromDict(_ data: VariantDictionary) {
        guard let slotsVar = data["slots"],
              let slotsArray = VariantArray(slotsVar) else {
            return
        }

        let count = min(Int(slotsArray.size()), slots.count)
        for i in 0..<count {
            if let slotDict = VariantDictionary(slotsArray[i]) {
                slots[i].fromDict(slotDict)
            }
        }
    }
}
