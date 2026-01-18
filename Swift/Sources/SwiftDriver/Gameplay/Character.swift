//
//  Character.swift
//  SwiftGodotMultiplayer
//
// Player controller with multiplayer support - movement, animations,
// server-authoritative inventory (RPC), skin sync, and chat via
// MultiplayerSynchronizer properties.

import SwiftGodot

/// Player character - movement, inventory RPC, skin/chat sync.
@Godot
public class Character: CharacterBody3D {
    // MARK: - Constants

    private let normalSpeed: Float = 6.0
    private let sprintSpeed: Float = 10.0
    private let jumpVelocity: Float = 6.0

    /// Maximum quantity allowed in a single inventory request (prevents abuse).
    private static let maxRequestQuantity: Int = 100

    // MARK: - Node References

    @Node("Mannequin_Medium") var body: Body?
    @Node("SpringArmOffset") var springArmOffset: SpringArmCharacter?
    @Node("PlayerNick/Nickname") var nicknameLabel: Label3D?
    @Node("Mannequin_Medium/Model/Rig_Medium/Skeleton3D/Mannequin_Medium_Body") var bodyMesh: MeshInstance3D?
    @Node("Mannequin_Medium/Model/Rig_Medium/Skeleton3D/Mannequin_Medium_Head") var headMesh: MeshInstance3D?
    @Node("Mannequin_Medium/Model/Rig_Medium/Skeleton3D/Mannequin_Medium_ArmLeft") var armLeftMesh: MeshInstance3D?
    @Node("Mannequin_Medium/Model/Rig_Medium/Skeleton3D/Mannequin_Medium_ArmRight") var armRightMesh: MeshInstance3D?
    @Node("Mannequin_Medium/Model/Rig_Medium/Skeleton3D/Mannequin_Medium_LegLeft") var legLeftMesh: MeshInstance3D?
    @Node("Mannequin_Medium/Model/Rig_Medium/Skeleton3D/Mannequin_Medium_LegRight") var legRightMesh: MeshInstance3D?

    // MARK: - Exports

    #exportGroup("Skin Colors")
    @Export var blueTexture: CompressedTexture2D?
    @Export var yellowTexture: CompressedTexture2D?
    @Export var greenTexture: CompressedTexture2D?
    @Export var redTexture: CompressedTexture2D?

    #exportGroup("Synced Properties")
    /// Synced skin color (-1=none/multicolor, 0=blue, 1=yellow, 2=green, 3=red). Automatically applies texture when changed.
    @Export var syncedSkinColor: Int = -1 {
        didSet {
            if syncedSkinColor != oldValue {
                applySkinTexture(syncedSkinColor)
            }
        }
    }

    /// Synced chat message. Format: "nick:message". When changed, displays in chat UI.
    @Export var syncedChatMessage: String = "" {
        didSet {
            if syncedChatMessage != oldValue && !syncedChatMessage.isEmpty {
                displayChatMessage(syncedChatMessage)
            }
        }
    }

    /// Counter to force sync even for same message sent twice
    @Export var chatMessageId: Int = 0

    /// Synced player nickname. When changed, updates the nickname label.
    @Export var syncedNickname: String = "" {
        didSet {
            if syncedNickname != oldValue && !syncedNickname.isEmpty {
                nicknameLabel?.text = syncedNickname
            }
        }
    }

    // MARK: - Private State

    private var currentSpeed: Float = 6.0
    private var respawnPoint = Vector3(x: 0, y: 5, z: 0)
    private var gravity: Float = 25.0  // Higher gravity for snappier feel
    private var canDoubleJump = true
    private var hasDoubleJumped = false

    // MARK: - Inventory

    /// Server-authoritative player inventory. Only modified via RPC on server.
    public var playerInventory: PlayerInventory?

    // MARK: - Lifecycle

    public override func _enterTree() {
        // Set multiplayer authority based on node name (which is peer_id)
        if let peerId = Int32(String(name)) {
            setMultiplayerAuthority(id: peerId)
        }

        // Enable camera only for local player
        if let camera = getNode(path: "SpringArmOffset/SpringArm3D/Camera3D") as? Camera3D {
            camera.current = isMultiplayerAuthority()
        }

        // Configure multiplayer synchronization
        configureMultiplayerSync()

        // Manually configure RPC methods
        configureRpcMethods()
    }

    // MARK: - Multiplayer Sync Configuration

