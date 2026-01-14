import SwiftGodot

// Player character controller with multiplayer support
@Godot
public class Character: CharacterBody3D {
    // Movement constants
    private let normalSpeed: Float = 6.0
    private let sprintSpeed: Float = 10.0
    private let jumpVelocity: Float = 10.0

    // Node references
    @Export(.nodeType, "Node3D") var body: Body?
    @Export(.nodeType, "Node3D") var springArmOffset: SpringArmCharacter?

    // Skin textures
    #exportGroup("Skin Colors")
    @Export var blueTexture: CompressedTexture2D?
    @Export var yellowTexture: CompressedTexture2D?
    @Export var greenTexture: CompressedTexture2D?
    @Export var redTexture: CompressedTexture2D?

    // Runtime state
    private var currentSpeed: Float = 6.0
    private var respawnPoint = Vector3(x: 0, y: 5, z: 0)
    private var gravity: Float = 9.8
    private var canDoubleJump = true
    private var hasDoubleJumped = false

    // Inventory
    public var playerInventory: PlayerInventory?

    // Nickname label - found via node path
    private var nicknameLabel: Label3D?

    // Mesh instances for skin coloring
    private var bottomMesh: MeshInstance3D?
    private var chestMesh: MeshInstance3D?
    private var faceMesh: MeshInstance3D?
    private var limbsHeadMesh: MeshInstance3D?

    public override func _enterTree() {
        // Set multiplayer authority based on node name (which is peer_id)
        if let peerId = Int32(String(name)) {
            setMultiplayerAuthority(id: peerId)
        }

        // Enable camera only for local player
        if let camera = getNode(path: "SpringArmOffset/SpringArm3D/Camera3D") as? Camera3D {
            camera.current = isMultiplayerAuthority()
        }
    }

    public override func _ready() {
        // Get gravity from project settings
        if let gravityVariant = ProjectSettings.getSetting(name: "physics/3d/default_gravity", defaultValue: Variant(9.8)),
           let gravityValue = Float(gravityVariant) {
            gravity = gravityValue
        }

        // Get node references
        nicknameLabel = getNode(path: "PlayerNick/Nickname") as? Label3D
        bottomMesh = getNode(path: "3DGodotRobot/RobotArmature/Skeleton3D/Bottom") as? MeshInstance3D
        chestMesh = getNode(path: "3DGodotRobot/RobotArmature/Skeleton3D/Chest") as? MeshInstance3D
        faceMesh = getNode(path: "3DGodotRobot/RobotArmature/Skeleton3D/Face") as? MeshInstance3D
        limbsHeadMesh = getNode(path: "3DGodotRobot/RobotArmature/Skeleton3D/Llimbs and head") as? MeshInstance3D

        let isLocalPlayer = isMultiplayerAuthority()
        let localClientId = multiplayer?.getUniqueId() ?? 0

        GD.print("Debug: Player \(name) ready - authority: \(getMultiplayerAuthority()), local client: \(localClientId), is_local: \(isLocalPlayer)")

        // Initialize inventory
        if isLocalPlayer {
            playerInventory = PlayerInventory()
            addStartingItems()
        } else if multiplayer?.isServer() == true {
            playerInventory = PlayerInventory()
            addStartingItems()
        } else {
            // Client requesting sync for their own character
            if getMultiplayerAuthority() == localClientId {
                requestInventorySync()
            }
        }
    }

