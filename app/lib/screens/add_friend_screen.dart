import 'package:flutter/material.dart';
import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/l10n/app_localizations.dart';

/// 查找添加好友：精确搜索用户名或手机号，结果仅展示昵称/头像/简介，不含手机号（规约 PROTOCOL 2.4）
class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final _queryController = TextEditingController();
  final _api = ApiClient();
  List<SearchUserItem> _results = [];
  bool _loading = false;
  String? _errorText;
  bool _searched = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _onSearch() async {
    final q = _queryController.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _errorText = null;
      _searched = true;
    });
    try {
      final list = await _api.userSearch(q);
      if (mounted) {
        setState(() {
          _results = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _results = [];
          _errorText = e.toString();
        });
      }
    }
  }

  Future<void> _onAddFriend(SearchUserItem user) async {
    final ok = await _api.requestAddFriend(user.uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? AppLocalizations.of(context)!.addFriendSent
              : AppLocalizations.of(context)!.addFriendFail,
        ),
      ),
    );
  }

  /// 规约：未设置头像时以昵称首字作为默认头像
  static Widget avatarFor(SearchUserItem user, double size) {
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(user.avatarUrl!),
        onBackgroundImageError: (_, __) {},
      );
    }
    final first = user.nickname.isNotEmpty
        ? user.nickname.runes.first
        : '?'.runes.first;
    final char = String.fromCharCode(first);
    return CircleAvatar(
      radius: size / 2,
      child: Text(char, style: TextStyle(fontSize: size * 0.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addFriendTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: InputDecoration(
                      hintText: l10n.searchUserHint,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _onSearch,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.searchHint),
                ),
              ],
            ),
          ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: _searched
                ? _results.isEmpty
                    ? Center(child: Text(l10n.noSearchResult))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final user = _results[i];
                          return ListTile(
                            leading: avatarFor(user, 40),
                            title: Text(user.nickname),
                            subtitle: user.bio != null && user.bio!.isNotEmpty
                                ? Text(
                                    user.bio!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            trailing: FilledButton.tonal(
                              onPressed: () => _onAddFriend(user),
                              child: Text(l10n.addFriend),
                            ),
                          );
                        },
                      )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
