import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import 'login/login_view.dart';
import 'profile_view.dart';

/// 用户 Tab - 未登录显示二维码登录，已登录显示个人资料
class LoginTab extends StatefulWidget {
  final FocusNode? sidebarFocusNode;
  final VoidCallback? onLoginSuccess;

  const LoginTab({super.key, this.sidebarFocusNode, this.onLoginSuccess});

  @override
  State<LoginTab> createState() => LoginTabState();
}

class LoginTabState extends State<LoginTab> {
  void _handleLoginSuccess() {
    setState(() {}); // Refresh to show ProfileView
    widget.onLoginSuccess?.call();
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    // 清除用户内容缓存
    await SettingsService.clearUserContentCache();
    if (mounted) {
      setState(() {}); // Refresh to show LoginView
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.isLoggedIn) {
      return ProfileView(
        sidebarFocusNode: widget.sidebarFocusNode,
        onLogout: _handleLogout,
      );
    }

    return LoginView(
      sidebarFocusNode: widget.sidebarFocusNode,
      onLoginSuccess: _handleLoginSuccess,
    );
  }
}
