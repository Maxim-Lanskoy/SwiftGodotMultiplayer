import SwiftGodot

/// Inventory UI panel with grid of slots
/// Uses click-to-move system instead of drag-drop due to SwiftGodot virtual method crash
@Godot
public class InventoryUI: Control {
    // MARK: - Node References

    @Node("Panel/MarginContainer/VBoxContainer/GridContainer") var gridContainer: GridContainer?
    @Node("Panel/MarginContainer/VBoxContainer/TitleBar/Title") var titleLabel: Label?
    @Node("Panel/MarginContainer/VBoxContainer/TitleBar/CloseButton") var closeButton: Button?
    @Node("ItemTooltip") var tooltip: Control?
    @Node("ItemTooltip/Panel/MarginContainer/TooltipText") var tooltipLabel: RichTextLabel?

    // MARK: - Exports

    #exportGroup("Scenes")
    @Export var slotUIScene: PackedScene?

    // MARK: - Signals

    @Signal var inventoryClosed: SimpleSignal

    // MARK: - Private Properties

    /// Cursor preview for held item
    private var cursorPreview: TextureRect?

    /// Current player reference
    public var currentPlayer: Character?

    /// Array of slot UI instances
    private var slotUIs: [InventorySlotUI] = []

    /// Held item state for click-to-move system (-1 = no item held)
    private var heldItemSlot: Int = -1

    // MARK: - Lifecycle

    public override func _ready() {
        // Validate critical nodes
        guard gridContainer != nil else {
            GD.pushError("InventoryUI: GridContainer node not found!")
            return
        }

        gridContainer?.columns = 4

        if let button = closeButton {
            button.pressed.connect { [weak self] in
                self?.onClosePressed()
            }
        }

        tooltip?.visible = false

        // Create cursor preview for held items
        createCursorPreview()

        // Preload slot scene if not set via export
        if slotUIScene == nil {
            slotUIScene = GD.load(path: "res://scenes/ui/inventory_slot_ui.tscn") as? PackedScene
        }

        if slotUIScene == nil {
            GD.pushError("InventoryUI: Failed to load slot UI scene!")
            return
        }

        createSlotUIs()
    }

    public override func _process(delta: Double) {
        // Update cursor preview position if holding an item
        if heldItemSlot >= 0, let preview = cursorPreview, preview.visible {
            let mousePos = getGlobalMousePosition()
            // Center the preview on cursor
            preview.setGlobalPosition(Vector2(x: mousePos.x - 16, y: mousePos.y - 16))
        }
    }

    public override func _input(event: InputEvent?) {
        guard visible else { return }

        if let keyEvent = event as? InputEventKey, keyEvent.pressed {
            if keyEvent.keycode == .escape {
                if heldItemSlot >= 0 {
                    // ESC cancels held item first
                    cancelHeldItem()
                    getViewport()?.setInputAsHandled()
                } else {
                    // ESC closes inventory
                    onClosePressed()
                }
            }
        }
    }

    // MARK: - Setup

    private func createCursorPreview() {
        cursorPreview = TextureRect()
        cursorPreview?.expandMode = .ignoreSize
        cursorPreview?.customMinimumSize = Vector2(x: 32, y: 32)
        cursorPreview?.setSize(Vector2(x: 32, y: 32))
        cursorPreview?.modulate = Color(r: 1, g: 1, b: 1, a: 0.8)
        cursorPreview?.mouseFilter = .ignore
        cursorPreview?.visible = false
        cursorPreview?.zIndex = 100

        if let preview = cursorPreview {
            addChild(node: preview)
        }
    }

