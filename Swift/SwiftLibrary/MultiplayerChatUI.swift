import SwiftGodot

// Multiplayer chat UI component
@Godot
public class MultiplayerChatUI: Control {
    // Node references
    private var messageInput: LineEdit?
    private var sendButton: Button?
    private var chatDisplay: TextEdit?

    // Signals
    @Signal var messageSent: SignalWithArguments<String>

    // State
    private var chatVisible = false

    public override func _ready() {
        // Find child nodes
        messageInput = getNode(path: "Panel/MarginContainer/VBoxContainer/HBoxContainer/Message") as? LineEdit
        sendButton = getNode(path: "Panel/MarginContainer/VBoxContainer/HBoxContainer/Send") as? Button
        chatDisplay = getNode(path: "Panel/MarginContainer/VBoxContainer/Chat") as? TextEdit

        // Connect signals
        sendButton?.pressed.connect(onSendPressed)
        messageInput?.textSubmitted.connect { [weak self] _ in
            self?.onSendPressed()
        }

        clearChat()
        hide()
    }

    public func toggleChat() {
        chatVisible = !chatVisible
        if chatVisible {
            show()
            // Grab focus after a frame
            callDeferred(method: "grabMessageFocus")
        } else {
            hide()
            messageInput?.text = ""
            getViewport()?.setInputAsHandled()
        }
    }

    @Callable
    func grabMessageFocus() {
        messageInput?.grabFocus()
    }

    public func isChatVisible() -> Bool {
        return chatVisible
    }

    func onSendPressed() {
        guard let text = messageInput?.text else { return }
        let messageText = text.trimmingCharacters(in: .whitespaces)
        if messageText.isEmpty {
            return
        }

        messageSent.emit(messageText)

        messageInput?.text = ""
        messageInput?.grabFocus()
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

    private func limitChatHistory() {
        guard let chat = chatDisplay else { return }
        let lines = chat.text.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count > 100 {
            let startIndex = lines.count - 100
            chat.text = lines.suffix(from: startIndex).joined(separator: "\n")
        }
    }

    public func clearChat() {
        chatDisplay?.text = ""
    }
}