    /// Configures the MultiplayerSynchronizer with properties to replicate.
    /// This replaces the need for an external SceneReplicationConfig resource.
    private func configureMultiplayerSync() {
        guard let sync = getNodeOrNull(path: NodePath("MultiplayerSynchronizer")) as? MultiplayerSynchronizer else {
            GD.pushWarning("Character: MultiplayerSynchronizer not found")
            return
        }

        let config = SceneReplicationConfig()

        // Define all properties to sync
        // Format: (path, spawn, replicationMode)
        // replicationMode: 0 = Never, 1 = Always, 2 = OnChange
        let syncedProperties: [(String, Bool, Int)] = [
            // Position and rotation
            (".:position", true, 1),
            ("Mannequin_Medium:rotation", true, 1),

            // Animation
            ("Mannequin_Medium/Model/AnimationPlayer_Medium:current_animation", true, 1),

            // Nickname display
            ("PlayerNick/Nickname:text", true, 1),

            // Synced @Export properties
            (".:synced_skin_color", true, 1),      // Skin color
            (".:synced_chat_message", false, 1),   // Chat (no spawn, sync always)
            (".:chat_message_id", false, 1),       // Chat ID (no spawn, sync always)
            (".:synced_nickname", true, 1),        // Nickname
        ]

        for (path, spawn, mode) in syncedProperties {
            let nodePath = NodePath(path)
            config.addProperty(path: nodePath, index: -1)

            // Configure spawn and replication mode
            config.propertySetSpawn(path: nodePath, enabled: spawn)
            config.propertySetReplicationMode(
                path: nodePath,
                mode: SceneReplicationConfig.ReplicationMode(rawValue: Int64(mode)) ?? .always
            )
        }

        sync.replicationConfig = config
        GD.print("Character: Configured MultiplayerSynchronizer with \(syncedProperties.count) properties")
    }

    /// Manually configure RPC settings for all @Rpc methods.
    private func configureRpcMethods() {
        // Helper to create config dictionary
        func makeRpcConfig(mode: MultiplayerAPI.RPCMode, callLocal: Bool, transferMode: MultiplayerPeer.TransferMode) -> VariantDictionary {
            let config = VariantDictionary()
            config["rpc_mode"] = Variant(mode.rawValue)
            config["call_local"] = Variant(callLocal)
            config["transfer_mode"] = Variant(transferMode.rawValue)
            config["channel"] = Variant(0)
            return config
        }

        // Configure all RPC methods (inventory operations)
        rpcConfig(method: StringName("request_inventory_sync"), config: Variant(makeRpcConfig(mode: .anyPeer, callLocal: true, transferMode: .reliable)))
        rpcConfig(method: StringName("sync_inventory_to_owner"), config: Variant(makeRpcConfig(mode: .anyPeer, callLocal: true, transferMode: .reliable)))
        rpcConfig(method: StringName("request_move_item"), config: Variant(makeRpcConfig(mode: .anyPeer, callLocal: true, transferMode: .reliable)))
        rpcConfig(method: StringName("request_add_item"), config: Variant(makeRpcConfig(mode: .anyPeer, callLocal: true, transferMode: .reliable)))
        rpcConfig(method: StringName("request_remove_item"), config: Variant(makeRpcConfig(mode: .anyPeer, callLocal: true, transferMode: .reliable)))
    }

    public override func _ready() {
        // Get gravity from project settings
        if let gravityVariant = ProjectSettings.getSetting(name: "physics/3d/default_gravity", defaultValue: Variant(9.8)),
           let gravityValue = Float(gravityVariant) {
            gravity = gravityValue
        }

        let isLocalPlayer = isMultiplayerAuthority()
        let isServer = multiplayer?.isServer() ?? false

        GD.print("Character._ready: name=\(name), isLocalPlayer=\(isLocalPlayer), isServer=\(isServer)")

        // Initialize inventory based on role
        if isLocalPlayer {
            playerInventory = PlayerInventory()
            addStartingItems()

            // If this is our player on a client, initialize our player info
            if !isServer {
                initializeLocalPlayerInfo()
            }
        } else if isServer {
            playerInventory = PlayerInventory()
            addStartingItems()
        } else {
            // Client requesting sync for their own character
            let localClientId = multiplayer?.getUniqueId() ?? 0
            if getMultiplayerAuthority() == localClientId {
                requestInventorySync()
            }
        }

        // Always apply initial skin texture (syncedSkinColor might already be set)
        applySkinTexture(syncedSkinColor)
    }

