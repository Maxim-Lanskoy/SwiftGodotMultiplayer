//
//  Body.swift
//  SwiftGodotMultiplayer
//
// Animation controller for player model - handles idle, run, sprint, jump,
// fall animations and smooth rotation based on movement direction.

import SwiftGodot
import Foundation

/// Animation controller for player character model.
///
/// Handles state-based animation playback (idle, run, sprint, jump, fall)
/// and smooth rotation towards movement direction.
@Godot
public class Body: Node3D {
    // MARK: - Constants

    /// Interpolation speed for rotation smoothing.
    private let lerpVelocity: Float = 0.15

    // MARK: - Node References

    @Node("AnimationPlayer") var animationPlayer: AnimationPlayer?

    // MARK: - Public Methods

    /// Rotates the body to face the movement direction.
    /// - Parameter velocity: Current movement velocity vector.
    public func applyRotation(_ velocity: Vector3) {
        let targetAngle = Foundation.atan2(Double(-velocity.x), Double(-velocity.z))
        let newRotationY = GD.lerpAngle(from: Double(rotation.y), to: targetAngle, weight: Double(lerpVelocity))
        rotation.y = Float(newRotationY)
    }

    /// Animates the character based on current state.
    /// - Parameters:
    ///   - velocity: Current movement velocity vector.
    ///   - isOnFloor: Whether the character is grounded.
    ///   - isRunning: Whether the character is sprinting.
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

    /// Plays a jump animation.
    /// - Parameter jumpType: Animation name ("Jump" or "Jump2" for double jump).
    public func playJumpAnimation(jumpType: String = "Jump") {
        animationPlayer?.play(name: StringName(jumpType))
    }
}
