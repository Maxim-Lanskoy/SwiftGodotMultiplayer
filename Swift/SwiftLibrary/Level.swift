import SwiftGodot
import Foundation

/// Main game level manager handling player spawning, UI, and game state.
///
/// This class is the central coordinator for the game scene, managing:
/// - Player spawning and removal based on network events
/// - UI state (main menu, chat, inventory)
/// - Debug functionality for testing
///
/// ## Scene Structure
/// The Level node expects the following children:
/// - `PlayersContainer`: Node3D containing spawned player characters
/// - `MainMenuUI`: Main menu control
/// - `MultiplayerChatUI`: Multiplayer chat panel
/// - `InventoryUI`: Inventory display panel
@Godot
public class Level: Node3D {
    // MARK: - Node References

    @Node("PlayersContainer") var playersContainer: Node3D?
    @Node("MultiplayerSpawner") var multiplayerSpawner: MultiplayerSpawner?
    @Node("MainMenuUI") var mainMenu: MainMenuUI?
    @Node("MultiplayerChatUI") var multiplayerChat: MultiplayerChatUI?
    @Node("InventoryUI") var inventoryUI: InventoryUI?

    // MARK: - Exports

    #exportGroup("Scenes")
    /// The player character scene to instantiate for each player.
    @Export var playerScene: PackedScene?

    // MARK: - Private State

    private var chatVisible = false
    private var inventoryVisible = false

    // MARK: - Lifecycle

    public override func _enterTree() {
        // Manually configure RPC methods
        configureRpcMethods()
    }

    /// Configure any RPC methods if needed.
    /// Note: Chat now uses MultiplayerSynchronizer instead of RPC.
    private func configureRpcMethods() {
        // Chat is now handled via Character's synced properties
        // No RPC configuration needed for Level
    }

    public override func _ready() {
        // Start dedicated server in headless mode
        if DisplayServer.getName() == "headless" {
            GD.print("Level: Starting dedicated server...")
            _ = Network.shared?.startHost(nickname: "", skinColorStr: "")
        }

        multiplayerChat?.hide()
        mainMenu?.showMenu()
        multiplayerChat?.setProcessInput(enable: true)

        // Connect main menu signals with weak self to avoid retain cycles
        mainMenu?.hostPressed.connect { [weak self] nickname, skin in
            self?.onHostPressed(nickname: nickname, skin: skin)
        }
        mainMenu?.joinPressed.connect { [weak self] nickname, skin, address in
            self?.onJoinPressed(nickname: nickname, skin: skin, address: address)
        }
        mainMenu?.quitPressed.connect { [weak self] in
            self?.onQuitPressed()
        }

        // Connect inventory UI signals
        inventoryUI?.inventoryClosed.connect { [weak self] in
            self?.onInventoryClosed()
        }

        // Connect chat signals
        multiplayerChat?.messageSent.connect { [weak self] msg in
            self?.onChatMessageSent(messageText: msg)
        }

        // Connect player events - with MultiplayerSpawner, only server spawns players
        // The spawner automatically replicates to clients
        Network.shared?.playerConnected.connect { [weak self] peerId, playerInfo in
            self?.onPlayerConnected(peerId: peerId, playerInfo: playerInfo)
        }

        // Server handles player removal - spawner will sync removal to clients
        multiplayer?.peerDisconnected.connect { [weak self] id in
            self?.removePlayer(id: id)
        }

        // Handle disconnection from server (client-side)
        Network.shared?.serverDisconnected.connect { [weak self] in
            self?.onServerDisconnected()
        }

        // Handle connection failure (timeout or rejection)
        Network.shared?.connectionAttemptFailed.connect { [weak self] in
            self?.onConnectionFailed()
        }

        GD.print("Level: Player signals connected, MultiplayerSpawner: \(multiplayerSpawner != nil ? "found" : "NOT FOUND")")

        // Debug: Check spawner configuration
        if let spawner = multiplayerSpawner {
            GD.print("Level: Spawner spawn_path: \(spawner.spawnPath)")
            GD.print("Level: Spawner spawnable scene count: \(spawner.getSpawnableSceneCount())")
            // Verify spawner can find the spawn node
            if let spawnNode = spawner.getNode(path: spawner.spawnPath) {
                GD.print("Level: Spawner found spawn node: \(spawnNode.name)")
            } else {
                GD.print("Level: WARNING - Spawner CANNOT find spawn node at path: \(spawner.spawnPath)")
            }

            // Connect to spawned signal to debug spawn events
            spawner.spawned.connect { [weak self] node in
                if let spawnedNode = node {
                    GD.print("Level: [SPAWNER] Spawned signal received for node: \(spawnedNode.name)")
                    GD.print("Level: [SPAWNER] Node scene_file_path: '\(spawnedNode.sceneFilePath)'")
                } else {
                    GD.print("Level: [SPAWNER] Spawned signal received but node is nil")
                }
                if let container = self?.playersContainer {
                    GD.print("Level: [SPAWNER] PlayersContainer now has \(container.getChildCount()) children")
                }
            }
            GD.print("Level: Connected to spawner.spawned signal")
        }
    }

