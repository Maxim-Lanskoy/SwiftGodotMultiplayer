import SwiftGodot
import Foundation

// Animation controller for the 3D robot character model
@Godot
public class Body: Node3D {
    private let lerpVelocity: Float = 0.15

    // Node reference - child AnimationPlayer
    @Node("AnimationPlayer") var animationPlayer: AnimationPlayer?

    public func applyRotation(_ velocity: Vector3) {
        let targetAngle = Foundation.atan2(Double(-velocity.x), Double(-velocity.z))
        let newRotationY = GD.lerpAngle(from: Double(rotation.y), to: targetAngle, weight: Double(lerpVelocity))
        rotation.y = Float(newRotationY)
    }

    /// Animate based on character state - all state passed as parameters
    public func animate(_ velocity: Vector3, isOnFloor: Bool, isRunning: Bool) {
        guard let animationPlayer = animationPlayer else { return }

        // Check if airborne
        if !isOnFloor {
            if velocity.y < 0 {
                animationPlayer.play(name: "Fall")
            } else {
                let currentAnim = animationPlayer.currentAnimation
                if currentAnim != "Jump" && currentAnim != "Jump2" {
                    animationPlayer.play(name: "Jump")
                }
            }
            return
        }

        // Check if moving
        if velocity.x != 0 || velocity.z != 0 {
            if isRunning {
                animationPlayer.play(name: "Sprint")
                return
            }
            animationPlayer.play(name: "Run")
            return
        }

        // Idle
        animationPlayer.play(name: "Idle")
    }

    public func playJumpAnimation(jumpType: String = "Jump") {
        animationPlayer?.play(name: StringName(jumpType))
    }
}
