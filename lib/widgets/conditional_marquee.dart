import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/settings_service.dart';

/// 轻量级条件滚动文本组件
///
/// 仅在文本宽度超出容器时才启动水平滚动动画。
///
/// 性能关键设计：
/// - 使用自定义 RenderObject 直接在 paint 阶段偏移文本，不触发 widget rebuild
/// - 外层 RepaintBoundary 隔离重绘范围，滚动时不影响卡片图片区域
/// - Timer.periodic 驱动而非 Ticker：不绑定 vsync，不强制引擎保持 60fps 渲染循环
///   Timer 间隔期间引擎完全休眠，仅在 markNeedsPaint 时唤醒渲染一帧
/// - 文本宽度仅在 text/style/constraints 变化时测量一次并缓存
class ConditionalMarquee extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double blankSpace;
  final double velocity;
  final int? maxLines;
  final bool alwaysScroll;

  /// 开始滚动前的延迟时间（用于聚焦后延迟启动）
  final Duration startDelay;

  const ConditionalMarquee({
    super.key,
    required this.text,
    required this.style,
    this.blankSpace = 30.0,
    this.velocity = 50.0,
    this.maxLines = 1,
    this.alwaysScroll = false,
    this.startDelay = const Duration(milliseconds: 500),
  });

  @override
  State<ConditionalMarquee> createState() => _ConditionalMarqueeState();
}

class _ConditionalMarqueeState extends State<ConditionalMarquee> {
  /// 文本是否溢出容器
  bool _needsScroll = false;

  /// 容器宽度缓存
  double _containerWidth = 0;

  /// 文本宽度缓存
  double _textWidth = 0;

  /// 一轮循环的总距离 = textWidth + blankSpace
  double _loopDistance = 0;

  /// 当前滚动偏移
  double _offset = 0;

  /// Timer 驱动滚动，不绑定 vsync，引擎在 timer 间隔内可完全休眠
  Timer? _scrollTimer;

  /// 滚动起始时间戳
  DateTime _scrollStartTime = DateTime.now();

  /// 滚动一轮的时长
  Duration _scrollDuration = Duration.zero;

  /// 动画帧率（从设置读取，支持 30/60fps 切换）
  static Duration get _frameInterval =>
      Duration(milliseconds: SettingsService.marqueeFps == 30 ? 33 : 16);

  /// RenderObject key，用于直接标记 repaint
  final _paintKey = GlobalKey();

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _scrollTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ConditionalMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _stopAnimation();
      _containerWidth = 0;
      _textWidth = 0;
    }
  }

  double _measureTextWidth() {
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return tp.width;
  }

  void _configureIfNeeded(double containerWidth) {
    if (containerWidth == _containerWidth && _textWidth > 0) return;

    _containerWidth = containerWidth;
    _textWidth = _measureTextWidth();
    final shouldScroll = widget.alwaysScroll || _textWidth > _containerWidth;

    if (shouldScroll && !_needsScroll) {
      _needsScroll = true;
      _loopDistance = _textWidth + widget.blankSpace;
      final ms = (_loopDistance / widget.velocity * 1000).round();
      _scrollDuration = Duration(milliseconds: ms.clamp(500, 30000));
      _startAnimation();
    } else if (!shouldScroll && _needsScroll) {
      _needsScroll = false;
      _stopAnimation();
    } else if (shouldScroll && _needsScroll) {
      _loopDistance = _textWidth + widget.blankSpace;
      final ms = (_loopDistance / widget.velocity * 1000).round();
      _scrollDuration = Duration(milliseconds: ms.clamp(500, 30000));
    }
  }

  void _startAnimation() {
    _offset = 0;
    _markNeedsPaint();
    _beginDelayPhase();
  }

  void _stopAnimation() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _offset = 0;
    _markNeedsPaint();
  }

  /// delay 阶段：等待 startDelay 后开始滚动
  void _beginDelayPhase() async {
    await Future.delayed(widget.startDelay);
    if (_disposed || !_needsScroll) return;
    _beginScrollPhase();
  }

  /// scrolling 阶段：Timer.periodic 驱动，每次 tick 计算 offset 并 markNeedsPaint
  /// Timer 间隔期间 Flutter 引擎完全休眠，不维持 vsync 渲染循环
  void _beginScrollPhase() {
    _scrollStartTime = DateTime.now();
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(_frameInterval, _onTimerTick);
  }

  void _onTimerTick(Timer timer) {
    if (_disposed || !_needsScroll) {
      timer.cancel();
      return;
    }

    final elapsed = DateTime.now().difference(_scrollStartTime);

    if (elapsed >= _scrollDuration) {
      // 一轮循环结束
      timer.cancel();
      _scrollTimer = null;
      _offset = 0;
      _markNeedsPaint();
      _beginPausePhase();
    } else {
      final t = elapsed.inMicroseconds / _scrollDuration.inMicroseconds;
      _offset = t * _loopDistance;
      _markNeedsPaint();
    }
  }

  /// pause 阶段：Timer 已取消，引擎完全休眠
  void _beginPausePhase() async {
    await Future.delayed(const Duration(seconds: 3));
    if (_disposed || !_needsScroll) return;
    _beginScrollPhase();
  }

  void _markNeedsPaint() {
    final ro = _paintKey.currentContext?.findRenderObject();
    if (ro != null) {
      ro.markNeedsPaint();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _configureIfNeeded(constraints.maxWidth);

        if (!_needsScroll) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: widget.maxLines,
            overflow: TextOverflow.ellipsis,
          );
        }

        // RepaintBoundary 隔离：滚动重绘不扩散到卡片其余区域
        return RepaintBoundary(
          child: _MarqueeRenderWidget(
            key: _paintKey,
            state: this,
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
        );
      },
    );
  }
}

/// 自定义单子 RenderObject：在 paint 阶段直接 clip + translate，
/// 不触发 layout，不触发 widget rebuild。
class _MarqueeRenderWidget extends SingleChildRenderObjectWidget {
  final _ConditionalMarqueeState state;

  const _MarqueeRenderWidget({
    super.key,
    required this.state,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMarquee(state: state);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderMarquee renderObject) {
    renderObject.state = state;
  }
}

class _RenderMarquee extends RenderProxyBox {
  _ConditionalMarqueeState state;

  _RenderMarquee({required this.state});

  @override
  bool get isRepaintBoundary => false; // 由外层 RepaintBoundary 管

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;

    final clipRect = Offset.zero & size;
    final dx = state._offset;
    final loopDist = state._textWidth + state.widget.blankSpace;

    context.pushClipRect(needsCompositing, offset, clipRect, (
      PaintingContext innerContext,
      Offset innerOffset,
    ) {
      // 第一份文字
      innerContext.paintChild(child!, innerOffset + Offset(-dx, 0));
      // 第二份文字：紧跟在第一份后面，间隔 blankSpace
      if (dx > 0) {
        innerContext.paintChild(
          child!,
          innerOffset + Offset(-dx + loopDist, 0),
        );
      }
    });
  }
}
