import SwiftGodot

// Player skin color options
public enum SkinColor: Int, CaseIterable {
    case blue = 0
    case yellow = 1
    case green = 2
    case red = 3

    public static func fromString(_ s: String) -> SkinColor {
        switch s.lowercased() {
        case "blue": return .blue
        case "yellow": return .yellow
        case "green": return .green
        case "red": return .red
        default: return .blue
        }
    }
}

// Player info structure for network transmission
public struct PlayerInfo {
    public var nick: String
    public var skin: SkinColor

    public init(nick: String = "Player", skin: SkinColor = .blue) {
        self.nick = nick
        self.skin = skin
    }

    public func toDict() -> VariantDictionary {
        let dict = VariantDictionary()
        dict["nick"] = Variant(nick)
        dict["skin"] = Variant(skin.rawValue)
        return dict
    }

    public static func fromDict(_ dict: VariantDictionary) -> PlayerInfo {
        var info = PlayerInfo()
        if let nickVar = dict["nick"], let nickStr = String(nickVar) {
            info.nick = nickStr
        }
        if let skinVar = dict["skin"], let skinInt = Int(skinVar) {
            info.skin = SkinColor(rawValue: skinInt) ?? .blue
        }
        return info
    }
}

// Network manager singleton - handles multiplayer connections
// This is registered as an autoload in Godot
@Godot
public class Network: Node {
    // Singleton accessor
    nonisolated(unsafe) public static var shared: Network!

    // Server configuration
    public static let serverAddress = "127.0.0.1"
    public static let serverPort: Int32 = 8080
    public static let maxPlayers: Int32 = 10

    // Connected players dictionary [peer_id: PlayerInfo]
    private var players: [Int: PlayerInfo] = [:]
    private var playerInfo = PlayerInfo(nick: "host", skin: .blue)

    // Signals
    @Signal var playerConnected: SignalWithArguments<Int, VariantDictionary>
    @Signal var serverDisconnected: SimpleSignal

    public override func _ready() {
        Network.shared = self

        // Connect multiplayer signals
        guard let mp = multiplayer else {
            GD.pushError("Network: multiplayer is nil")
            return
        }

        mp.serverDisconnected.connect(onConnectionFailed)
        mp.connectionFailed.connect(onServerDisconnected)
        mp.peerDisconnected.connect(onPlayerDisconnected)
        mp.peerConnected.connect(onPlayerConnected)
        mp.connectedToServer.connect(onConnectedOk)
    }

    public override func _process(delta: Double) {
        if Input.isActionJustPressed(action: "quit") {
            getTree()?.quit(exitCode: 0)
        }
    }

    public func startHost(nickname: String, skinColorStr: String) -> GodotError {
        let peer = ENetMultiplayerPeer()
        let error = peer.createServer(port: Network.serverPort, maxClients: Network.maxPlayers)
        if error != .ok {
            return error
        }

        multiplayer?.multiplayerPeer = peer

        var nick = nickname
        if nick.trimmingCharacters(in: .whitespaces).isEmpty {
            nick = "Host_\(multiplayer?.getUniqueId() ?? 1)"
        }

        playerInfo.nick = nick
        playerInfo.skin = SkinColor.fromString(skinColorStr)

        // Skip player creation for headless server
        if DisplayServer.getName() == "headless" {
            return .ok
        }

        players[1] = playerInfo
        playerConnected.emit(1, playerInfo.toDict())
        return .ok
    }

    public func joinGame(nickname: String, skinColorStr: String, address: String = serverAddress) -> GodotError {
        let peer = ENetMultiplayerPeer()
        let error = peer.createClient(address: address, port: Network.serverPort)
        if error != .ok {
            return error
        }

        multiplayer?.multiplayerPeer = peer

        var nick = nickname
        if nick.trimmingCharacters(in: .whitespaces).isEmpty {
            nick = "Player_\(multiplayer?.getUniqueId() ?? 0)"
        }

        playerInfo.nick = nick
        playerInfo.skin = SkinColor.fromString(skinColorStr)
        return .ok
    }

    func onConnectedOk() {
        let peerId = Int(multiplayer?.getUniqueId() ?? 0)
        players[peerId] = playerInfo
        playerConnected.emit(peerId, playerInfo.toDict())
    }

    func onPlayerConnected(id: Int64) {
        // Skip for headless server
        if DisplayServer.getName() == "headless" {
            return
        }
        // Send our info to the new player
        registerPlayer(newPlayerInfo: playerInfo.toDict(), peerId: id)
    }

    // RPC function to register a new player
    @Callable
    func registerPlayer(newPlayerInfo: VariantDictionary, peerId: Int64 = 0) {
        let senderId = peerId > 0 ? Int(peerId) : Int(multiplayer?.getRemoteSenderId() ?? 0)
        let info = PlayerInfo.fromDict(newPlayerInfo)
        players[senderId] = info
        playerConnected.emit(senderId, newPlayerInfo)
    }

    func onPlayerDisconnected(id: Int64) {
        players.removeValue(forKey: Int(id))
    }

    func onConnectionFailed() {
        multiplayer?.multiplayerPeer = nil
    }

    func onServerDisconnected() {
        multiplayer?.multiplayerPeer = nil
        players.removeAll()
        serverDisconnected.emit()
    }

    // Public accessors
    public func getPlayers() -> [Int: PlayerInfo] {
        return players
    }

    public func getPlayerInfo(_ peerId: Int) -> PlayerInfo? {
        return players[peerId]
    }

    public func getLocalPlayerInfo() -> PlayerInfo {
        return playerInfo
    }
}