    /// Initializes local player info from Network when client receives their player.
    private func initializeLocalPlayerInfo() {
        guard let playerInfo = Network.shared?.getLocalPlayerInfo() else {
            GD.print("Character: No local player info found")
            return
        }

        GD.print("Character: Initializing local player with nick='\(playerInfo.nick)', skin=\(playerInfo.skin.rawValue)")

        // Set nickname - this syncs via MultiplayerSynchronizer
        syncedNickname = playerInfo.nick

        // Set skin - this updates syncedSkinColor which syncs via MultiplayerSynchronizer
        syncedSkinColor = playerInfo.skin.rawValue
    }

    public override func _physicsProcess(delta: Double) {
        guard isMultiplayerAuthority() else { return }

        // Check if UI is open and freeze movement
        if isOnFloor() {
            if let currentScene = getTree()?.currentScene as? Level {
                if currentScene.isChatVisible() || currentScene.isInventoryVisible() {
                    freeze()
                    return
                }
            }
        }

        // Handle jumping
        if isOnFloor() {
            canDoubleJump = true
            hasDoubleJumped = false

            if Input.isActionJustPressed(action: "jump") {
                velocity.y = jumpVelocity
                canDoubleJump = true
                body?.playJumpAnimation(jumpType: "Jump")
            }
        } else {
            velocity.y -= gravity * Float(delta)

            // Double jump
            if canDoubleJump && !hasDoubleJumped && Input.isActionJustPressed(action: "jump") {
                velocity.y = jumpVelocity
                hasDoubleJumped = true
                canDoubleJump = false
                body?.playJumpAnimation(jumpType: "Jump2")
            }
        }

        move()
        moveAndSlide()
        body?.animate(velocity, isOnFloor: isOnFloor(), isRunning: isRunning())
    }

    public override func _process(delta: Double) {
        guard isMultiplayerAuthority() else { return }
        checkFallAndRespawn()
    }

    // MARK: - Movement

    /// Freezes player movement (used when UI is open).
    public func freeze() {
        velocity.x = 0
        velocity.z = 0
        currentSpeed = 0
        body?.animate(Vector3.zero, isOnFloor: isOnFloor(), isRunning: false)
    }

    private func move() {
        var inputDirection = Vector2.zero
        if isMultiplayerAuthority() {
            inputDirection = Input.getVector(
                negativeX: "move_left",
                positiveX: "move_right",
                negativeY: "move_forward",
                positiveY: "move_backward"
            )
        }

        var direction = transform.basis * Vector3(x: inputDirection.x, y: 0, z: inputDirection.y)
        direction = direction.normalized()

        _ = isRunning()

        if let springArm = springArmOffset {
            direction = direction.rotated(axis: .up, angle: Double(springArm.rotation.y))
        }

        if direction.x != 0 || direction.z != 0 {
            velocity.x = direction.x * currentSpeed
            velocity.z = direction.z * currentSpeed
            body?.applyRotation(velocity)
            return
        }

        velocity.x = Float(GD.moveToward(from: Double(velocity.x), to: 0, delta: Double(currentSpeed)))
        velocity.z = Float(GD.moveToward(from: Double(velocity.z), to: 0, delta: Double(currentSpeed)))
    }

    /// Returns whether the player is currently sprinting.
    public func isRunning() -> Bool {
        if Input.isActionPressed(action: "shift") {
            currentSpeed = sprintSpeed
            return true
        } else {
            currentSpeed = normalSpeed
            return false
        }
    }

    private func checkFallAndRespawn() {
        if globalTransform.origin.y < -15.0 {
            respawn()
        }
    }

    private func respawn() {
        globalTransform.origin = respawnPoint
        velocity = Vector3.zero
    }

    // MARK: - Chat System

    /// Sends a chat message by updating the synced property.
    /// - Parameter message: The message text to send.
    public func sendChatMessage(_ message: String) {
        guard let nick = nicknameLabel?.text, !nick.isEmpty else {
            GD.print("Character: Cannot send chat - no nickname")
            return
        }

        // Format: "nick:message"
        chatMessageId += 1  // Increment to force sync even for same message
        syncedChatMessage = "\(nick):\(message)"
        GD.print("Character: Sent chat message: \(syncedChatMessage)")
    }

