# CLAUDE.md - Project Context for AI Assistants

## Project Goal

Migrate a GDScript multiplayer game template to Swift using SwiftGodot GDExtension bindings, combining best practices from reference projects while maintaining the existing Makefile-based workflow and integrating the Godot editor rebuild plugin.

## Technology Stack

- **Game Engine**: Godot 4.5 (GDExtension system)
- **Language**: Swift 5.9+ via SwiftGodot bindings
- **Build System**: Swift Package Manager + Makefile
- **Networking**: ENet multiplayer (fully implemented in Swift)

## Key Directories

| Directory | Purpose |
|-----------|---------|
| `Swift/` | Main Swift SPM package for the game |
| `Swift/SwiftLibrary/` | Game implementation source files |
| `Godot/` | Godot project that loads the Swift GDExtension |
| `GDScript/` | Reference: Original multiplayer implementation |
| `StarterKitSwift/` | Reference: SwiftGodot code patterns |
| `SwiftGodotTemplate/` | Reference: Original editor plugin template |
| `SwiftGodot.docc/` | SwiftGodot documentation bundle |

## Build Commands

```bash
cd Swift
make all       # Build, deploy, and pack resources (primary workflow)
make build     # Build Swift library only
make build-all # Build library + standalone executable
make deploy    # Copy libraries to Godot/bin
make open      # Open Godot project
make run       # Run standalone with SwiftGodotKit
make paths     # Show configured paths
make clean     # Remove build artifacts
```

## Current Swift Implementation

### Source Files

| File | Purpose |
|------|---------|
| `SwiftLibrary.swift` | Entry point, type registration |
| `Network.swift` | Connection management, ENet peer handling |
| `Level.swift` | Player spawning, game state, chat handling |
| `Character.swift` | Player controller with server-authoritative inventory |
| `PlayerInventory.swift` | Inventory grid system (20 slots) |
| `InventorySlot.swift` | Single slot data container |
| `Item.swift` | Item data model with types/rarities |
| `ItemDatabase.swift` | Singleton item registry |
| `InventoryUI.swift` | Inventory panel with click-to-move system |
| `InventorySlotUI.swift` | Individual slot UI component |
| `MainMenuUI.swift` | Main menu with host/join/quit options |
| `MultiplayerChatUI.swift` | Real-time chat panel |

### Key Classes

```swift
// Network singleton - manages ENet connections
Network.shared?.startHost(nickname: "Host", skinColorStr: "blue")
Network.shared?.joinGame(nickname: "Player", skinColorStr: "red", address: "127.0.0.1")

// ItemDatabase singleton - item registry
ItemDatabase.shared?.getItem("iron_sword")

// Character - player controller with inventory RPC
Character: CharacterBody3D  // @Rpc methods for server-authoritative inventory
```

## SwiftGodot Patterns

### Class Registration

```swift
import SwiftGodot

@Godot
class MyNode: Node3D {
    @Export var speed: Double = 10.0
    @Signal var myEvent: SignalWithArguments<Int>
    @Node("ChildPath") var childNode: Node3D?

    override func _ready() { }
    override func _physicsProcess(delta: Double) { }
}
```

### RPC Methods (Multiplayer)

```swift
@Godot
class NetworkedNode: Node {
    override func _enterTree() {
        _configureRpc()  // Required for @Rpc methods
    }

    // Server-authoritative RPC
    @Rpc(mode: .anyPeer, callLocal: false, transferMode: .reliable)
    @Callable
    func requestAction(data: String) {
        guard multiplayer?.isServer() == true else { return }
        let senderId = multiplayer?.getRemoteSenderId() ?? 0
        // Validate and process...
    }

    // Broadcast to all clients
    @Rpc(mode: .authority, callLocal: true, transferMode: .reliable)
    @Callable
    func syncState(data: VariantDictionary) {
        // Update local state
    }
}
```

### Calling RPC Methods

```swift
// Call on specific peer
_ = rpcId(peerId: 1, method: StringName("requestAction"), Variant("data"))

// Call on all peers (requires authority)
_ = rpc(method: StringName("syncState"), Variant(dict))
```

