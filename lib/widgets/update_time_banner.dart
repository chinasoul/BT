import 'dart:async';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// 顶部更新时间横幅组件
///
/// 在页面顶部显示"更新于x分钟前"的横幅
/// 延迟出现，显示一段时间后自动淡出
class UpdateTimeBanner extends StatefulWidget {
  /// 要显示的时间文本，如 "更新于5分钟前"
  final String timeText;

  /// 出现前的延迟时间
  final Duration showDelay;

  /// 显示时长（淡出前）
  final Duration displayDuration;

  /// Banner 高度
  final double height;

  const UpdateTimeBanner({
    super.key,
    required this.timeText,
    this.showDelay = const Duration(milliseconds: 500),
    this.displayDuration = const Duration(seconds: 2),
    this.height = 32,
  });

  @override
  State<UpdateTimeBanner> createState() => _UpdateTimeBannerState();
}

class _UpdateTimeBannerState extends State<UpdateTimeBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  Timer? _showTimer;
  Timer? _hideTimer;
  bool _visible = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _dismissed = true);
      }
    });

    // 延迟后显示
    _showTimer = Timer(widget.showDelay, () {
      if (mounted) {
        setState(() => _visible = true);
        // 显示后再延迟淡出
        _hideTimer = Timer(widget.displayDuration, () {
          if (mounted) {
            _controller.forward();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.timeText.isEmpty || _dismissed || !_visible) {
      return const SizedBox.shrink();
    }

    final themeColor = SettingsService.themeColor;

    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, _) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Center(
            child: Container(
              height: widget.height,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    widget.timeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