    /// Displays a received chat message in the UI.
    private func displayChatMessage(_ formattedMessage: String) {
        // Parse "nick:message" format
        guard let colonIndex = formattedMessage.firstIndex(of: ":") else {
            GD.print("Character: Invalid chat message format: \(formattedMessage)")
            return
        }

        let nick = String(formattedMessage[..<colonIndex])
        let message = String(formattedMessage[formattedMessage.index(after: colonIndex)...])

        GD.print("Character: Displaying chat - nick='\(nick)', msg='\(message)'")

        // Find the chat UI and add the message
        if let level = getTree()?.currentScene as? Level {
            level.addChatMessage(nick: nick, message: message)
        }
    }

    // MARK: - Skin Customization

    /// Target hue values for the shader (HSV hue 0.0-1.0, or -1 for original colors)
    /// These SET the hue of all colored pixels to create uniform team colors
    private func getTargetHue(_ skinColor: SkinColor) -> Float {
        switch skinColor {
        case .none: return -1.0      // Keep original multicolor texture
        case .blue: return 0.58      // Blue (~210 degrees)
        case .green: return 0.33     // Green (~120 degrees)
        case .yellow: return 0.15    // Yellow (~55 degrees)
        case .red: return 0.0        // Red (0 degrees)
        }
    }

    /// Applies the skin color by loading the shader material and setting target_hue.
    /// Called automatically when syncedSkinColor changes.
    /// If colorId is -1 (none), keeps the original material (no shader applied).
    private func applySkinTexture(_ colorId: Int) {
        let skin = SkinColor(rawValue: colorId) ?? .none
        let targetHue = getTargetHue(skin)

        // If no color specified, keep original material
        if targetHue < 0 {
            GD.print("Character: Keeping original multicolor texture (no skin color specified)")
            return
        }

        // Load the shader material
        guard let shaderMaterial = ResourceLoader.load(path: "res://assets/materials/mannequin_color.tres") as? ShaderMaterial else {
            GD.print("Character: Failed to load shader material")
            return
        }

        // Apply shader material with the target hue to all 6 Mannequin mesh parts
        applyShaderToMesh(bodyMesh, material: shaderMaterial, hue: targetHue)
        applyShaderToMesh(headMesh, material: shaderMaterial, hue: targetHue)
        applyShaderToMesh(armLeftMesh, material: shaderMaterial, hue: targetHue)
        applyShaderToMesh(armRightMesh, material: shaderMaterial, hue: targetHue)
        applyShaderToMesh(legLeftMesh, material: shaderMaterial, hue: targetHue)
        applyShaderToMesh(legRightMesh, material: shaderMaterial, hue: targetHue)

        GD.print("Character: Applied skin target hue \(targetHue) for color \(colorId)")
    }

    private func applyShaderToMesh(_ meshInstance: MeshInstance3D?, material: ShaderMaterial, hue: Float) {
        guard let mesh = meshInstance else {
            return
        }

        // Clone the material to avoid modifying shared resource
        guard let clonedMaterial = material.duplicate() as? ShaderMaterial else {
            GD.print("Character: Failed to clone shader material for \(mesh.name)")
            return
        }

        // Set the target hue
        clonedMaterial.setShaderParameter(param: "target_hue", value: Variant(hue))

        // Apply as surface override
        mesh.setSurfaceOverrideMaterial(surface: 0, material: clonedMaterial)
    }

    // MARK: - Inventory RPC Validation

    /// Result of RPC request validation.
    private enum RpcValidationResult {
        case allowed
        case denied(reason: String)
        case notServer
    }

    /// Validates an inventory RPC request.
    /// - Parameter allowServer: Whether to allow requests from server (peer 1).
    /// - Returns: Validation result indicating if request should proceed.
    private func validateInventoryRequest(allowServer: Bool = false) -> RpcValidationResult {
        guard multiplayer?.isServer() == true else {
            return .notServer
        }

        let requestingClient = multiplayer?.getRemoteSenderId() ?? 0
        let isLocalCall = requestingClient == 0
        let isFromOwner = requestingClient == getMultiplayerAuthority()
        let isFromServer = requestingClient == 1

        if isLocalCall || isFromOwner || (allowServer && isFromServer) {
            return .allowed
        }

        return .denied(reason: "Client \(requestingClient) unauthorized for player \(getMultiplayerAuthority())")
    }

