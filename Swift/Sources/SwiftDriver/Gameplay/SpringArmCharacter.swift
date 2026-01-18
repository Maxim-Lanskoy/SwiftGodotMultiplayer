//
//  SpringArmCharacter.swift
//  SwiftGodotMultiplayer
//
// Third-person camera controller with mouse look and spring arm collision.

import SwiftGodot

/// Third-person camera controller with spring arm collision.
///
/// Handles mouse-look camera rotation with vertical clamping.
/// Only processes input when the node has multiplayer authority.
@Godot
public class SpringArmCharacter: Node3D {
    // MARK: - Constants

    /// Mouse sensitivity for camera rotation.
    private let mouseSensitivity: Float = 0.005

    // MARK: - Node References

    @Node("SpringArm3D") var springArm: SpringArm3D?

    // MARK: - Input Handling

    /// Handles unhandled mouse motion input for camera rotation.
    /// - Parameter event: The input event to process.
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

// MARK: - Float Extension

extension Float {
    /// Clamps the value to the specified range.
    /// - Parameter range: The closed range to clamp to.
    /// - Returns: The clamped value.
    func clamped(to range: ClosedRange<Float>) -> Float {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
