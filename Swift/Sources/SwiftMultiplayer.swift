import Foundation
import SwiftGodot
@preconcurrency import SwiftGodotKit
import SwiftDriver
import SwiftUI

func registerTypes(level: GDExtension.InitializationLevel) {
    if level == .scene {
        register(type: Icon2D.self)
    }
}

@main
struct SwiftMultiplayerApp: App {
    init() {
        initHookCb = registerTypes
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var app: GodotApp?
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            Text("SwiftGodot Multiplayer")
                .font(.headline)
                .padding(.top)

            if let errorMessage = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)

                    Text("SwiftGodotKit Error")
                        .font(.title2)

                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()

                    Text("Use the GDExtension workflow instead:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("cd Swift && make all && make open")
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
                .frame(minWidth: 800, minHeight: 600)
            } else if let app = app {
                GodotAppView()
                    .frame(minWidth: 800, minHeight: 600)
                    .environment(\.godotApp, app)
            } else {
                Text("Loading Godot...")
                    .frame(minWidth: 800, minHeight: 600)
            }
        }
        .padding()
        .onAppear {
            setupGodot()
        }
    }

    private func setupGodot() {
        // Try to find the pack file in the bundle
        if let packPath = Bundle.module.path(forResource: "SwiftDriver", ofType: "pck") {
            let packDir = (packPath as NSString).deletingLastPathComponent
            app = GodotApp(packFile: "SwiftDriver.pck", godotPackPath: packDir)

            if app?.start() == true {
                print("GodotApp started with pack: \(packPath)")
            } else {
                errorMessage = """
                Failed to load pack file.

                The pack version may be incompatible with SwiftGodotKit.
                """
            }
        } else {
            errorMessage = """
            Could not find SwiftDriver.pck in bundle.

            Run 'make pack' to create the pack file.
            """
        }
    }
}

#Preview {
    ContentView()
}
