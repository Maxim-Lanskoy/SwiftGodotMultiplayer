//
//  Godot.swift
//
//
//  Created by Alex Loren on 5/19/24.
//

import SwiftGodot

#initSwiftExtension(
    cdecl: "swift_entry_point",
    types: [
        AudioPlayer.self,
        Player.self,
        Coin.self,
        Cloud.self,
        FallingPlatform.self,
        GameUI.self,
        CameraView.self
    ]
)
