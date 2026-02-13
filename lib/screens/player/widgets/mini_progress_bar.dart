import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 迷你进度条 - 显示在屏幕底部，当控制栏隐藏时显示
/// 缓冲区间按实际 bufferedRanges 独立渲染，仅已缓冲部分显示黄色
class MiniProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final List<DurationRange> bufferedRanges;

  const MiniProgressBar({
    super.key,
    required this.position,
    required this.duration,
    this.bufferedRanges = const [],
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds;
    final progress = totalMs > 0 ? position.inMilliseconds / totalMs : 0.0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 4,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            return Stack(
              children: [
                // 背景条
                Container(color: Colors.white.withValues(alpha: 0.3)),
                // 缓冲区间（每个 range 独立定位）
                if (totalMs > 0)
                  for (final range in bufferedRanges)
                    Positioned(
                      left: (range.start.inMilliseconds / totalMs)
                              .clamp(0.0, 1.0) *
                          totalWidth,
                      width: ((range.end.inMilliseconds -
                                      range.start.inMilliseconds) /
                                  totalMs)
                              .clamp(0.0, 1.0) *
                          totalWidth,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        color:
                            const Color(0xFFFFF59D).withValues(alpha: 0.5),
                      ),
                    ),
                // 播放进度条
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF81C784),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
