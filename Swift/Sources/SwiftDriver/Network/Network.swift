//
//  Network.swift
//  SwiftGodotMultiplayer
//
// ENet multiplayer manager - handles host/join, player tracking, connection
// timeout (10s), and network signals. Configure as Godot Autoload.

import SwiftGodot

// MARK: - Player Skin Color

/// Player skin color options (none/blue/yellow/green/red).
/// Use `.none` (-1) to keep the original multicolor texture.
public enum SkinColor: Int, CaseIterable {
    case none = -1
    case blue = 0
    case yellow = 1
    case green = 2
    case red = 3

    /// Creates a SkinColor from a string name.
    /// - Parameter s: Color name (case-insensitive).
    /// - Returns: Matching color, or `.none` for empty/unrecognized (keeps original texture).
    public static func fromString(_ s: String) -> SkinColor {
        let trimmed = s.trimmingCharacters(in: .whitespaces).lowercased()
        switch trimmed {
        case "blue": return .blue
        case "yellow": return .yellow
        case "green": return .green
        case "red": return .red
        default: return .none  // Empty or unrecognized = keep original multicolor
        }
    }
}

// MARK: - Player Info

/// Player information structure for network transmission.
///
/// Contains the player's display name and skin color choice.
/// Can be serialized to/from Godot's VariantDictionary for RPC.
public struct PlayerInfo {
    public var nick: String
    public var skin: SkinColor

    public init(nick: String = "Player", skin: SkinColor = .blue) {
        self.nick = nick
        self.skin = skin
    }

    /// Converts to VariantDictionary for network transmission.
    public func toDict() -> VariantDictionary {
        let dict = VariantDictionary()
        dict["nick"] = Variant(nick)
        dict["skin"] = Variant(skin.rawValue)
        return dict
    }

    /// Creates PlayerInfo from a VariantDictionary.
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

// MARK: - Network Manager

/// Network manager singleton handling multiplayer connections.
///
/// This class manages:
/// - Server hosting and client connections via ENet
/// - Player registration and tracking
/// - Connection lifecycle events
///
/// ## Usage
/// Configure as Godot Autoload in Project Settings.
///
/// ```swift
/// // Host a game
/// Network.shared?.startHost(nickname: "Host", skinColorStr: "blue")
///
/// // Join a game
/// Network.shared?.joinGame(nickname: "Player", skinColorStr: "red", address: "127.0.0.1")
/// ```
///
/// ## Signals
/// - `playerConnected`: Emitted when a player joins (peerId, playerInfo)
/// - `serverDisconnected`: Emitted when disconnected from server
@Godot
public class Network: Node {
    // MARK: - Singleton

    /// Shared instance. Set when added as Godot Autoload.
    /// Use optional chaining for safe access: `Network.shared?.startHost(...)`.
    nonisolated(unsafe) public static var shared: Network?

    // MARK: - Configuration

    /// Default server address for local testing.
    public static let serverAddress = "127.0.0.1"
    /// Server port number.
    public static let serverPort: Int32 = 8080
    /// Maximum number of connected players.
    public static let maxPlayers: Int32 = 10
    /// Connection timeout in seconds.
    public static let connectionTimeout: Double = 10.0
    /// Maximum nickname length.
    public static let maxNicknameLength: Int = 32

    // MARK: - Nickname Validation

    /// Validates and sanitizes a nickname.
    ///
    /// Removes special characters (allowing only letters, numbers, underscores, and hyphens),
    /// trims whitespace, and enforces maximum length.
    ///
    /// - Parameter nickname: The raw nickname input.
    /// - Returns: A sanitized nickname, or a default if the result is empty.
    public static func validateNickname(_ nickname: String) -> String {
        // Trim whitespace
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)

        // Filter to allowed characters: letters, numbers, underscore, hyphen
        let sanitized = trimmed.filter { char in
            char.isLetter || char.isNumber || char == "_" || char == "-"
        }

        // Enforce maximum length
        let limited = String(sanitized.prefix(maxNicknameLength))

        // Return default if empty
        return limited.isEmpty ? "Player" : limited
    }

    // MARK: - Private State

    /// Connected players dictionary [peer_id: PlayerInfo].
    private var players: [Int: PlayerInfo] = [:]

    /// Local player info.
    private var playerInfo = PlayerInfo(nick: "host", skin: .blue)

    /// Timer for connection timeout.
    private var connectionTimer: Timer?

    /// Whether we're currently attempting to connect.
    private var isConnecting = false

    /// Signal connection tokens for proper cleanup.
    private var signalTokens: [Callable] = []

    /// Timer signal token.
    private var timerSignalToken: Callable?

    // MARK: - Signals

    /// Emitted when a player connects. Parameters: (peerId: Int, playerInfo: VariantDictionary).
    @Signal var playerConnected: SignalWithArguments<Int, VariantDictionary>
    /// Emitted when disconnected from server.
    @Signal var serverDisconnected: SimpleSignal
    /// Emitted when connection attempt fails (including timeout).
    @Signal var connectionAttemptFailed: SimpleSignal