    public override func _physicsProcess(delta: Double) {
        guard isMultiplayerAuthority() else { return }

        // Check if UI is open and freeze movement
        // Level class reference will be added when Level.swift is created
        if isOnFloor() {
            // TODO: Check if chat or inventory UI is visible via Level class
            // For now, movement is always enabled
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

        velocity.y -= gravity * Float(delta)

        move()
        moveAndSlide()
        body?.animate(velocity)
    }

    public override func _process(delta: Double) {
        guard isMultiplayerAuthority() else { return }
        checkFallAndRespawn()
    }

    public func freeze() {
        velocity.x = 0
        velocity.z = 0
        currentSpeed = 0
        body?.animate(Vector3.zero)
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

    // MARK: - Network RPCs

    @Callable
    public func changeNick(newNick: String) {
        nicknameLabel?.text = newNick
    }

    public func getTextureFromSkin(_ skinColor: SkinColor) -> CompressedTexture2D? {
        switch skinColor {
        case .blue: return blueTexture
        case .yellow: return yellowTexture
        case .green: return greenTexture
        case .red: return redTexture
        }
    }

    @Callable
    public func setPlayerSkin(skinColor: Int) {
        let skin = SkinColor(rawValue: skinColor) ?? .blue
        guard let texture = getTextureFromSkin(skin) else { return }

        setMeshTexture(bottomMesh, texture: texture)
        setMeshTexture(chestMesh, texture: texture)
        setMeshTexture(faceMesh, texture: texture)
        setMeshTexture(limbsHeadMesh, texture: texture)
    }

    private func setMeshTexture(_ meshInstance: MeshInstance3D?, texture: CompressedTexture2D) {
        guard let mesh = meshInstance,
              let material = mesh.getSurfaceOverrideMaterial(surface: 0) as? StandardMaterial3D else {
            return
        }
        material.albedoTexture = texture
        mesh.setSurfaceOverrideMaterial(surface: 0, material: material)
    }

    // MARK: - Inventory Network Functions

    @Callable
    public func requestInventorySync() {
        GD.print("Debug: requestInventorySync called on player \(name)")

        guard multiplayer?.isServer() == true else { return }

        let requestingClient = multiplayer?.getRemoteSenderId() ?? 0
        if requestingClient != getMultiplayerAuthority() {
            GD.pushWarning("Client \(requestingClient) tried to request inventory for player \(getMultiplayerAuthority())")
            return
        }

        if let inventory = playerInventory {
            // Call syncInventoryToOwner on the requesting client
            rpcId(peerId: Int64(requestingClient), method: "syncInventoryToOwner", Variant(inventory.toDict()))
        }
    }

    @Callable
    public func syncInventoryToOwner(inventoryData: VariantDictionary) {
        GD.print("Debug: syncInventoryToOwner called on player \(name)")

        // Only accept from server
        guard multiplayer?.getRemoteSenderId() == 1 else { return }
        guard isMultiplayerAuthority() else { return }

        if playerInventory == nil {
            playerInventory = PlayerInventory()
        }
        playerInventory?.fromDict(inventoryData)

        // Update UI - Level will handle this when implemented
        notifyInventoryUpdate()
    }

    @Callable
    public func requestMoveItem(fromSlot: Int, toSlot: Int, quantity: Int = -1) {
        GD.print("Debug: requestMoveItem called - from: \(fromSlot) to: \(toSlot)")

        guard multiplayer?.isServer() == true else { return }

        let requestingClient = multiplayer?.getRemoteSenderId() ?? 0
        if requestingClient != getMultiplayerAuthority() {
            GD.pushWarning("Client \(requestingClient) tried to modify inventory for player \(getMultiplayerAuthority())")
            return
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
            let ownerId = getMultiplayerAuthority()
            if ownerId != 1 {
                rpcId(peerId: Int64(ownerId), method: "syncInventoryToOwner", Variant(inventory.toDict()))
            } else {
                notifyInventoryUpdate()
            }
        }
    }

    @Callable
    public func requestAddItem(itemId: String, quantity: Int = 1) {
        GD.print("Debug: requestAddItem called - item: \(itemId), qty: \(quantity)")

        guard multiplayer?.isServer() == true else { return }

        let requestingClient = multiplayer?.getRemoteSenderId() ?? 0
        if requestingClient != getMultiplayerAuthority() && requestingClient != 1 {
            GD.pushWarning("Client \(requestingClient) tried to add items to player \(getMultiplayerAuthority())")
            return
        }

        guard let inventory = playerInventory, quantity > 0 else { return }

        guard let item = ItemDatabase.shared.getItem(itemId) else {
            GD.pushWarning("Item not found: \(itemId)")
            return
        }

        let remaining = inventory.addItem(item, quantity: quantity)
        let added = quantity - remaining
        GD.print("Debug: Added \(added) \(itemId) to inventory (\(remaining) remaining)")

        if added > 0 {
            let ownerId = getMultiplayerAuthority()
            if ownerId != 1 {
                rpcId(peerId: Int64(ownerId), method: "syncInventoryToOwner", Variant(inventory.toDict()))
            } else {
                notifyInventoryUpdate()
            }
        }
    }

    @Callable
    public func requestRemoveItem(itemId: String, quantity: Int = 1) {
        GD.print("Debug: requestRemoveItem called - item: \(itemId), qty: \(quantity)")

        guard multiplayer?.isServer() == true else { return }

        let requestingClient = multiplayer?.getRemoteSenderId() ?? 0
        if requestingClient != getMultiplayerAuthority() {
            GD.pushWarning("Client \(requestingClient) tried to remove items from player \(getMultiplayerAuthority())")
            return
        }

        guard let inventory = playerInventory, quantity > 0 else { return }

        let removed = inventory.removeItem(itemId: itemId, quantity: quantity)

        if removed > 0 {
            let ownerId = getMultiplayerAuthority()
            if ownerId != 1 {
                rpcId(peerId: Int64(ownerId), method: "syncInventoryToOwner", Variant(inventory.toDict()))
            }
        }
    }

    public func getInventory() -> PlayerInventory? {
        return playerInventory
    }

    private func addStartingItems() {
        guard let inventory = playerInventory else { return }

        if let sword = ItemDatabase.shared.getItem("iron_sword") {
            _ = inventory.addItem(sword, quantity: 1)
        }
        if let potion = ItemDatabase.shared.getItem("health_potion") {
            _ = inventory.addItem(potion, quantity: 3)
        }
    }

    // Helper for RPC calls - placeholder until proper SwiftGodot RPC is implemented
    private func rpcId(peerId: Int64, method: String, _ args: Variant...) {
        // SwiftGodot RPC implementation varies - this is a stub
        // In practice, use multiplayer.rpc or direct method calls
        GD.print("RPC to \(peerId): \(method)")
    }

    // Notify inventory update - will be connected to Level when implemented
    private func notifyInventoryUpdate() {
        // Level.updateLocalInventoryDisplay() will be called when Level class exists
        GD.print("Inventory updated for player \(name)")
    }
}
