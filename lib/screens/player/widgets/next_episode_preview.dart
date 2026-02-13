import 'package:flutter/material.dart';

/// 下一集预览卡片 — 从右下角滑入
class NextEpisodePreview extends StatelessWidget {
  final bool visible;
  final String title;
  final String? pic;
  final int countdown;

  const NextEpisodePreview({
    super.key,
    required this.visible,
    required this.title,
    this.pic,
    required this.countdown,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      bottom: 80,
      right: visible ? 24 : -320,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            // 缩略图
            if (pic != null && pic!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  pic!,
                  width: 80,
                  height: 45,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 80,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.skip_next,
                      color: Colors.white38,
                      size: 20,
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 80,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.skip_next,
                  color: Colors.white38,
                  size: 20,
                ),
              ),
            const SizedBox(width: 10),
            // 文字信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$countdown秒后播放',
                    style: const TextStyle(
                      color: Color(0xFF81C784),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