    // MARK: - Lifecycle

    public override func _ready() {
        Network.shared = self

        guard let mp = multiplayer else {
            GD.pushError("Network: multiplayer is nil")
            return
        }

        // Connect multiplayer signals and store tokens for cleanup
        signalTokens.append(mp.serverDisconnected.connect(onServerDisconnected))
        signalTokens.append(mp.connectionFailed.connect(onConnectionFailed))
        signalTokens.append(mp.peerDisconnected.connect(onPlayerDisconnected))
        signalTokens.append(mp.peerConnected.connect(onPeerConnected))
        signalTokens.append(mp.connectedToServer.connect(onConnectedToServer))

        GD.print("Network: Ready, multiplayer signals connected")
    }

    public override func _exitTree() {
        // Disconnect all signal connections
        if let mp = multiplayer {
            for token in signalTokens {
                mp.serverDisconnected.disconnect(token)
                mp.connectionFailed.disconnect(token)
                mp.peerDisconnected.disconnect(token)
                mp.peerConnected.disconnect(token)
                mp.connectedToServer.disconnect(token)
            }
        }
        signalTokens.removeAll()

        // Clean up timer
        if let timer = connectionTimer, let token = timerSignalToken {
            timer.timeout.disconnect(token)
        }
        connectionTimer?.queueFree()
        connectionTimer = nil
        timerSignalToken = nil

        if Network.shared === self {
            Network.shared = nil
        }
    }

    public override func _process(delta: Double) {
        if Input.isActionJustPressed(action: "quit") {
            getTree()?.quit(exitCode: 0)
        }
    }

    // MARK: - Host/Join Methods

    /// Starts hosting a game server.
    /// - Parameters:
    ///   - nickname: Host player's display name.
    ///   - skinColorStr: Host player's skin color name.
    /// - Returns: Error code (.ok on success).
    public func startHost(nickname: String, skinColorStr: String) -> GodotError {
        GD.print("Network: startHost() called with nickname='\(nickname)', skin='\(skinColorStr)'")
        let peer = ENetMultiplayerPeer()
        let error = peer.createServer(port: Network.serverPort, maxClients: Network.maxPlayers)
        if error != .ok {
            GD.pushError("Network: Failed to create server: \(error)")
            return error
        }

        multiplayer?.multiplayerPeer = peer

        // Validate nickname (sanitizes special characters and enforces length)
        var nick = Network.validateNickname(nickname)
        if nick == "Player" && !nickname.trimmingCharacters(in: .whitespaces).isEmpty {
            // If sanitization resulted in default, log a warning
            GD.pushWarning("Network: Nickname contained invalid characters, using: \(nick)")
        }
        // Add unique ID suffix if generic
        if nick == "Player" {
            nick = "Host_\(multiplayer?.getUniqueId() ?? 1)"
        }

        playerInfo.nick = nick
        playerInfo.skin = SkinColor.fromString(skinColorStr)

        // Skip player creation for headless server
        if DisplayServer.getName() == "headless" {
            GD.print("Network: Headless server started on port \(Network.serverPort)")
            return .ok
        }

        // Register host player (peer ID 1)
        players[1] = playerInfo
        playerConnected.emit(1, playerInfo.toDict())
        GD.print("Network: Server started on port \(Network.serverPort), host player registered")
        return .ok
    }

    /// Joins an existing game server.
    /// - Parameters:
    ///   - nickname: Player's display name.
    ///   - skinColorStr: Player's skin color name.
    ///   - address: Server IP address (defaults to localhost if empty).
    /// - Returns: Error code (.ok on success).
    public func joinGame(nickname: String, skinColorStr: String, address: String = serverAddress) -> GodotError {
        GD.print("Network: joinGame() called with nickname='\(nickname)', skin='\(skinColorStr)', address='\(address)'")
        // Use default address if empty
        let serverAddr = address.trimmingCharacters(in: .whitespaces).isEmpty ? Network.serverAddress : address

        let peer = ENetMultiplayerPeer()
        let error = peer.createClient(address: serverAddr, port: Network.serverPort)
        if error != .ok {
            GD.pushError("Network: Failed to connect to \(serverAddr):\(Network.serverPort): \(error)")
            return error
        }

        multiplayer?.multiplayerPeer = peer

        // Validate nickname (sanitizes special characters and enforces length)
        var nick = Network.validateNickname(nickname)
        if nick == "Player" && !nickname.trimmingCharacters(in: .whitespaces).isEmpty {
            // If sanitization resulted in default, log a warning
            GD.pushWarning("Network: Nickname contained invalid characters, using: \(nick)")
        }
        // Add unique ID suffix if generic
        if nick == "Player" {
            nick = "Player_\(multiplayer?.getUniqueId() ?? 0)"
        }

        playerInfo.nick = nick
        playerInfo.skin = SkinColor.fromString(skinColorStr)

        // Start connection timeout timer
        isConnecting = true
        startConnectionTimeout()

        GD.print("Network: Connecting to \(serverAddr):\(Network.serverPort) (timeout: \(Network.connectionTimeout)s)")
        return .ok
    }

