# CLAUDE.md - Project Context for AI Assistants

## Project Goal

Migrate a GDScript multiplayer game template to Swift using SwiftGodot GDExtension bindings, combining best practices from reference projects while maintaining the existing Makefile-based workflow and integrating the Godot editor rebuild plugin.

## Technology Stack

- **Game Engine**: Godot 4.5 (GDExtension system)
- **Language**: Swift 5.9+ via SwiftGodot bindings
- **Build System**: Swift Package Manager + Makefile
- **Networking**: ENet multiplayer (to be implemented in Swift)

## Key Directories

| Directory | Purpose |
|-----------|---------|
| `Swift/` | Main Swift SPM package for the game |
| `Godot/` | Godot project that loads the Swift GDExtension |
| `GDScript/` | Reference: Original multiplayer implementation to migrate |
| `StarterKitSwift/` | Reference: SwiftGodot code patterns and best practices |
| `SwiftGodotTemplate/` | Reference: Original editor plugin template (adapted to `Godot/addons/swift/`) |

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

## SwiftGodot Patterns

### Class Registration

```swift
import SwiftGodot

@Godot
class MyNode: Node3D {
    @Export var speed: Double = 10.0
    @Signal var myEvent: SignalWithArguments<Int>

    override func _ready() { }
    override func _physicsProcess(delta: Double) { }
}
```

### Entry Point (Manual)

```swift
public let godotTypes: [Object.Type] = [MyNode.self]
#initSwiftExtension(cdecl: "swift_entry_point", types: godotTypes)
```

### Entry Point (Auto with Plugin)

```swift
@Godot
class MyNode: Node { }
// Uses EntryPointGeneratorPlugin from SwiftGodot package
```

## GDExtension Configuration

File: `Godot/bin/SwiftLibrary.gdextension`

```ini
[configuration]
entry_symbol = "swift_entry_point"
compatibility_minimum = 4.5

[libraries]
macos.debug = "res://bin/SwiftLibrary.dylib"

[dependencies]
macos.debug = {"res://bin/SwiftGodot.dylib" : ""}
```

## Multiplayer Concepts to Migrate

From `GDScript/scripts/`:

1. **network.gd** - Connection management, peer handling, RPC registration
2. **player.gd** - CharacterBody3D with multiplayer authority, input handling
3. **player_inventory.gd** - Server-authoritative inventory with client sync
4. **level.gd** - Player spawning, game state management
5. **multiplayer_chat_ui.gd** - Real-time chat system

### Key GDScript Patterns

```gdscript
# Multiplayer authority check
if not is_multiplayer_authority(): return

# RPC decorator patterns
@rpc("any_peer", "reliable")
@rpc("any_peer", "call_local", "reliable")

# Sync to specific client
sync_data.rpc_id(target_peer_id, data)
```

## Editor Plugin Integration

The Swift editor plugin (adapted from SwiftGodotTemplate) is located at `Godot/addons/swift/`:

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

## Environment Variables (.env)

```bash
export PROJECT_NAME=SwiftLibrary
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_PROJECT_DIRECTORY=/path/to/Godot
export GODOT_BIN_PATH=$(GODOT_PROJECT_DIRECTORY)/bin
export BUILD_PATH=./.build
export LIBRARY_NAME=$(PROJECT_NAME)
export EXECUTABLE_NAME=MultiplayerSwift
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

### Debugging with Xcode

Use SwiftGodotKit standalone mode:
```bash
make run
```
This allows attaching Xcode debugger to the Swift code.

## Important Notes

- SwiftGodot requires Swift 5.9+ (Xcode 15+)
- GDExtension is still experimental; API may change
- Always check multiplayer authority before processing input
- Use `@rpc` equivalent Swift patterns for network calls
- The `bin/` folder in Godot needs both `SwiftLibrary.dylib` and `SwiftGodot.dylib`

## Reference Links

- [SwiftGodot GitHub](https://github.com/migueldeicaza/SwiftGodot)
- [SwiftGodot Docs](https://migueldeicaza.github.io/SwiftGodotDocs/documentation/swiftgodot/)
- [SwiftGodot Tutorials](https://migueldeicaza.github.io/SwiftGodotDocs/tutorials/swiftgodot-tutorials/)
- [Godot Multiplayer Docs](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
