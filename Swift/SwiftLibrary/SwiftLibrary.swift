import SwiftGodot

#warning("Remove this Icon2D class")
@Godot(.tool)
public class Icon2D: Sprite2D {
    public override func _ready() {
        GD.printDebug("Hello world!")
        guard let image = GD.load(path: "res://icon.svg") as? Texture2D else {
            fatalError("Could not load res://icon.svg")
        }
        texture = image
        scale = .init(x: 0.25, y: 0.25)
    }

    public override func _process(delta: Double) {
        rotate(radians: delta)
    }
}

public let godotTypes: [Object.Type] = [
    Icon2D.self
]

#initSwiftExtension(cdecl: "swift_entry_point", types: godotTypes)
