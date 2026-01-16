# SwiftGodot Multiplayer

A multiplayer game project using [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot) - Swift language bindings for Godot 4.4+ game engine via GDExtension.

## Project Overview

This project aims to implement a multiplayer game using SwiftGodot, migrating an existing GDScript multiplayer template to Swift while following best practices from community examples.

### Features

- **ENet Multiplayer**: Client-server networking with host/join functionality
- **Server-Authoritative Inventory**: Secure inventory system with RPC validation
- **Player Management**: Spawn/despawn with skin customization
- **Real-time Chat**: Multiplayer chat system
- **Click-to-Move Inventory UI**: Intuitive item management interface

## Project Structure

```
SwiftGodotMultiplayer/
├── Swift/                    # Swift SPM package for game logic
│   ├── Package.swift         # Swift Package Manager configuration
│   ├── Makefile              # Build automation (build, deploy, run, pack)
│   ├── .env                  # Environment variables for Makefile
│   └── SwiftLibrary/         # Main GDExtension library
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
│
├── Godot/                    # Godot project directory
│   ├── project.godot         # Godot project configuration
│   ├── addons/swift/         # Editor plugin for Swift rebuilds
│   └── bin/                  # Built Swift libraries destination
│       └── SwiftLibrary.gdextension
│
├── GDScript/                 # Reference: GDScript multiplayer implementation
│   ├── scripts/              # All GDScript source files
│   │   ├── network.gd        # Network/connection management
│   │   ├── player.gd         # Player controller with inventory
│   │   ├── level.gd          # Level management
│   │   └── ...               # Other game scripts
│   └── scenes/               # Godot scene files
│
└── StarterKitSwift/          # Reference: SwiftGodot 3D Platformer example
    └── source/               # Swift source code examples
        └── Sources/Platformer3D/
```

## Quick Start

### Prerequisites

- Godot 4.4+ (tested with 4.5)
- Swift 5.9+ or Xcode 15+
- macOS, Windows, or Linux

### Building

Navigate to the Swift folder and use the Makefile:

```bash
cd Swift

# Show configured paths
make paths

# Build Swift library
make build

# Build library + standalone executable
make build-all

# Deploy to Godot bin folder
make deploy

# Build, deploy, and create resource pack (primary workflow)
make all

# Open Godot project
make open

# Run standalone (SwiftGodotKit)
make run

# Remove build artifacts
make clean
```

Or use the Godot editor plugin: **Swift** tab > **Rebuild**

### Environment Configuration

The `.env` file in the `Swift/` folder configures:

| Variable | Description |
|----------|-------------|
| `PROJECT_NAME` | Name of the Swift library |
| `GODOT` | Path to Godot executable |
| `GODOT_PROJECT_DIRECTORY` | Path to Godot project |
| `BUILD_PATH` | Swift build output directory |
| `LIBRARY_NAME` | Output library name |
| `EXECUTABLE_NAME` | Standalone executable name |

### Test Multiplayer

1. Godot > Debug > Customize Run Instances > Enable Multiple Instances
2. Run (F5)
3. Host on one instance, Join on another

## Architecture

### Networking Layer

```
Server (Host)                    Client (Join)
     │                                │
     │◄── ENet Connection ───────────►│
     │                                │
     ├── MultiplayerSpawner ─────────►│  (auto-spawn players)
     │                                │
     ├── MultiplayerSynchronizer ────►│  (sync position, skin, chat)
     │                                │
     │◄── RPC Requests ───────────────┤  (inventory operations)
     │                                │
     ├── RPC Responses ──────────────►│  (inventory sync)
```

### Key Systems

| System | Server | Client | Sync Method |
|--------|--------|--------|-------------|
| Player Spawn | Creates Character | Receives via Spawner | MultiplayerSpawner |
| Movement | - | Local control | MultiplayerSynchronizer |
| Skin Color | - | Sets property | MultiplayerSynchronizer |
| Chat | - | Sets property | MultiplayerSynchronizer |
| Inventory | Validates & modifies | Requests via RPC | RPC |

## Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Space | Jump (double jump available) |
| Shift | Sprint |
| I | Toggle inventory |
| Tab | Toggle chat |
| F1 | Debug: Add random item |
| F2 | Debug: Print inventory |
| Escape | Close panels |

## Code Examples

### Server-Authoritative RPC

```swift
// Client sends request
func sendRequestAddItem(itemId: String, quantity: Int) {
    if multiplayer?.isServer() == true {
        requestAddItem(itemId: itemId, quantity: quantity)
    } else {
        callRpcId(peerId: 1, method: "request_add_item",
                  Variant(itemId), Variant(quantity))
    }
}

// Server validates and processes
@Callable @Rpc(mode: .anyPeer, callLocal: true, transferMode: .reliable)
func requestAddItem(itemId: String, quantity: Int) {
    switch validateInventoryRequest(allowServer: true) {
    case .notServer: return
    case .denied(let reason): GD.pushWarning(reason); return
    case .allowed: break
    }
    // Process request...
}
```

### Property Sync for Chat

```swift
// Synced via MultiplayerSynchronizer in player.tscn
@Export var syncedChatMessage: String = "" {
    didSet {
        if !syncedChatMessage.isEmpty && syncedChatMessage != oldValue {
            displayChatMessage(syncedChatMessage)
        }
    }
}

func sendChatMessage(_ message: String) {
    chatMessageId += 1  // Force sync even for same message
    syncedChatMessage = "\(nickname):\(message)"
}
```

## Adding Content

### New Item

```swift
// ItemDatabase.swift - createSampleItems()
let newItem = Item(id: "magic_staff", name: "Magic Staff",
                   description: "Channels arcane energy",
                   stackable: false, itemType: .weapon,
                   rarity: .epic, value: 500)
items[newItem.id] = newItem
```

### New Swift Class

1. Create file in `SwiftLibrary/Gameplay/` or appropriate folder
2. Add `@Godot` macro
3. Register in `SwiftLibrary.swift` types array
4. `make all`

## Reference Projects

- **GDScript/**: Original GDScript multiplayer template
- **StarterKitSwift/**: SwiftGodot patterns and examples
- **SwiftGodotTemplate/**: Editor plugin template

## Resources

- [SwiftGodot Documentation](https://migueldeicaza.github.io/SwiftGodotDocs/documentation/swiftgodot/)
- [SwiftGodot Tutorials](https://migueldeicaza.github.io/SwiftGodotDocs/tutorials/swiftgodot-tutorials/)
- [Godot High-Level Multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)

## License

MIT License - See [LICENSE](LICENSE) for details.

## Credits

- [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot) by Miguel de Icaza
- [3D Multiplayer Template](https://godotengine.org/asset-library/asset/3377) by devmoreir4
- [3D Platformer Starter Kit](https://github.com/lorenalexm/Starter-Kit-3D-Platformer-Swift) by Alex Loren
