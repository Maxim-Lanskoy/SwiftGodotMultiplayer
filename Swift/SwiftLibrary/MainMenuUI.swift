import SwiftGodot

/// Main menu UI for hosting/joining games
@Godot
public class MainMenuUI: Control {
    // MARK: - Node References

    @Node("MainContainer/MainMenu/Option1/NickInput") var nickInput: LineEdit?
    @Node("MainContainer/MainMenu/Option2/SkinInput") var skinInput: LineEdit?
    @Node("MainContainer/MainMenu/Option3/AddressInput") var addressInput: LineEdit?

    // MARK: - Signals

    @Signal var hostPressed: SignalWithArguments<String, String>
    @Signal var joinPressed: SignalWithArguments<String, String, String>
    @Signal var quitPressed: SimpleSignal

    // MARK: - Button Handlers

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

    // MARK: - Public Methods

    public func showMenu() {
        show()
    }

    public func hideMenu() {
        hide()
    }

    public func isMenuVisible() -> Bool {
        return visible
    }

    // MARK: - Accessors

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
