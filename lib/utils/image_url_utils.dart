class ImageUrlUtils {
  /// 获取优化后的图片 URL
  ///
  /// [url] 原始图片 URL
  /// [width] 目标宽度
  /// [height] 目标高度 (可选)
  ///
  /// Bilibili 图片处理参数格式: @{width}w_{height}h_1c.webp
  /// 1c 表示启用裁剪
  static String getResizedUrl(
    String url, {
    int? width,
    int? height,
    int quality = 90,
  }) {
    if (url.isEmpty) return url;
    if (url.contains('@')) return url; // 已经包含处理参数，不再处理

    // 只需要 webp 格式 (B站支持)
    String suffix = '';

    if (width != null && height != null) {
      suffix = '@${width}w_${height}h_1c.webp';
    } else if (width != null) {
      suffix = '@${width}w.webp';
    } else {
      // 如果没有指定尺寸，默认转为 webp 以减小体积
      suffix = '@.webp';
    }

    return '$url$suffix';
  }
}
