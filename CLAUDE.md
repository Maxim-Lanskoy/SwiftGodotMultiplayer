# CLAUDE.md - Project Context for AI Assistants

## Project Overview

A complete multiplayer game template using SwiftGodot - Swift bindings for Godot 4.5+ via GDExtension. Features ENet networking, server-authoritative inventory, real-time chat, and player customization.

## Technology Stack

- **Engine**: Godot 4.5+ (GDExtension)
- **Language**: Swift 5.9+ via SwiftGodot
- **Build**: Swift Package Manager + Makefile
- **Networking**: ENet multiplayer with MultiplayerSpawner/Synchronizer

## Directory Structure

```
SwiftGodotMultiplayer/
├── Swift/                      # Swift SPM package
│   ├── Package.swift
│   ├── Makefile               # Build automation
│   ├── .env                   # Build configuration
│   └── SwiftLibrary/          # GDExtension library
│       ├── SwiftLibrary.swift # Entry point, type registration
│       ├── Network/           # Networking layer
│       │   └── Network.swift  # Connection management, ENet
│       ├── Gameplay/          # Game logic
│       │   ├── Level.swift    # Scene manager, player spawning
│       │   ├── Character.swift # Player controller, inventory RPC
│       │   ├── Body.swift     # Animation controller
│       │   ├── SpringArmCharacter.swift # Camera controller
│       │   ├── PlayerInventory.swift    # Inventory grid (20 slots)
│       │   ├── InventorySlot.swift      # Slot data model
│       │   ├── Item.swift     # Item data model
│       │   └── ItemDatabase.swift # Item registry singleton
│       └── UI/                # User interface
│           ├── InventoryUI.swift     # Inventory panel
│           ├── InventorySlotUI.swift # Slot UI component
│           ├── MainMenuUI.swift      # Host/join menu
│           └── MultiplayerChatUI.swift # Chat panel
├── Godot/            # Godot project that loads the Swift GDExtension
├── GDScript/         # Reference: Original multiplayer implementation
├── StarterKitSwift/  # Reference: SwiftGodot code patterns
└── SwiftGodot.docc/  # Godot project
```

## Build Commands

```bash
cd Swift
make all       # Build, deploy, and pack resources (primary workflow)
make build     # Build Swift library only
make build-all # Build library + standalone executable
make deploy    # Copy libraries to Godot/bin
make open      # Open Godot project
make server    # Start headless dedicated server
make run       # Run standalone with SwiftGodotKit
make paths     # Show configured paths
make clean     # Remove build artifacts
```

## Multiplayer Architecture

### Overview

The game uses a client-server architecture with:
- **ENet** for reliable UDP transport
- **MultiplayerSpawner** for automatic player replication
- **MultiplayerSynchronizer** for property sync (position, rotation, skin, chat)
- **RPC** for server-authoritative inventory operations

### Property Sync (MultiplayerSynchronizer)

Properties synced automatically via `player.tscn` MultiplayerSynchronizer:
- `position`, `rotation` - movement
- `synced_skin_color` - player appearance
- `synced_chat_message`, `chat_message_id` - chat messages

```swift
// Character.swift - Synced properties with didSet observers
@Export var syncedSkinColor: Int = 0 {
    didSet {
        if syncedSkinColor != oldValue {
            applySkinTexture(syncedSkinColor)
        }
    }
}

@Export var syncedChatMessage: String = "" {
    didSet {
        if !syncedChatMessage.isEmpty && syncedChatMessage != oldValue {
            displayChatMessage(syncedChatMessage)
        }
    }
}
```

### RPC Configuration

SwiftGodot requires manual RPC configuration via `rpcConfig()`:

```swift
override func _enterTree() {
    configureRpcMethods()
}

private func configureRpcMethods() {
    func makeRpcConfig(mode: MultiplayerAPI.RPCMode, callLocal: Bool,
                       transferMode: MultiplayerPeer.TransferMode) -> VariantDictionary {
        let config = VariantDictionary()
        config["rpc_mode"] = Variant(mode.rawValue)
        config["call_local"] = Variant(callLocal)
        config["transfer_mode"] = Variant(transferMode.rawValue)
        config["channel"] = Variant(0)
        return config
    }

    rpcConfig(method: StringName("request_add_item"),
              config: Variant(makeRpcConfig(mode: .anyPeer, callLocal: true, transferMode: .reliable)))
}

@Callable
@Rpc(mode: .anyPeer, callLocal: true, transferMode: .reliable)
func requestAddItem(itemId: String, quantity: Int = 1) {
    // Server validates and processes
}
```

