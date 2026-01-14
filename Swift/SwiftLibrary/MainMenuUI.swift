import SwiftGodot

// Main menu UI for hosting/joining games
@Godot
public class MainMenuUI: Control {
    // Signals
    @Signal var hostPressed: SignalWithArguments<String, String>
    @Signal var joinPressed: SignalWithArguments<String, String, String>
    @Signal var quitPressed: SimpleSignal

    // Node references - set via editor or found at runtime
    private var skinInput: LineEdit?
    private var nickInput: LineEdit?
    private var addressInput: LineEdit?

    public override func _ready() {
        // Find input nodes
        skinInput = getNode(path: "MainContainer/MainMenu/Option2/SkinInput") as? LineEdit
        nickInput = getNode(path: "MainContainer/MainMenu/Option1/NickInput") as? LineEdit
        addressInput = getNode(path: "MainContainer/MainMenu/Option3/AddressInput") as? LineEdit
    }

    @Callable
    public func onHostPressed() {
        let nickname = nickInput?.text.trimmingCharacters(in: .whitespaces) ?? ""
        let skin = skinInput?.text.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        hostPressed.emit(nickname, skin)
    }

    @Callable
    public func onJoinPressed() {
        let nickname = nickInput?.text.trimmingCharacters(in: .whitespaces) ?? ""
        let skin = skinInput?.text.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        let address = addressInput?.text.trimmingCharacters(in: .whitespaces) ?? Network.serverAddress
        joinPressed.emit(nickname, skin, address)
    }

    @Callable
    public func onQuitPressed() {
        quitPressed.emit()
    }

    public func showMenu() {
        show()
    }

    public func hideMenu() {
        hide()
    }

    public func isMenuVisible() -> Bool {
        return visible
    }

    public func getNickname() -> String {
        return nickInput?.text.trimmingCharacters(in: .whitespaces) ?? ""
    }

    public func getSkin() -> String {
        return skinInput?.text.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
    }

    public func getAddress() -> String {
        return addressInput?.text.trimmingCharacters(in: .whitespaces) ?? ""
    }
}