    /// Syncs inventory to the owner client after server modification.
    private func syncInventoryToClient() {
        guard let inventory = playerInventory else { return }
        let ownerId = getMultiplayerAuthority()
        if ownerId != 1 {
            callRpcId(peerId: Int64(ownerId), method: "sync_inventory_to_owner", Variant(inventory.toDict()))
        } else {
            notifyInventoryUpdate()
        }
    }

    // MARK: - Inventory Network Functions

    /// Requests inventory sync from server. Called by clients to get their inventory state.
    @Callable
    @Rpc(mode: .anyPeer, callLocal: true, transferMode: .reliable)
    public func requestInventorySync() {
        switch validateInventoryRequest() {
        case .notServer:
            return
        case .denied(let reason):
            GD.pushWarning("requestInventorySync: \(reason)")
            return
        case .allowed:
            break
        }

        if let inventory = playerInventory {
            let ownerId = getMultiplayerAuthority()
            let requestingClient = multiplayer?.getRemoteSenderId() ?? 0
            let isLocalCall = requestingClient == 0

            if ownerId != 1 && !isLocalCall {
                callRpcId(peerId: Int64(requestingClient), method: "sync_inventory_to_owner", Variant(inventory.toDict()))
            } else {
                notifyInventoryUpdate()
            }
        }
    }

    /// Receives inventory sync from server. Only accepts data from server (peer 1).
    @Callable
    @Rpc(mode: .anyPeer, callLocal: true, transferMode: .reliable)
    public func syncInventoryToOwner(inventoryData: VariantDictionary) {
        // Only accept from server
        guard multiplayer?.getRemoteSenderId() == 1 else { return }
        guard isMultiplayerAuthority() else { return }

        if playerInventory == nil {
            playerInventory = PlayerInventory()
        }
        playerInventory?.fromDict(inventoryData)
        notifyInventoryUpdate()
    }

    /// Requests to move an item between inventory slots. Server-authoritative.
    /// - Parameters:
    ///   - fromSlot: Source slot index.
    ///   - toSlot: Destination slot index.
    ///   - quantity: Amount to move (-1 for all).
    @Callable
    @Rpc(mode: .anyPeer, callLocal: true, transferMode: .reliable)
    public func requestMoveItem(fromSlot: Int, toSlot: Int, quantity: Int = -1) {
        switch validateInventoryRequest() {
        case .notServer:
            return
        case .denied(let reason):
            GD.pushWarning("requestMoveItem: \(reason)")
            return
        case .allowed:
            break
        }

        guard let inventory = playerInventory else { return }

        // Validate slot indices
        guard fromSlot >= 0 && fromSlot < PlayerInventory.inventorySize &&
              toSlot >= 0 && toSlot < PlayerInventory.inventorySize else {
            GD.pushWarning("Invalid slot indices: from=\(fromSlot) to=\(toSlot)")
            return
        }

        var success = false
        if quantity == -1 {
            success = inventory.moveItem(fromIndex: fromSlot, toIndex: toSlot)
            if !success {
                success = inventory.swapItems(fromIndex: fromSlot, toIndex: toSlot)
            }
        } else {
            success = inventory.moveItem(fromIndex: fromSlot, toIndex: toSlot, quantity: quantity)
        }

        if success {
            syncInventoryToClient()
        }
    }

    /// Requests to add an item to inventory. Server-authoritative.
    /// - Parameters:
    ///   - itemId: The item ID from ItemDatabase.
    ///   - quantity: Amount to add (clamped to maxRequestQuantity).
    @Callable
    @Rpc(mode: .anyPeer, callLocal: true, transferMode: .reliable)
    public func requestAddItem(itemId: String, quantity: Int = 1) {
        switch validateInventoryRequest(allowServer: true) {
        case .notServer:
            return
        case .denied(let reason):
            GD.pushWarning("requestAddItem: \(reason)")
            return
        case .allowed:
            break
        }

        // Validate quantity
        guard quantity > 0 else {
            GD.pushWarning("requestAddItem: Invalid quantity \(quantity)")
            return
        }

        let clampedQuantity = min(quantity, Character.maxRequestQuantity)
        if clampedQuantity != quantity {
            GD.pushWarning("requestAddItem: Quantity clamped from \(quantity) to \(clampedQuantity)")
        }

        guard let inventory = playerInventory else { return }

        guard let item = ItemDatabase.shared?.getItem(itemId) else {
            GD.pushWarning("requestAddItem: Item not found: \(itemId)")
            return
        }

        let remaining = inventory.addItem(item, quantity: clampedQuantity)
        let added = clampedQuantity - remaining

        if added > 0 {
            syncInventoryToClient()
        }
    }