### Server-Authoritative Inventory

1. Client calls `sendRequestAddItem()` which routes to server via RPC
2. Server validates request (ownership, quantity limits)
3. Server modifies inventory
4. Server syncs back via `syncInventoryToOwner` RPC

```swift
// Validation pattern
private enum RpcValidationResult {
    case allowed
    case denied(reason: String)
    case notServer
}

private func validateInventoryRequest(allowServer: Bool = false) -> RpcValidationResult {
    guard multiplayer?.isServer() == true else { return .notServer }
    let senderId = multiplayer?.getRemoteSenderId() ?? 0
    let isLocalCall = senderId == 0
    let isFromOwner = senderId == getMultiplayerAuthority()
    if isLocalCall || isFromOwner || (allowServer && senderId == 1) { return .allowed }
    return .denied(reason: "Unauthorized")
}
```

### Connection Handling

```swift
// Network.swift - Connection with timeout
public func joinGame(nickname: String, skinColorStr: String, address: String) -> GodotError {
    // ... setup peer ...
    isConnecting = true
    startConnectionTimeout()  // 10 second timeout
    return .ok
}

// Signals
@Signal var playerConnected: SignalWithArguments<Int, VariantDictionary>
@Signal var serverDisconnected: SimpleSignal
@Signal var connectionAttemptFailed: SimpleSignal
```

## GDExtension Configuration

File: `Godot/bin/SwiftLibrary.gdextension`

```ini
[configuration]
entry_symbol = "swift_entry_point"
compatibility_minimum = 4.5

[libraries]
macos.debug = "res://bin/libSwiftLibrary.dylib"

[dependencies]
macos.debug = {"res://bin/libSwiftGodot.dylib" : ""}
```

## Environment Variables (.env)

The `.env` file in the `Swift/` folder configures build paths:

```bash
export PROJECT_NAME=SwiftLibrary
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_PROJECT_DIRECTORY=/path/to/Godot
export GODOT_BIN_PATH=$(GODOT_PROJECT_DIRECTORY)/bin
export BUILD_PATH=./.build
export LIBRARY_NAME=$(PROJECT_NAME)
export EXECUTABLE_NAME=MultiplayerSwift
```

## SwiftGodot Patterns

### Singleton (Godot Autoload)

```swift
@Godot
public class Network: Node {
    nonisolated(unsafe) public static var shared: Network?

    public override func _ready() {
        Network.shared = self
    }

    public override func _exitTree() {
        if Network.shared === self { Network.shared = nil }
    }
}
// Usage: Network.shared?.startHost(...)
```

### Signal Connections (Weak Self)

```swift
override func _ready() {
    Network.shared?.playerConnected.connect { [weak self] peerId, info in
        self?.onPlayerConnected(peerId: peerId, playerInfo: info)
    }
}
```

### Node References

```swift
@Node("Path/To/Child") var childNode: SomeNode?
```

## Common Tasks

### Adding a New Swift Class

1. Create file in `Swift/SwiftLibrary/`
2. Use `@Godot` macro for node classes
3. Add type to `godotTypes` array in main entry point
4. Rebuild using either:
   - Terminal: `cd Swift && make all`
   - Editor: Click **Swift** tab → **Rebuild**

### Testing Multiplayer Locally

1. Build and deploy with `make all`
2. Open Godot with `make open`
3. Use Debug > Customize Run Instances > Enable Multiple Instances
4. Run project (F5)

### Adding New Items

Edit `ItemDatabase.swift` in `createSampleItems()`:

```swift
let newItem = Item(
    id: "unique_id",
    name: "Display Name",
    description: "Item description",
    stackable: true,
    maxStack: 10,
    itemType: .consumable,
    rarity: .common,
    value: 25
)
newItem.icon = placeholderIcon
items[newItem.id] = newItem
```

## Important Notes

- Use `[weak self]` in signal closures
- RPC requires both `@Callable` and `@Rpc` macros
- Call `rpcConfig()` in `_enterTree()` for each RPC method
- Use optional chaining: `Network.shared?.method()`
- `nonisolated(unsafe)` for Swift 6 static singletons

## Reference Links

- [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot)
- [SwiftGodot Docs](https://migueldeicaza.github.io/SwiftGodotDocs/documentation/swiftgodot/)
- [Godot Multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
