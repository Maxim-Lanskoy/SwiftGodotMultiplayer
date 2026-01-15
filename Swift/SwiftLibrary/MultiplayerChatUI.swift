import SwiftGodot

/// Multiplayer chat UI component
@Godot
public class MultiplayerChatUI: Control {
    // MARK: - Node References

    @Node("Panel/MarginContainer/VBoxContainer/HBoxContainer/Message") var messageInput: LineEdit?
    @Node("Panel/MarginContainer/VBoxContainer/HBoxContainer/Send") var sendButton: Button?
    @Node("Panel/MarginContainer/VBoxContainer/Chat") var chatDisplay: TextEdit?

    // MARK: - Signals

    @Signal var messageSent: SignalWithArguments<String>

    // MARK: - Private State

    private var chatVisible = false

    // MARK: - Lifecycle

    public override func _ready() {
        // Connect signals with weak self to avoid retain cycles
        sendButton?.pressed.connect { [weak self] in
            self?.onSendPressed()
        }
        messageInput?.textSubmitted.connect { [weak self] _ in
            self?.onSendPressed()
        }

        clearChat()
        hide()
    }

    // MARK: - Public Methods

    public func toggleChat() {
        chatVisible = !chatVisible
        if chatVisible {
            show()
            // Grab focus after a frame
            _ = callDeferred(method: "grabMessageFocus")
        } else {
            hide()
            messageInput?.text = ""
            getViewport()?.setInputAsHandled()
        }
    }

    public func isChatVisible() -> Bool {
        return chatVisible
    }

    public func sendMessage() {
        onSendPressed()
    }

    public func addMessage(nick: String, msg: String) {
        let time = Time.getTimeStringFromSystem()
        let formattedMessage = "[\(time)] \(nick): \(msg)\n"
        chatDisplay?.text = (chatDisplay?.text ?? "") + formattedMessage

        if let chat = chatDisplay {
            chat.scrollVertical = Double(chat.getLineCount())
        }
        limitChatHistory()
    }

    public func clearChat() {
        chatDisplay?.text = ""
    }

    // MARK: - Private Methods

    @Callable
    func grabMessageFocus() {
        messageInput?.grabFocus()
    }

    private func onSendPressed() {
        guard let text = messageInput?.text else { return }
        let messageText = text.trimmingCharacters(in: .whitespaces)
        if messageText.isEmpty {
            return
        }

        messageSent.emit(messageText)

        messageInput?.text = ""
        messageInput?.grabFocus()
    }

    private func limitChatHistory() {
        guard let chat = chatDisplay else { return }
        let lines = chat.text.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count > 100 {
            let startIndex = lines.count - 100
            chat.text = lines.suffix(from: startIndex).joined(separator: "\n")
        }
    }
}