    // MARK: - Menu Handlers

    private func onPlayerConnected(peerId: Int, playerInfo: VariantDictionary) {
        GD.print("Level: onPlayerConnected called for peer \(peerId), isServer: \(multiplayer?.isServer() ?? false)")
        GD.print("Level: Current peer ID: \(multiplayer?.getUniqueId() ?? 0)")
        addPlayer(id: peerId, playerInfo: playerInfo)
    }

    private func onHostPressed(nickname: String, skin: String) {
        mainMenu?.hideMenu()
        _ = Network.shared?.startHost(nickname: nickname, skinColorStr: skin)
    }

    private func onJoinPressed(nickname: String, skin: String, address: String) {
        mainMenu?.hideMenu()
        _ = Network.shared?.joinGame(nickname: nickname, skinColorStr: skin, address: address)
    }

    private func onQuitPressed() {
        getTree()?.quit(exitCode: 0)
    }

    // MARK: - Player Management

    /// Spawns a player character for the given peer.
    /// With MultiplayerSpawner, only the server spawns - the spawner replicates to clients.
    private func addPlayer(id: Int, playerInfo: VariantDictionary) {
        let isServer = multiplayer?.isServer() ?? false
        GD.print("Level: addPlayer called for peer \(id)")
        GD.print("Level: isServer: \(isServer), uniqueId: \(multiplayer?.getUniqueId() ?? 0)")
        GD.print("Level: multiplayerPeer: \(multiplayer?.multiplayerPeer != nil ? "exists" : "nil")")

        // Only the server should spawn players - MultiplayerSpawner handles replication
        guard isServer else {
            GD.print("Level: [CLIENT] Not server, waiting for MultiplayerSpawner to replicate")
            // Debug: Check if spawner is ready
            if let spawner = multiplayerSpawner {
                GD.print("Level: [CLIENT] Spawner exists, spawn_path: \(spawner.spawnPath)")
            }
            return
        }

        // Skip host player in headless mode
        if DisplayServer.getName() == "headless" && id == 1 {
            GD.print("Level: Skipping headless host player")
            return
        }

        guard let container = playersContainer else {
            GD.pushError("Level: PlayersContainer not found!")
            return
        }

        // Check if player already exists
        if container.hasNode(path: NodePath(String(id))) {
            GD.print("Level: Player \(id) already exists, skipping")
            return
        }

        guard let scene = playerScene else {
            GD.pushError("Level: playerScene not set!")
            return
        }

        guard let player = scene.instantiate() as? Character else {
            GD.pushError("Level: Failed to instantiate player scene as Character")
            return
        }

        player.name = StringName(String(id))
        player.position = getSpawnPoint()

        // Add to container - MultiplayerSpawner will automatically replicate to clients
        container.addChild(node: player, forceReadableName: true)
        GD.print("Level: Server spawned player \(id) at \(player.position)")
        GD.print("Level: Player scene_file_path: '\(player.sceneFilePath)'")
        GD.print("Level: PlayersContainer children count: \(container.getChildCount())")

        // Set player info from network data
        if let playerData = Network.shared?.getPlayers()[id] {
            player.changeNick(newNick: playerData.nick)
            player.setPlayerSkin(skinColor: playerData.skin.rawValue)
            GD.print("Level: Set player \(id) nick to '\(playerData.nick)'")
        } else {
            GD.pushWarning("Level: No player data found for peer \(id)")
        }
    }

    /// Returns a random spawn point around the origin.
    private func getSpawnPoint() -> Vector3 {
        let angle = Float.random(in: 0...(2 * Float.pi))
        let radius: Float = 10.0
        let x = cos(angle) * radius
        let z = sin(angle) * radius
        return Vector3(x: x, y: 0, z: z)
    }

