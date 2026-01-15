import SwiftGodot

/// Individual inventory slot UI component with click-to-move support
/// NOTE: Godot's drag-drop virtual methods (_getDragData, _canDropData, _dropData)
/// crash in SwiftGodot, so we use a click-based system instead
@Godot
public class InventorySlotUI: Control {
    // MARK: - Node References

    @Node("Background") var background: NinePatchRect?
    @Node("ItemIcon") var itemIcon: TextureRect?
    @Node("QuantityLabel") var quantityLabel: Label?
    @Node("RarityBorder") var rarityBorder: NinePatchRect?

    // MARK: - Properties

    /// Index of this slot in the inventory
    public var slotIndex: Int = 0

    /// Data for the item in this slot
    public var inventoryData: InventorySlot?

    /// Reference to parent inventory UI
    public weak var parentInventory: InventoryUI?

    // MARK: - Private State

    /// Whether the slot is currently highlighted
    private var isHighlighted: Bool = false

    // MARK: - Signals

    @Signal var slotClicked: SignalWithArguments<Int, Int>
    @Signal var itemHovered: SignalWithArguments<Int, String>
    @Signal var itemUnhovered: SimpleSignal

    // MARK: - Helpers

    private func getRarityColor(_ rarity: ItemRarity) -> Color {
        switch rarity {
        case .common: return Color.white
        case .uncommon: return Color.green
        case .rare: return Color.blue
        case .epic: return Color(r: 0.5, g: 0, b: 0.5, a: 1) // Purple
        case .legendary: return Color.orange
        }
    }

    // MARK: - Lifecycle

    public override func _ready() {
        // Connect signals with weak self to avoid retain cycles
        guiInput.connect { [weak self] event in
            self?.onGuiInput(event: event)
        }
        mouseEntered.connect { [weak self] in
            self?.onMouseEntered()
        }
        mouseExited.connect { [weak self] in
            self?.onMouseExited()
        }

        updateDisplay()
    }

    // MARK: - Public Methods

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

    /// Visual feedback for when this slot is the source of a held item
    public func setAsHeldSource(_ isSource: Bool) {
        if isSource {
            itemIcon?.modulate = Color(r: 0.5, g: 0.5, b: 0.5, a: 0.5)
        } else {
            itemIcon?.modulate = Color.white
        }
    }

    /// Check if this slot has an item
    public func hasItem() -> Bool {
        return inventoryData != nil && inventoryData?.isEmpty() == false
    }

    /// Get the item texture for creating preview
    public func getItemTexture() -> Texture2D? {
        guard let slotData = inventoryData,
              let item = ItemDatabase.shared?.getItem(slotData.itemId) else {
            return nil
        }
        return item.icon
    }

    // MARK: - Display Updates

    private func showEmptySlot() {
        itemIcon?.texture = nil
        itemIcon?.modulate = Color.white
        quantityLabel?.visible = false
        rarityBorder?.visible = false
        if !isHighlighted {
            background?.modulate = Color.white
        }
    }

    private func showItemSlot() {
        guard let slotData = inventoryData,
              let item = ItemDatabase.shared?.getItem(slotData.itemId) else {
            showEmptySlot()
            return
        }

        itemIcon?.texture = item.icon
        itemIcon?.modulate = Color.white

        if item.stackable && slotData.quantity > 1 {
            quantityLabel?.text = String(slotData.quantity)
            quantityLabel?.visible = true
        } else {
            quantityLabel?.visible = false
        }

        rarityBorder?.modulate = getRarityColor(item.rarity)
        rarityBorder?.visible = true
    }

    // MARK: - Input Handlers

    private func onGuiInput(event: InputEvent?) {
        guard let mouseEvent = event as? InputEventMouseButton,
              mouseEvent.pressed else { return }

        let buttonIndex = Int(mouseEvent.buttonIndex.rawValue)
        slotClicked.emit(slotIndex, buttonIndex)
    }

    private func onMouseEntered() {
        isHighlighted = true
        if let slotData = inventoryData, !slotData.isEmpty() {
            itemHovered.emit(slotIndex, slotData.itemId)
        }
        background?.modulate = Color(r: 1.2, g: 1.2, b: 1.2, a: 1)
    }

    private func onMouseExited() {
        isHighlighted = false
        itemUnhovered.emit()
        background?.modulate = Color.white
    }
}
