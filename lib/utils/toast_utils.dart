import 'dart:async';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// 轻量级自定义 Toast 工具
///
/// 支持多条消息堆叠：短时间内连续调用 show() 时，新消息追加在下方并列显示，
/// 而非覆盖前一条。定时器在最后一条消息加入后重新计时。
class ToastUtils {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;
  static Timer? _fadeTimer;
  static double _opacity = 1.0;
  static final List<String> _messages = [];

  /// 默认显示时长
  static const Duration defaultDuration = Duration(milliseconds: 1500);

  /// 淡出动画时长
  static const int _fadeSteps = 10;
  static const int _fadeIntervalMs = 20; // 总共 200ms

  /// 显示 Toast
  ///
  /// 若当前已有 Toast 显示，新消息追加在下方并列展示，定时器重新计时。
  static void show(
    BuildContext context,
    String msg, {
    Duration duration = defaultDuration,
  }) {
    _timer?.cancel();
    _timer = null;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _opacity = 1.0;

    if (_currentEntry != null && _messages.isNotEmpty) {
      if (!_messages.contains(msg)) {
        _messages.add(msg);
      }
      _currentEntry?.markNeedsBuild();
    } else {
      _removeEntry();
      _messages.clear();
      _messages.add(msg);

      final overlay = Overlay.of(context);

      _currentEntry = OverlayEntry(
        builder: (context) {
          final screenSize = MediaQuery.of(context).size;
          final screenWidth = screenSize.width;
          final screenHeight = screenSize.height;
          final sidebarWidth = screenWidth * 0.05;
          final topOffset = screenHeight * 2 / 3;

          return Positioned(
            top: topOffset,
            left: sidebarWidth,
            right: 0,
            child: Center(
              child: Opacity(
                opacity: _opacity,
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _messages.asMap().entries.map((entry) {
                      return Padding(
                        padding: EdgeInsets.only(
                          top: entry.key == 0 ? 0 : 8,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: SettingsService.themeColor.withValues(
                              alpha: 0.9,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            entry.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          );
        },
      );

      overlay.insert(_currentEntry!);
    }

    _timer = Timer(duration, _startFadeOut);
  }

  /// 开始淡出动画
  static void _startFadeOut() {
    _timer?.cancel();
    _timer = null;

    int step = 0;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: _fadeIntervalMs), (
      timer,
    ) {
      step++;
      _opacity = 1.0 - (step / _fadeSteps);
      if (_opacity <= 0) {
        timer.cancel();
        _removeEntry();
      } else {
        _currentEntry?.markNeedsBuild();
      }
    });
  }

  /// 移除 entry
  static void _removeEntry() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    try {
      _currentEntry?.remove();
    } catch (_) {}
    _currentEntry = null;
    _opacity = 1.0;
    _messages.clear();
  }

  /// 取消当前 Toast
  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _removeEntry();
  }
}
