import SwiftGodot

// Inventory UI panel with grid of slots
@Godot
public class InventoryUI: Control {
    // Node references
    private var gridContainer: GridContainer?
    private var titleLabel: Label?
    private var closeButton: Button?
    private var tooltip: Control?
    private var tooltipLabel: RichTextLabel?

    // Data
    public var currentPlayer: Character?
    @Export var slotUIScene: PackedScene?
    private var slotUIs: [InventorySlotUI] = []

    // Signals
    @Signal var inventoryClosed: SimpleSignal

    public override func _ready() {
        // Find child nodes
        gridContainer = getNode(path: "Panel/MarginContainer/VBoxContainer/GridContainer") as? GridContainer
        titleLabel = getNode(path: "Panel/MarginContainer/VBoxContainer/TitleBar/Title") as? Label
        closeButton = getNode(path: "Panel/MarginContainer/VBoxContainer/TitleBar/CloseButton") as? Button
        tooltip = getNode(path: "ItemTooltip") as? Control
        tooltipLabel = getNode(path: "ItemTooltip/Panel/MarginContainer/TooltipText") as? RichTextLabel

        gridContainer?.columns = 4
        closeButton?.pressed.connect(onClosePressed)
        tooltip?.visible = false

        // Preload slot scene if not set via export
        if slotUIScene == nil {
            slotUIScene = GD.load(path: "res://scenes/ui/inventory_slot_ui.tscn") as? PackedScene
        }

        createSlotUIs()
    }

    private func createSlotUIs() {
        guard let grid = gridContainer else { return }

        // Clear existing slots
        for child in grid.getChildren() {
            child?.queueFree()
        }
        slotUIs.removeAll()

        // Create new slots
        for i in 0..<PlayerInventory.inventorySize {
            guard let scene = slotUIScene,
                  let slotUI = scene.instantiate() as? InventorySlotUI else {
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

    public func updateInventoryDisplay() {
        guard let player = currentPlayer,
              let playerInventory = player.getInventory() else { return }

        GD.print("Debug: Updating inventory display with \(playerInventory.slots.count) slots")

        for i in 0..<slotUIs.count {
            if i < PlayerInventory.inventorySize {
                slotUIs[i].setSlotData(slotData: playerInventory.slots[i], index: i)
            }
        }
    }

    func onSlotClicked(slotIndex: Int, button: Int) {
        GD.print("Slot \(slotIndex) clicked with button \(button)")

        switch button {
        case 1: // Left click
            break
        case 2: // Right click
            handleRightClick(slotIndex: slotIndex)
        default:
            break
        }
    }

    private func handleRightClick(slotIndex: Int) {
        guard let player = currentPlayer,
              let playerInventory = player.getInventory() else { return }

        let slot = playerInventory.slots[slotIndex]
        if !slot.isEmpty() {
            if let item = ItemDatabase.shared.getItem(slot.itemId) {
                GD.print("Right clicked on: \(item.name)")
                // TODO: Show context menu or perform quick action
            }
        }
    }

    func onItemHovered(slotIndex: Int, itemId: String) {
        if let item = ItemDatabase.shared.getItem(itemId) {
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

    public func handleItemDrop(fromSlot: Int, toSlot: Int, inventoryType: String) {
        GD.print("Moving item from slot \(fromSlot) to slot \(toSlot)")

        if inventoryType == "player", let player = currentPlayer {
            player.requestMoveItem(fromSlot: fromSlot, toSlot: toSlot, quantity: -1)
        }
    }

    func onClosePressed() {
        inventoryClosed.emit()
        visible = false
    }

    public func openInventory(player: Character? = nil) {
        if let player = player {
            currentPlayer = player
            updateInventoryDisplay()
        }
        visible = true
    }

    public func closeInventory() {
        visible = false
    }

    public func refreshDisplay() {
        GD.print("Debug: InventoryUI refresh_display called")
        updateInventoryDisplay()
    }

    public override func _input(event: InputEvent?) {
        guard let keyEvent = event as? InputEventKey,
              keyEvent.pressed,
              keyEvent.keycode == .escape,
              visible else { return }

        onClosePressed()
    }
}