    /// Requests to remove an item from inventory. Server-authoritative.
    /// - Parameters:
    ///   - itemId: The item ID to remove.
    ///   - quantity: Amount to remove (clamped to maxRequestQuantity).
    @Callable
    @Rpc(mode: .anyPeer, callLocal: true, transferMode: .reliable)
    public func requestRemoveItem(itemId: String, quantity: Int = 1) {
        switch validateInventoryRequest() {
        case .notServer:
            return
        case .denied(let reason):
            GD.pushWarning("requestRemoveItem: \(reason)")
            return
        case .allowed:
            break
        }

        // Validate quantity
        guard quantity > 0 else {
            GD.pushWarning("requestRemoveItem: Invalid quantity \(quantity)")
            return
        }

        let clampedQuantity = min(quantity, Character.maxRequestQuantity)
        if clampedQuantity != quantity {
            GD.pushWarning("requestRemoveItem: Quantity clamped from \(quantity) to \(clampedQuantity)")
        }

        guard let inventory = playerInventory else { return }

        let removed = inventory.removeItem(itemId: itemId, quantity: clampedQuantity)

        if removed > 0 {
            syncInventoryToClient()
        }
    }

    /// Returns the player's inventory.
    public func getInventory() -> PlayerInventory? {
        return playerInventory
    }

    // MARK: - Client-side RPC Calls

    /// Sends request to server to add an item. Handles both server and client cases.
    /// - Parameters:
    ///   - itemId: The item ID to add.
    ///   - quantity: Amount to add.
    public func sendRequestAddItem(itemId: String, quantity: Int = 1) {
        // If we're the server, call directly to avoid RPC warning
        if multiplayer?.isServer() == true {
            requestAddItem(itemId: itemId, quantity: quantity)
        } else {
            callRpcId(peerId: 1, method: "request_add_item", Variant(itemId), Variant(quantity))
        }
    }

    /// Sends request to server to move an item.
    /// - Parameters:
    ///   - fromSlot: Source slot index.
    ///   - toSlot: Destination slot index.
    public func sendRequestMoveItem(fromSlot: Int, toSlot: Int) {
        if multiplayer?.isServer() == true {
            requestMoveItem(fromSlot: fromSlot, toSlot: toSlot, quantity: -1)
        } else {
            callRpcId(peerId: 1, method: "request_move_item", Variant(fromSlot), Variant(toSlot), Variant(-1))
        }
    }

    /// Sends request to server to remove an item.
    /// - Parameters:
    ///   - itemId: The item ID to remove.
    ///   - quantity: Amount to remove.
    public func sendRequestRemoveItem(itemId: String, quantity: Int = 1) {
        if multiplayer?.isServer() == true {
            requestRemoveItem(itemId: itemId, quantity: quantity)
        } else {
            callRpcId(peerId: 1, method: "request_remove_item", Variant(itemId), Variant(quantity))
        }
    }

    private func addStartingItems() {
        guard let inventory = playerInventory,
              let db = ItemDatabase.shared else { return }

        if let sword = db.getItem("iron_sword") {
            _ = inventory.addItem(sword, quantity: 1)
        }
        if let potion = db.getItem("health_potion") {
            _ = inventory.addItem(potion, quantity: 3)
        }
    }

    /// Helper for RPC calls using SwiftGodot's Node.rpcId.
    /// Logs errors if the RPC call fails.
    private func callRpcId(peerId: Int64, method: String, _ args: Variant...) {
        let methodName = StringName(method)
        var error: GodotError = .ok

        switch args.count {
        case 0:
            error = rpcId(peerId: peerId, method: methodName)
        case 1:
            error = rpcId(peerId: peerId, method: methodName, args[0])
        case 2:
            error = rpcId(peerId: peerId, method: methodName, args[0], args[1])
        case 3:
            error = rpcId(peerId: peerId, method: methodName, args[0], args[1], args[2])
        default:
            GD.pushError("callRpcId: Too many arguments")
            return
        }

        if error != .ok {
            GD.pushWarning("RPC call '\(method)' to peer \(peerId) failed with error: \(error)")
        }
    }

    /// Notifies the UI that inventory has been updated.
    private func notifyInventoryUpdate() {
        if isMultiplayerAuthority() {
            if let level = getTree()?.currentScene as? Level {
                level.updateLocalInventoryDisplay()
            }
        }
    }
}
