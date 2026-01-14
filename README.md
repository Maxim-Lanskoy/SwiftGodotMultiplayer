# SwiftGodot Multiplayer

A multiplayer game project using [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot) - Swift language bindings for Godot 4.4+ game engine via GDExtension.

## Project Overview

This project aims to implement a multiplayer game using SwiftGodot, migrating an existing GDScript multiplayer template to Swift while following best practices from community examples.

## Project Structure

```
SwiftGodotMultiplayer/
├── Swift/                    # Swift SPM package for game logic
│   ├── Package.swift         # Swift Package Manager configuration
│   ├── Makefile              # Build automation (build, deploy, run, pack)
│   ├── .env                  # Environment variables for Makefile
│   ├── SwiftLibrary/         # Main GDExtension library
│   │   └── SwiftLibrary.swift
│   └── MultiplayerSwift/     # Standalone executable (SwiftGodotKit)
│       └── main.swift
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
├── StarterKitSwift/          # Reference: SwiftGodot 3D Platformer example
│   └── source/               # Swift source code examples
│       └── Sources/Platformer3D/
│
└── SwiftGodotTemplate/       # Reference: Editor plugin template
    ├── addons/
    │   ├── swift_godot_editor_plugin/  # Editor rebuild button plugin
    │   └── swift_godot_extension/      # GDExtension configuration
    └── swift_godot_game/     # Example SPM project
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

# Deploy to Godot bin folder
make deploy

# Build, deploy, and create resource pack
make all

# Open Godot project
make open

# Run standalone (SwiftGodotKit)
make run
```

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

## SwiftGodot Overview

[SwiftGodot](https://github.com/migueldeicaza/SwiftGodot) provides Swift bindings for Godot 4.4+ using GDExtension:

- **No GC Stutters**: Unlike C#, Swift avoids garbage collection frame drops
- **Two Modes**: GDExtension libraries or embedded Godot via SwiftGodotKit
- **Multi-Platform**: iOS, macOS, Linux, Windows support
- **Swift Integration**: Easy access to Apple/Swift native APIs

### Resources

- [SwiftGodot Documentation](https://migueldeicaza.github.io/SwiftGodotDocs/documentation/swiftgodot/)
- [SwiftGodot Tutorials](https://migueldeicaza.github.io/SwiftGodotDocs/tutorials/swiftgodot-tutorials/)
- [Discord Community](https://discord.gg/bHAsTYaCZM)

## Reference Projects

### GDScript Multiplayer Template

Located in `GDScript/`, this is a complete 3D multiplayer template featuring:

- ENet-based client-server networking
- Player management with skin selection
- Real-time movement/animation sync
- Multiplayer chat system
- Server-authoritative inventory system

### StarterKitSwift (3D Platformer)

Located in `StarterKitSwift/`, demonstrates SwiftGodot best practices:

- `@Godot` macro for class registration
- `@Export` for editor-exposed properties
- `@Signal` for custom signals
- Proper Swift patterns with Godot node hierarchy

### SwiftGodotTemplate (Editor Plugin)

Located in `SwiftGodotTemplate/`, provides:

- Godot editor tab with "Rebuild" button
- One-click Swift build and editor reload
- Clean build option
- Integrated build logging

## Development Workflow

### Using Makefile (Terminal)

```bash
cd Swift
make all    # Build, deploy, pack
```

### Using Editor Plugin (Recommended)

1. Open `Godot/project.godot` in Godot
2. Click the **Swift** tab at the top of the editor
3. Click **Rebuild** to compile and deploy
4. Editor automatically restarts with updated libraries

The plugin uses the same build directory (`Swift/.build`) as the Makefile.

## License

MIT License - See [LICENSE](LICENSE) for details.

## Credits

- [SwiftGodot](https://github.com/migueldeicaza/SwiftGodot) by Miguel de Icaza
- [3D Multiplayer Template](https://godotengine.org/asset-library/asset/3377) by devmoreir4
- [3D Platformer Starter Kit](https://github.com/lorenalexm/Starter-Kit-3D-Platformer-Swift) by Alex Loren
- [SwiftGodotTemplate](https://github.com/elijah-semyonov/SwiftGodotTemplate) by Elijah Semyonov
