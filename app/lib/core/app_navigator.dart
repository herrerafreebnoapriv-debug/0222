import 'package:flutter/material.dart';

/// 全局 NavigatorKey，供 wipe 等场景跳转登录并清空栈（规约 PROTOCOL 4.2）
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// wipe 执行后调用：清空栈并进入登录页
void navigateToLoginAndClearStack() {
  appNavigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
}
