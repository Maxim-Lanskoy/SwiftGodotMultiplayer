//
//  SpringArmCharacter.swift
//  SwiftGodotMultiplayer
//
// Third-person camera controller with mouse look and spring arm collision.

import SwiftGodot
@Godot
public class SpringArmCharacter: Node3D {
    private let mouseSensitivity: Float = 0.005

    // Node reference - using @Node macro for scene tree binding
    @Node("SpringArm3D") var springArm: SpringArm3D?

    public override func _unhandledInput(event: InputEvent?) {
        guard let event = event as? InputEventMouseMotion,
              isMultiplayerAuthority() else {
            return
        }

        // Rotate horizontally (around Y axis)
        rotateY(angle: Double(-event.relative.x * mouseSensitivity))

        // Rotate spring arm vertically (around X axis)
        if let springArm = springArm {
            springArm.rotateX(angle: Double(-event.relative.y * mouseSensitivity))
            // Clamp vertical rotation between -45 degrees and ~7.5 degrees
            springArm.rotation.x = springArm.rotation.x.clamped(to: Float(-Double.pi / 4)...Float(Double.pi / 24))
        }
    }
}

// Extension to add clamped function for Float
extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
