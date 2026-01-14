import SwiftGodot

// Individual inventory slot UI component with drag and drop support
@Godot
public class InventorySlotUI: Control {
    // Node references
    private var background: NinePatchRect?
    private var itemIcon: TextureRect?
    private var quantityLabel: Label?
    private var rarityBorder: NinePatchRect?

    // Data
    public var slotIndex: Int = 0
    public var inventoryData: InventorySlot?
    public weak var parentInventory: InventoryUI?

    // Signals
    @Signal var slotClicked: SignalWithArguments<Int, Int>
    @Signal var itemHovered: SignalWithArguments<Int, String>  // Pass item ID instead of Item
    @Signal var itemUnhovered: SimpleSignal

    // Rarity color helper
    private func getRarityColor(_ rarity: ItemRarity) -> Color {
        switch rarity {
        case .common: return Color.white
        case .uncommon: return Color.green
        case .rare: return Color.blue
        case .epic: return Color(r: 0.5, g: 0, b: 0.5, a: 1) // Purple
        case .legendary: return Color.orange
        }
    }

    public override func _ready() {
        // Find child nodes
        background = getNode(path: "Background") as? NinePatchRect
        itemIcon = getNode(path: "ItemIcon") as? TextureRect
        quantityLabel = getNode(path: "QuantityLabel") as? Label
        rarityBorder = getNode(path: "RarityBorder") as? NinePatchRect

        // Connect signals
        guiInput.connect(onGuiInput)
        mouseEntered.connect(onMouseEntered)
        mouseExited.connect(onMouseExited)

        updateDisplay()
    }

    public func setSlotData(slotData: InventorySlot?, index: Int) {
        inventoryData = slotData
        slotIndex = index
        updateDisplay()
    }

    public func updateDisplay() {
        if inventoryData == nil || inventoryData?.isEmpty() == true {
            showEmptySlot()
        } else {
            showItemSlot()
        }
    }

    private func showEmptySlot() {
        itemIcon?.texture = nil
        quantityLabel?.visible = false
        rarityBorder?.visible = false
        background?.modulate = Color.white
    }

    private func showItemSlot() {
        guard let slotData = inventoryData,
              let item = ItemDatabase.shared.getItem(slotData.itemId) else {
            showEmptySlot()
            return
        }

        itemIcon?.texture = item.icon

        if item.stackable && slotData.quantity > 1 {
            quantityLabel?.text = String(slotData.quantity)
            quantityLabel?.visible = true
        } else {
            quantityLabel?.visible = false
        }

        rarityBorder?.modulate = getRarityColor(item.rarity)
        rarityBorder?.visible = true
    }

    func onGuiInput(event: InputEvent?) {
        guard let mouseEvent = event as? InputEventMouseButton,
              mouseEvent.pressed else { return }
        slotClicked.emit(slotIndex, Int(mouseEvent.buttonIndex.rawValue))
    }

    func onMouseEntered() {
        if let slotData = inventoryData, !slotData.isEmpty() {
            itemHovered.emit(slotIndex, slotData.itemId)
        }
        background?.modulate = Color(r: 1.2, g: 1.2, b: 1.2, a: 1)
    }

    func onMouseExited() {
        itemUnhovered.emit()
        background?.modulate = Color.white
    }

    // Drag and Drop support
    public override func _canDropData(atPosition position: Vector2, data: Variant?) -> Bool {
        guard let data = data, let dict = VariantDictionary(data) else { return false }
        return dict["slot_index"] != nil && dict["inventory_type"] != nil
    }

    public override func _dropData(atPosition position: Vector2, data: Variant?) {
        guard let data = data,
              let dict = VariantDictionary(data),
              let fromSlotVar = dict["slot_index"],
              let fromSlot = Int(fromSlotVar) else { return }

        parentInventory?.handleItemDrop(fromSlot: fromSlot, toSlot: slotIndex, inventoryType: "player")
    }

    public override func _getDragData(atPosition position: Vector2) -> Variant? {
        guard let slotData = inventoryData, !slotData.isEmpty(),
              let item = ItemDatabase.shared.getItem(slotData.itemId) else {
            return nil
        }

        // Create drag preview
        let preview = Control()
        let previewIcon = TextureRect()
        previewIcon.texture = item.icon
        previewIcon.expandMode = .ignoreSize
        previewIcon.customMinimumSize = Vector2(x: 32, y: 32)
        preview.addChild(node: previewIcon)
        preview.modulate = Color(r: 1, g: 1, b: 1, a: 0.8)
        setDragPreview(control: preview)

        itemIcon?.modulate = Color(r: 0.5, g: 0.5, b: 0.5, a: 1)

        // Return drag data
        let dragData = VariantDictionary()
        dragData["slot_index"] = Variant(slotIndex)
        dragData["item_id"] = Variant(slotData.itemId)
        dragData["quantity"] = Variant(slotData.quantity)
        dragData["inventory_type"] = Variant("player")
        return Variant(dragData)
    }

    // Track drag end to restore icon color
    func onDragEnded() {
        itemIcon?.modulate = Color.white
    }
}
