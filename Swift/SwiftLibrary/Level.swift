import SwiftGodot
import Foundation

// Main game level manager - handles player spawning, UI, and game state
@Godot
public class Level: Node3D {
    // Node references - using @Node macro for scene tree binding
    @Node("PlayersContainer") var playersContainer: Node3D?
    @Node("MainMenuUI") var mainMenu: MainMenuUI?
    @Node("MultiplayerChatUI") var multiplayerChat: MultiplayerChatUI?
    @Node("InventoryUI") var inventoryUI: InventoryUI?

    @Export var playerScene: PackedScene?

    // State
    private var chatVisible = false
    private var inventoryVisible = false

    public override func _ready() {
        // Start dedicated server in headless mode
        if DisplayServer.getName() == "headless" {
            GD.print("Dedicated server starting...")
            _ = Network.shared.startHost(nickname: "", skinColorStr: "")
        }

        multiplayerChat?.hide()
        mainMenu?.showMenu()
        multiplayerChat?.setProcessInput(enable: true)

        // Connect main menu signals
        if let menu = mainMenu {
            menu.hostPressed.connect(onHostPressed)
            menu.joinPressed.connect(onJoinPressed)
            menu.quitPressed.connect(onQuitPressed)
        }

        // Connect inventory UI signals
        if let inventory = inventoryUI {
            inventory.inventoryClosed.connect(onInventoryClosed)
        }

        // Connect chat signals
        if let chat = multiplayerChat {
            chat.messageSent.connect(onChatMessageSent)
        }

        guard multiplayer?.isServer() == true else { return }

        // Server-only: connect player events
        Network.shared.playerConnected.connect(onPlayerConnected)
        multiplayer?.peerDisconnected.connect(removePlayer)
    }

    func onPlayerConnected(peerId: Int, playerInfo: VariantDictionary) {
        addPlayer(id: peerId, playerInfo: playerInfo)
    }

    func onHostPressed(nickname: String, skin: String) {
        mainMenu?.hideMenu()
        _ = Network.shared.startHost(nickname: nickname, skinColorStr: skin)
    }

    func onJoinPressed(nickname: String, skin: String, address: String) {
        mainMenu?.hideMenu()
        _ = Network.shared.joinGame(nickname: nickname, skinColorStr: skin, address: address)
    }

    func addPlayer(id: Int, playerInfo: VariantDictionary) {
        // Skip host player in headless mode
        if DisplayServer.getName() == "headless" && id == 1 {
            return
        }

        guard let container = playersContainer else { return }

        // Check if player already exists
        if container.hasNode(path: NodePath(String(id))) {
            return
        }

        guard let scene = playerScene,
              let player = scene.instantiate() as? Character else {
            return
        }

        player.name = StringName(String(id))
        player.position = getSpawnPoint()
        container.addChild(node: player, forceReadableName: true)

        // Set player info
        if let players = Network.shared.getPlayers()[id] {
            player.changeNick(newNick: players.nick)
            player.setPlayerSkin(skinColor: players.skin.rawValue)
        }
    }

    func getSpawnPoint() -> Vector3 {
        let angle = Float.random(in: 0...(2 * Float.pi))
        let radius: Float = 10.0
        let x = cos(angle) * radius
        let z = sin(angle) * radius
        return Vector3(x: x, y: 0, z: z)
    }

    func removePlayer(id: Int64) {
        guard multiplayer?.isServer() == true,
              let container = playersContainer else { return }

        let path = NodePath(String(id))
        if container.hasNode(path: path),
           let playerNode = container.getNode(path: path) {
            playerNode.queueFree()
        }
    }

    func onQuitPressed() {
        getTree()?.quit(exitCode: 0)
    }

    // MARK: - Multiplayer Chat

    func toggleChat() {
        if mainMenu?.isMenuVisible() == true {
            return
        }

        multiplayerChat?.toggleChat()
        chatVisible = multiplayerChat?.isChatVisible() ?? false
    }

    public func isChatVisible() -> Bool {
        return multiplayerChat?.isChatVisible() ?? false
    }

    public override func _input(event: InputEvent?) {
        guard let event = event else { return }

        if event.isActionPressed(action: "toggle_chat") {
            toggleChat()
        } else if chatVisible {
            if let keyEvent = event as? InputEventKey,
               keyEvent.keycode == .enter && keyEvent.pressed {
                multiplayerChat?.sendMessage()
                getViewport()?.setInputAsHandled()
            }
        } else if event.isActionPressed(action: "inventory") {
            toggleInventory()
        } else if let keyEvent = event as? InputEventKey, keyEvent.pressed {
            // Debug keys
            if keyEvent.keycode == .f1 {
                debugAddItem()
            } else if keyEvent.keycode == .f2 {
                debugPrintInventory()
            }
        }
    }

    func onChatMessageSent(messageText: String) {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespaces)
        if trimmedMessage.isEmpty {
            return
        }

        let localId = Int(multiplayer?.getUniqueId() ?? 0)
        if let playerInfo = Network.shared.getPlayerInfo(localId) {
            // RPC call to broadcast message
            msgRpc(nick: playerInfo.nick, msg: trimmedMessage)
        }
    }

    @Callable
    func msgRpc(nick: String, msg: String) {
        multiplayerChat?.addMessage(nick: nick, msg: msg)
    }

    // MARK: - Inventory System

    func toggleInventory() {
        if mainMenu?.isMenuVisible() == true {
            return
        }

        guard let localPlayer = getLocalPlayer() else { return }

        inventoryVisible = !inventoryVisible
        if inventoryVisible {
            inventoryUI?.openInventory(player: localPlayer)
        } else {
            inventoryUI?.closeInventory()
        }
    }

    public func isInventoryVisible() -> Bool {
        return inventoryVisible
    }

    func onInventoryClosed() {
        inventoryVisible = false
    }

    public func updateLocalInventoryDisplay() {
        inventoryUI?.refreshDisplay()
        GD.print("Debug: Inventory display updated from server sync")
    }

    func getLocalPlayer() -> Character? {
        guard let container = playersContainer else { return nil }
        let localPlayerId = Int(multiplayer?.getUniqueId() ?? 0)
        let path = NodePath(String(localPlayerId))
        if container.hasNode(path: path) {
            return container.getNode(path: path) as? Character
        }
        return nil
    }

    // MARK: - Debug Functions

    func debugAddItem() {
        guard let localPlayer = getLocalPlayer() else {
            GD.print("Debug: No local player found!")
            return
        }

        let testItems = ["iron_sword", "health_potion", "leather_armor", "magic_gem", "iron_pickaxe"]
        let randomItem = testItems.randomElement() ?? "health_potion"
        GD.print("Debug: Requesting to add \(randomItem) to player \(localPlayer.name) (authority: \(localPlayer.getMultiplayerAuthority()))")
        localPlayer.requestAddItem(itemId: randomItem, quantity: 1)
    }

    func debugPrintInventory() {
        guard let localPlayer = getLocalPlayer(),
              let inventory = localPlayer.getInventory() else {
            GD.print("No inventory found for local player")
            return
        }

        GD.print("=== Inventory Debug ===")
        for i in 0..<inventory.slots.count {
            let slot = inventory.slots[i]
            if !slot.isEmpty() {
                GD.print("Slot \(i): \(slot.itemId) x\(slot.quantity)")
            }
        }
        GD.print("=====================")
    }
}