    /// Starts the connection timeout timer.
    private func startConnectionTimeout() {
        // Cancel any existing timer and disconnect its signal
        if let timer = connectionTimer, let token = timerSignalToken {
            timer.timeout.disconnect(token)
        }
        connectionTimer?.stop()
        connectionTimer?.queueFree()
        connectionTimer = nil
        timerSignalToken = nil

        // Create a Godot Timer node for the timeout
        let timer = Timer()
        timer.waitTime = Network.connectionTimeout
        timer.oneShot = true
        timerSignalToken = timer.timeout.connect { [weak self] in
            self?.onConnectionTimeout()
        }
        addChild(node: timer)
        timer.start()
        connectionTimer = timer
    }

    /// Called when connection timeout expires.
    private func onConnectionTimeout() {
        guard isConnecting else { return }

        GD.pushWarning("Network: Connection timeout after \(Network.connectionTimeout) seconds")
        isConnecting = false

        // Clean up
        multiplayer?.multiplayerPeer = nil
        connectionTimer?.queueFree()
        connectionTimer = nil

        // Emit failure signal
        connectionAttemptFailed.emit()
    }

    /// Cancels the connection timeout timer.
    private func cancelConnectionTimeout() {
        isConnecting = false
        if let timer = connectionTimer, let token = timerSignalToken {
            timer.timeout.disconnect(token)
        }
        connectionTimer?.stop()
        connectionTimer?.queueFree()
        connectionTimer = nil
        timerSignalToken = nil
    }

    // MARK: - Connection Handlers

    /// Called on CLIENT when successfully connected to server.
    func onConnectedToServer() {
        // Cancel connection timeout
        cancelConnectionTimeout()

        let peerId = Int(multiplayer?.getUniqueId() ?? 0)
        GD.print("Network: [CLIENT] Connected to server as peer \(peerId)")
        GD.print("Network: [CLIENT] isServer: \(multiplayer?.isServer() ?? false)")
        GD.print("Network: [CLIENT] multiplayerPeer status: \(multiplayer?.multiplayerPeer?.getConnectionStatus().rawValue ?? -1)")

        // Store our own player info
        players[peerId] = playerInfo

        // Emit signal so Level can process (but Level won't spawn since not server)
        playerConnected.emit(peerId, playerInfo.toDict())
        GD.print("Network: [CLIENT] playerConnected signal emitted for peer \(peerId)")
    }

    /// Called on BOTH server and client when a new peer connects.
    func onPeerConnected(id: Int64) {
        let peerId = Int(id)
        let isServer = multiplayer?.isServer() ?? false
        GD.print("Network: [PEER_CONNECTED] Peer \(peerId) connected, isServer: \(isServer)")

        // On server: register the new player with default info
        // The actual player info will be synced via MultiplayerSynchronizer
        if isServer {
            // Create default info for the new player
            let newPlayerInfo = PlayerInfo(nick: "Player_\(peerId)", skin: .blue)
            players[peerId] = newPlayerInfo
            GD.print("Network: [SERVER] About to emit playerConnected for peer \(peerId)")
            playerConnected.emit(peerId, newPlayerInfo.toDict())
            GD.print("Network: [SERVER] playerConnected signal emitted, players dict: \(players)")
        } else {
            GD.print("Network: [CLIENT] Received peer_connected for peer \(peerId)")
        }
    }

    func onPlayerDisconnected(id: Int64) {
        players.removeValue(forKey: Int(id))
        GD.print("Network: Player \(id) disconnected")
    }

    func onConnectionFailed() {
        // Cancel connection timeout
        cancelConnectionTimeout()

        multiplayer?.multiplayerPeer = nil
        GD.pushWarning("Network: Connection failed")

        // Emit our signal so UI can respond
        connectionAttemptFailed.emit()
    }

    func onServerDisconnected() {
        multiplayer?.multiplayerPeer = nil
        players.removeAll()
        serverDisconnected.emit()
        GD.print("Network: Disconnected from server")
    }

    // MARK: - Public Accessors

    /// Returns all connected players.
    public func getPlayers() -> [Int: PlayerInfo] {
        return players
    }

    /// Returns info for a specific player.
    /// - Parameter peerId: The player's peer ID.
    public func getPlayerInfo(_ peerId: Int) -> PlayerInfo? {
        return players[peerId]
    }

    /// Returns the local player's info.
    public func getLocalPlayerInfo() -> PlayerInfo {
        return playerInfo
    }

    /// Updates a player's info (called when receiving sync).
    public func updatePlayerInfo(_ peerId: Int, nick: String, skin: SkinColor) {
        if var info = players[peerId] {
            info.nick = nick
            info.skin = skin
            players[peerId] = info
        } else {
            players[peerId] = PlayerInfo(nick: nick, skin: skin)
        }
    }
}