    /// Removes a player character when they disconnect.
    /// Only server removes - MultiplayerSpawner handles despawn replication.
    private func removePlayer(id: Int64) {
        // Only server removes players
        guard multiplayer?.isServer() == true else { return }
        guard let container = playersContainer else { return }

        let path = NodePath(String(id))
        if container.hasNode(path: path),
           let playerNode = container.getNode(path: path) {
            GD.print("Level: Server removing player \(id)")
            playerNode.queueFree()
        }
    }

    /// Called when connection attempt fails (timeout or rejection).
    private func onConnectionFailed() {
        GD.print("Level: Connection failed, returning to menu")

        // Show main menu
        mainMenu?.showMenu()
    }

    /// Called when client disconnects from server. Cleans up UI and state.
    private func onServerDisconnected() {
        GD.print("Level: Disconnected from server, cleaning up")

        // Clear inventory UI to prevent dangling reference
        inventoryUI?.clearPlayer()
        inventoryVisible = false

        // Hide chat
        multiplayerChat?.hide()
        chatVisible = false

        // Clear all players from container
        if let container = playersContainer {
            for child in container.getChildren() {
                child?.queueFree()
            }
        }

        // Show main menu
        mainMenu?.showMenu()
    }

    // MARK: - Multiplayer Chat

    private func toggleChat() {
        if mainMenu?.isMenuVisible() == true {
            return
        }

        multiplayerChat?.toggleChat()
        chatVisible = multiplayerChat?.isChatVisible() ?? false
    }

    /// Returns whether the chat panel is currently visible.
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
            // Debug keys (F1, F2)
            if keyEvent.keycode == .f1 {
                debugAddItem()
            } else if keyEvent.keycode == .f2 {
                debugPrintInventory()
            }
        }
    }

    private func onChatMessageSent(messageText: String) {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespaces)
        if trimmedMessage.isEmpty {
            return
        }

        // Send chat through the local player's Character (synced via MultiplayerSynchronizer)
        if let localPlayer = getLocalPlayer() {
            localPlayer.sendChatMessage(trimmedMessage)
        } else {
            GD.print("Level: Cannot send chat - no local player found")
        }
    }

    /// Adds a chat message to the UI. Called by Character when synced messages arrive.
    public func addChatMessage(nick: String, message: String) {
        multiplayerChat?.addMessage(nick: nick, msg: message)
    }

    // MARK: - Inventory System

    private func toggleInventory() {
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

    /// Returns whether the inventory panel is currently visible.
    public func isInventoryVisible() -> Bool {
        return inventoryVisible
    }

    private func onInventoryClosed() {
        inventoryVisible = false
    }

    /// Refreshes the inventory display (called after server sync).
    public func updateLocalInventoryDisplay() {
        inventoryUI?.refreshDisplay()
    }

    /// Returns the local player's Character node.
    private func getLocalPlayer() -> Character? {
        guard let container = playersContainer else { return nil }
        let localPlayerId = Int(multiplayer?.getUniqueId() ?? 0)
        let path = NodePath(String(localPlayerId))
        if container.hasNode(path: path) {
            return container.getNode(path: path) as? Character
        }
        return nil
    }

    // MARK: - Debug Functions

    /// Debug: Adds a random item to the local player's inventory (F1 key).
    private func debugAddItem() {
        guard let localPlayer = getLocalPlayer() else {
            GD.print("Debug: No local player found")
            return
        }

        let testItems = ["iron_sword", "health_potion", "leather_armor", "magic_gem", "iron_pickaxe"]
        let randomItem = testItems.randomElement() ?? "health_potion"
        localPlayer.sendRequestAddItem(itemId: randomItem, quantity: 1)
    }

    /// Debug: Prints the local player's inventory contents (F2 key).
    private func debugPrintInventory() {
        guard let localPlayer = getLocalPlayer(),
              let inventory = localPlayer.getInventory() else {
            GD.print("Debug: No inventory found")
            return
        }

        GD.print("=== Inventory ===")
        for i in 0..<inventory.slots.count {
            let slot = inventory.slots[i]
            if !slot.isEmpty() {
                GD.print("Slot \(i): \(slot.itemId) x\(slot.quantity)")
            }
        }
    }
}