    private func createSlotUIs() {
        guard let grid = gridContainer else {
            GD.pushError("InventoryUI: Cannot create slots - GridContainer is nil!")
            return
        }

        // Clear existing slots
        for child in grid.getChildren() {
            child?.queueFree()
        }
        slotUIs.removeAll()

        // Create new slots
        for i in 0..<PlayerInventory.inventorySize {
            guard let scene = slotUIScene,
                  let slotUI = scene.instantiate() as? InventorySlotUI else {
                GD.pushWarning("InventoryUI: Failed to instantiate slot UI for index \(i)")
                continue
            }

            slotUI.customMinimumSize = Vector2(x: 64, y: 64)
            slotUI.parentInventory = self

            slotUI.slotClicked.connect { [weak self] slotIndex, button in
                self?.onSlotClicked(slotIndex: slotIndex, button: button)
            }
            slotUI.itemHovered.connect { [weak self] slotIndex, itemId in
                self?.onItemHovered(slotIndex: slotIndex, itemId: itemId)
            }
            slotUI.itemUnhovered.connect { [weak self] in
                self?.onItemUnhovered()
            }

            slotUI.setSlotData(slotData: nil, index: i)

            grid.addChild(node: slotUI)
            slotUIs.append(slotUI)
        }
    }

    // MARK: - Public Methods

    public func updateInventoryDisplay() {
        guard let player = currentPlayer, player.isInsideTree() else {
            // No player or player was freed - clear reference
            if currentPlayer != nil {
                clearPlayer()
            }
            return
        }

        guard let playerInventory = player.getInventory() else {
            GD.pushWarning("InventoryUI: Player has no inventory")
            return
        }

        for i in 0..<slotUIs.count {
            if i < PlayerInventory.inventorySize {
                slotUIs[i].setSlotData(slotData: playerInventory.slots[i], index: i)

                // Re-apply held source visual if needed
                if i == heldItemSlot {
                    slotUIs[i].setAsHeldSource(true)
                }
            }
        }
    }

    public func openInventory(player: Character? = nil) {
        if let player = player {
            currentPlayer = player
            updateInventoryDisplay()
        }
        // Clear any held state when opening
        clearHeldState()
        visible = true
    }

    public func closeInventory() {
        cancelHeldItem()
        visible = false
    }

    /// Clears the player reference. Call when player disconnects to prevent dangling reference.
    public func clearPlayer() {
        currentPlayer = nil
        clearHeldState()
        if visible {
            visible = false
            inventoryClosed.emit()
        }
    }

    /// Checks if the current player reference is still valid (in scene tree).
    public func isPlayerValid() -> Bool {
        guard let player = currentPlayer else { return false }
        return player.isInsideTree()
    }

    public func refreshDisplay() {
        // Safety check before refreshing
        guard isPlayerValid() else {
            clearPlayer()
            return
        }
        updateInventoryDisplay()
    }

    // MARK: - Slot Click Handling

    func onSlotClicked(slotIndex: Int, button: Int) {
        switch button {
        case 1: // Left click - pick up or place item
            handleLeftClick(slotIndex: slotIndex)
        case 2: // Right click - cancel held item or show context menu
            handleRightClick(slotIndex: slotIndex)
        default:
            break
        }
    }

    private func handleLeftClick(slotIndex: Int) {
        if heldItemSlot < 0 {
            // Not holding anything - try to pick up
            if slotUIs[slotIndex].hasItem() {
                pickUpItem(fromSlot: slotIndex)
            }
        } else {
            // Holding an item - place it
            if slotIndex != heldItemSlot {
                placeItem(toSlot: slotIndex)
            } else {
                // Clicked on same slot - cancel
                cancelHeldItem()
            }
        }
    }

    private func handleRightClick(slotIndex: Int) {
        // Right click cancels held item
        if heldItemSlot >= 0 {
            cancelHeldItem()
            return
        }

        // Otherwise show context menu or quick action
        guard let player = currentPlayer,
              let playerInventory = player.getInventory() else { return }

        let slot = playerInventory.slots[slotIndex]
        if !slot.isEmpty() {
            if let item = ItemDatabase.shared?.getItem(slot.itemId) {
                // TODO: Show context menu or perform quick action (use item, etc.)
                _ = item // Suppress unused warning until context menu is implemented
            }
        }
    }