### Singleton Pattern (Godot Autoload)

For Node-derived singletons, use Godot's Autoload system:

```swift
@Godot
public class MySingleton: Node {
    /// Shared instance. Set when Godot instantiates the Autoload.
    nonisolated(unsafe) public static var shared: MySingleton?

    public override func _ready() {
        MySingleton.shared = self
    }

    public override func _exitTree() {
        if MySingleton.shared === self {
            MySingleton.shared = nil
        }
    }
}

// Usage (always use optional chaining)
MySingleton.shared?.doSomething()
```

Configure as Autoload in Godot: Project Settings > Autoload > Add the scene/script.

Note: `nonisolated(unsafe)` is needed for Swift 6 concurrency. The `_exitTree()` cleanup prevents dangling pointers if the node is freed.

### Signal Connections with Weak Self

```swift
override func _ready() {
    someSignal.connect { [weak self] args in
        self?.handleSignal(args)
    }
}
```

## Multiplayer Architecture

### Server-Authoritative Inventory

1. Client sends request via RPC: `requestAddItem`, `requestRemoveItem`, `requestMoveItem`
2. Server validates request (checks ownership, item existence)
3. Server modifies inventory
4. Server syncs back to client via `receiveInventorySync`

### RPC Validation Pattern

```swift
private enum RpcValidationResult {
    case allowed
    case denied(reason: String)
    case notServer
}

private func validateInventoryRequest(allowServer: Bool = false) -> RpcValidationResult {
    guard multiplayer?.isServer() == true else { return .notServer }
    let requestingClient = multiplayer?.getRemoteSenderId() ?? 0
    let isLocalCall = requestingClient == 0
    let isFromOwner = requestingClient == getMultiplayerAuthority()
    let isFromServer = requestingClient == 1
    if isLocalCall || isFromOwner || (allowServer && isFromServer) { return .allowed }
    return .denied(reason: "Unauthorized")
}
```

### Network Events

```swift
// Server-side player events
Network.shared?.playerConnected.connect { peerId, playerInfo in
    // Spawn player character
}
multiplayer?.peerDisconnected.connect { id in
    // Remove player character
}
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

## Editor Plugin Integration

The Swift editor plugin at `Godot/addons/swift/`:

| File | Purpose |
|------|---------|
| `plugin.cfg` | Plugin metadata |
| `swift_plugin.gd` | Main editor plugin (adds "Swift" tab) |
| `swift_panel.gd` | Build panel logic |
| `swift_panel.tscn` | Panel UI |

**Features:**
- Adds a **Swift** tab to the Godot editor
- **Rebuild** button compiles Swift and deploys to `bin/`
- **Clean** checkbox runs `swift package clean` before build
- Automatically restarts editor after successful build
- Uses same build directory as Makefile (`Swift/.build`)

## Debug Keys

| Key | Action |
|-----|--------|
| F1 | Add random test item to inventory |
| F2 | Print inventory contents to console |
| Tab | Toggle multiplayer chat |
| I | Toggle inventory panel |
| Escape | Close inventory / cancel held item |

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

- SwiftGodot requires Swift 5.9+ (Xcode 15+)
- Always call `_configureRpc()` in `_enterTree()` for classes with `@Rpc` methods
- Use optional chaining for singletons: `Network.shared?.method()`
- Use `[weak self]` in signal closures to avoid retain cycles
- RPC validation: always check `multiplayer?.isServer()` and sender authority
- The `bin/` folder needs both `libSwiftLibrary.dylib` and `libSwiftGodot.dylib`

## Reference Links

- [SwiftGodot GitHub](https://github.com/migueldeicaza/SwiftGodot)
- [SwiftGodot Docs](https://migueldeicaza.github.io/SwiftGodotDocs/documentation/swiftgodot/)
- [SwiftGodot Tutorials](https://migueldeicaza.github.io/SwiftGodotDocs/tutorials/swiftgodot-tutorials/)
- [Godot Multiplayer Docs](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
