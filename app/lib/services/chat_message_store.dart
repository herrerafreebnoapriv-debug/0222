/// 聊天消息占位：会话内内存存储，Tinode 接入后可替换为真实消息（规约 ARCHITECTURE 第 9 节）
class ChatMessage {
  ChatMessage({
    required this.content,
    required this.isMe,
    required this.timestamp,
  });

  final String content;
  final bool isMe;
  final DateTime timestamp;
}

/// 按对方昵称分桶的占位消息列表，仅进程内有效
class ChatMessageStore {
  ChatMessageStore._();

  static final Map<String, List<ChatMessage>> _byPeer = {};

  static List<ChatMessage> getMessages(String peerKey) {
    return List.unmodifiable(_byPeer[peerKey] ?? []);
  }

  static void add(String peerKey, String content, bool isMe) {
    _byPeer.putIfAbsent(peerKey, () => []);
    _byPeer[peerKey]!.add(ChatMessage(content: content, isMe: isMe, timestamp: DateTime.now()));
  }
}