    // MARK: - Item Holding State

    private func pickUpItem(fromSlot: Int) {
        guard fromSlot >= 0 && fromSlot < slotUIs.count else { return }

        heldItemSlot = fromSlot

        // Dim the source slot
        slotUIs[fromSlot].setAsHeldSource(true)

        // Show cursor preview with item icon
        if let texture = slotUIs[fromSlot].getItemTexture() {
            cursorPreview?.texture = texture
            cursorPreview?.visible = true
        }

        // Hide tooltip while holding item
        hideTooltip()
    }

    private func placeItem(toSlot: Int) {
        guard heldItemSlot >= 0 else { return }

        let fromSlot = heldItemSlot

        // Send move request to server
        if let player = currentPlayer {
            player.sendRequestMoveItem(fromSlot: fromSlot, toSlot: toSlot)
        }

        // Clear held state
        clearHeldState()
    }

    private func cancelHeldItem() {
        clearHeldState()
    }

    private func clearHeldState() {
        if heldItemSlot >= 0 && heldItemSlot < slotUIs.count {
            slotUIs[heldItemSlot].setAsHeldSource(false)
        }
        heldItemSlot = -1
        cursorPreview?.visible = false
        cursorPreview?.texture = nil
    }

    // MARK: - Tooltip

    func onItemHovered(slotIndex: Int, itemId: String) {
        // Don't show tooltip while holding an item
        guard heldItemSlot < 0 else { return }

        if let item = ItemDatabase.shared?.getItem(itemId) {
            showTooltip(item: item)
        }
    }

    func onItemUnhovered() {
        hideTooltip()
    }

    private func showTooltip(item: Item) {
        var content = "[b][color=#FFD700]\(item.name)[/color][/b]\n"
        content += "[color=#CCCCCC]\(item.itemDescription)[/color]\n\n"
        content += "[color=#87CEEB]Type:[/color] \(getItemTypeString(item.itemType))\n"
        content += "[color=#FF69B4]Rarity:[/color] \(getRarityString(item.rarity))\n"
        content += "[color=#FFD700]Value:[/color] \(item.value) gold"

        if item.stackable {
            content += "\n[color=#98FB98]Max Stack:[/color] \(item.maxStack)"
        }

        tooltipLabel?.text = content
        tooltip?.visible = true

        positionTooltipSmartly()
    }

    private func hideTooltip() {
        tooltip?.visible = false
    }

    private func positionTooltipSmartly() {
        guard let tooltip = tooltip else { return }

        let mousePos = getGlobalMousePosition()
        let tooltipSize = tooltip.getSize()
        let viewportSize = getViewport()?.getVisibleRect().size ?? Vector2(x: 1920, y: 1080)

        var tooltipPos = Vector2(x: mousePos.x + 10, y: mousePos.y + 10)

        if tooltipPos.x + tooltipSize.x > viewportSize.x {
            tooltipPos.x = mousePos.x - tooltipSize.x - 10
        }

        if tooltipPos.y + tooltipSize.y > viewportSize.y {
            tooltipPos.y = mousePos.y - tooltipSize.y - 10
        }

        if tooltipPos.x < 0 {
            tooltipPos.x = 10
        }

        if tooltipPos.y < 0 {
            tooltipPos.y = 10
        }

        tooltip.setGlobalPosition(tooltipPos)
    }

    // MARK: - UI Actions

    func onClosePressed() {
        cancelHeldItem()
        inventoryClosed.emit()
        visible = false
    }

    // MARK: - Helpers

    private func getItemTypeString(_ type: ItemType) -> String {
        switch type {
        case .weapon: return "Weapon"
        case .armor: return "Armor"
        case .consumable: return "Consumable"
        case .tool: return "Tool"
        case .misc: return "Miscellaneous"
        }
    }

    private func getRarityString(_ rarity: ItemRarity) -> String {
        switch rarity {
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }
}
