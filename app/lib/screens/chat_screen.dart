import 'package:flutter/material.dart';
import 'package:mop_app/l10n/app_localizations.dart';
import 'package:mop_app/services/chat_message_store.dart';
import 'package:mop_app/services/friend_remark_service.dart';

/// 聊天页：标题为对方昵称，更多菜单含备注/音视频/屏幕共享，消息区与输入框（规约 ARCHITECTURE 第 9 节）
/// 当前为本地占位消息；Tinode 接入后替换为真实消息列表与发送
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  static const String routeName = '/chat';

  /// 传入参数：peerNickname（必显）, peerUid（可选，后续 Tinode 用）
  static Map<String, String>? getArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, String>) return args;
    if (args is Map) {
      return {
        'peerNickname': '${args['peerNickname'] ?? args['peer_nickname'] ?? ''}',
        'peerUid': '${args['peerUid'] ?? args['peer_uid'] ?? ''}',
      };
    }
    return null;
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late String _peerNickname;
  late String _peerUid;
  String? _remark;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _remarkService = FriendRemarkService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ChatScreen.getArgs(context);
    _peerNickname = args?['peerNickname']?.isNotEmpty == true
        ? args!['peerNickname']!
        : AppLocalizations.of(context)!.chat;
    _peerUid = args?['peerUid'] ?? '';
    _loadRemark();
  }

  Future<void> _loadRemark() async {
    final r = await _remarkService.getFriendRemark(_peerUid, _peerNickname);
    if (mounted) setState(() => _remark = r);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<ChatMessage> get _messages =>
      ChatMessageStore.getMessages(_peerNickname);

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    ChatMessageStore.add(_peerNickname, text, true);
    _textController.clear();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 标题：优先备注，无则昵称（规约 ARCHITECTURE 第 9 节）
  String get _displayTitle =>
      (_remark != null && _remark!.isNotEmpty) ? _remark! : _peerNickname;

  Future<void> _showRemarkDialog(AppLocalizations l10n) async {
    final controller = TextEditingController(text: _remark ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.setRemark),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: _peerNickname,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          maxLines: 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _remarkService.setFriendRemark(
        _peerUid,
        _peerNickname,
        controller.text,
      );
      if (mounted) setState(() => _remark = controller.text.trim().isEmpty ? null : controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final list = _messages;

    return Scaffold(
      appBar: AppBar(
        title: Text(_displayTitle),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'remark':
                  _showRemarkDialog(l10n);
                  break;
                case 'voice_video':
                  Navigator.of(context).pushNamed(
                    '/jitsi_join',
                    arguments: {
                      'peerNickname': _peerNickname,
                      'peerUid': ChatScreen.getArgs(context)?['peerUid'] ?? '',
                    },
                  );
                  break;
                case 'screen_share':
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.screenShare)),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'remark', child: Text(l10n.setRemark)),
              PopupMenuItem(value: 'voice_video', child: Text(l10n.voiceVideo)),
              PopupMenuItem(value: 'screen_share', child: Text(l10n.screenShare)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      l10n.chatPlaceholder,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final msg = list[i];
                      return _Bubble(message: msg);
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: l10n.messageHint,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  tooltip: l10n.send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isMe
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.content,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
