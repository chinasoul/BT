import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

/// 播放器内部焦点导航工具
///
/// 提供播放器面板内的焦点导航逻辑，可被 player_event_mixin 使用
class PlayerFocusHandler {
  /// 处理控制栏按钮导航（水平模式）
  ///
  /// [event] - 键盘事件
  /// [currentIndex] - 当前聚焦按钮索引
  /// [maxIndex] - 最大按钮索引
  /// [onIndexChange] - 索引变化回调
  /// [onSelect] - 确认键回调
  /// [onProgressBar] - 进入进度条模式回调（上键触发）
  /// [onHide] - 隐藏控制栏回调（下键触发）
  ///
  /// 返回事件处理结果和新的索引
  static ({KeyEventResult result, int newIndex}) handleControlsNavigation(
    KeyEvent event, {
    required int currentIndex,
    required int maxIndex,
    required Function(int) onSelect,
    VoidCallback? onProgressBar,
    VoidCallback? onHide,
  }) {
    if (event is! KeyDownEvent) {
      return (result: KeyEventResult.ignored, newIndex: currentIndex);
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        final newIndex = (currentIndex - 1).clamp(0, maxIndex);
        return (result: KeyEventResult.handled, newIndex: newIndex);

      case LogicalKeyboardKey.arrowRight:
        final newIndex = (currentIndex + 1).clamp(0, maxIndex);
        return (result: KeyEventResult.handled, newIndex: newIndex);

      case LogicalKeyboardKey.arrowUp:
        onProgressBar?.call();
        return (result: KeyEventResult.handled, newIndex: currentIndex);

      case LogicalKeyboardKey.arrowDown:
        onHide?.call();
        return (result: KeyEventResult.handled, newIndex: currentIndex);

      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.select:
        onSelect(currentIndex);
        return (result: KeyEventResult.handled, newIndex: currentIndex);

      default:
        return (result: KeyEventResult.ignored, newIndex: currentIndex);
    }
  }

  /// 处理设置面板导航（垂直模式，带子菜单）
  ///
  /// [event] - 键盘事件
  /// [currentIndex] - 当前聚焦项索引
  /// [maxIndex] - 最大项索引
  /// [isSubMenu] - 是否在子菜单中
  /// [onActivate] - 激活当前项回调
  /// [onBack] - 返回上级菜单回调
  /// [onAdjust] - 调整值回调（用于弹幕设置等，传入 -1 或 1）
  ///
  /// 返回事件处理结果和新的索引
  static ({KeyEventResult result, int newIndex}) handleSettingsPanelNavigation(
    KeyEvent event, {
    required int currentIndex,
    required int maxIndex,
    required bool isSubMenu,
    VoidCallback? onActivate,
    VoidCallback? onBack,
    Function(int)? onAdjust,
  }) {
    if (event is! KeyDownEvent) {
      return (result: KeyEventResult.ignored, newIndex: currentIndex);
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        final newIndex = (currentIndex - 1).clamp(0, maxIndex);
        return (result: KeyEventResult.handled, newIndex: newIndex);

      case LogicalKeyboardKey.arrowDown:
        final newIndex = (currentIndex + 1).clamp(0, maxIndex);
        return (result: KeyEventResult.handled, newIndex: newIndex);

      case LogicalKeyboardKey.arrowLeft:
        if (isSubMenu && onAdjust != null) {
          onAdjust(-1);
        } else {
          onBack?.call();
        }
        return (result: KeyEventResult.handled, newIndex: currentIndex);

      case LogicalKeyboardKey.arrowRight:
        if (isSubMenu && onAdjust != null) {
          onAdjust(1);
        } else {
          onActivate?.call();
        }
        return (result: KeyEventResult.handled, newIndex: currentIndex);

      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.select:
        onActivate?.call();
        return (result: KeyEventResult.handled, newIndex: currentIndex);

      case LogicalKeyboardKey.escape:
        onBack?.call();
        return (result: KeyEventResult.handled, newIndex: currentIndex);

      default:
        return (result: KeyEventResult.ignored, newIndex: currentIndex);
    }
  }

  /// 处理选集面板导航（垂直/水平模式）
  ///
  /// [event] - 键盘事件
  /// [currentIndex] - 当前选中索引
  /// [maxIndex] - 最大索引
  /// [onSelect] - 选中回调
  /// [onClose] - 关闭面板回调
  static ({KeyEventResult result, int newIndex}) handleEpisodePanelNavigation(
    KeyEvent event, {
    required int currentIndex,
    required int maxIndex,
    VoidCallback? onSelect,
    VoidCallback? onClose,
  }) {
    // 支持长按连续移动 (KeyRepeatEvent)
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return (result: KeyEventResult.ignored, newIndex: currentIndex);
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        final newIndex = (currentIndex - 1).clamp(0, maxIndex);
        return (result: KeyEventResult.handled, newIndex: newIndex);

      case LogicalKeyboardKey.arrowDown:
        final newIndex = (currentIndex + 1).clamp(0, maxIndex);
        return (result: KeyEventResult.handled, newIndex: newIndex);

      case LogicalKeyboardKey.arrowLeft:
        onClose?.call();
        return (result: KeyEventResult.handled, newIndex: currentIndex);

      case LogicalKeyboardKey.arrowRight:
        // 右键在选集面板为无效操作
        return (result: KeyEventResult.handled, newIndex: currentIndex);

      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.select:
        onSelect?.call();
        return (result: KeyEventResult.handled, newIndex: currentIndex);

      case LogicalKeyboardKey.escape:
        onClose?.call();
        return (result: KeyEventResult.handled, newIndex: currentIndex);

      default:
        return (result: KeyEventResult.ignored, newIndex: currentIndex);
    }
  }

  /// 处理快进快退指示器导航（特殊预览模式）
  ///
  /// [event] - 键盘事件
  /// [onSeekBackward] - 后退回调
  /// [onSeekForward] - 前进回调
  /// [onConfirm] - 确认跳转回调
  /// [onCancel] - 取消预览回调
  static KeyEventResult handleSeekPreviewNavigation(
    KeyEvent event, {
    VoidCallback? onSeekBackward,
    VoidCallback? onSeekForward,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    // 支持 KeyRepeat 用于快速拖动
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        onSeekBackward?.call();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowRight:
        onSeekForward?.call();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.select:
        if (event is KeyDownEvent) {
          onConfirm?.call();
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
      case LogicalKeyboardKey.browserBack:
        if (event is KeyDownEvent) {
          onCancel?.call();
        }
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  /// 检查是否是返回键
  static bool isBackKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.browserBack ||
        event.logicalKey == LogicalKeyboardKey.escape;
  }

  /// 检查是否是确认键
  static bool isSelectKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select;
  }
}
