// Imports removed

class MpdGenerator {
  /// 生成 DASH MPD 文件
  /// [dashData] 是 Bilibili API 返回的 dash 对象
  static Future<String> generate(Map<String, dynamic> dashData) async {
    final buffer = StringBuffer();

    // MPD 头部
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<MPD xmlns="urn:mpeg:dash:schema:mpd:2011"');
    buffer.writeln(
      '     profiles="urn:mpeg:dash:profile:isoff-on-demand:2011"',
    );
    // 提高最小缓冲时间，减少卡顿/掉帧（ExoPlayer 会据此缓冲更多数据）
    final minBufferSec = (double.tryParse(dashData['minBufferTime']?.toString() ?? '1.5') ?? 1.5);
    final minBufferTimeSec = minBufferSec < 4.0 ? 4.0 : minBufferSec;
    buffer.writeln('     minBufferTime="PT${minBufferTimeSec}S"');
    buffer.writeln('     type="static"');
    buffer.writeln(
      '     mediaPresentationDuration="PT${dashData['duration']}S">',
    );

    buffer.writeln('  <Period>');

    // 视频自适应集
    if (dashData['video'] != null) {
      buffer.writeln(
        '    <AdaptationSet mimeType="video/mp4" contentType="video" subsegmentAlignment="true" subsegmentStartsWithSAP="1">',
      );
      for (var video in dashData['video']) {
        _writeRepresentation(buffer, video, true);
      }
      buffer.writeln('    </AdaptationSet>');
    }

    // 音频自适应集
    if (dashData['audio'] != null) {
      buffer.writeln(
        '    <AdaptationSet mimeType="audio/mp4" contentType="audio" subsegmentAlignment="true" subsegmentStartsWithSAP="1">',
      );
      for (var audio in dashData['audio']) {
        _writeRepresentation(buffer, audio, false);
      }
      buffer.writeln('    </AdaptationSet>');
    }

    buffer.writeln('  </Period>');
    buffer.writeln('</MPD>');

    // 直接返回内容
    return buffer.toString();
  }

  static void _writeRepresentation(
    StringBuffer buffer,
    Map<String, dynamic> stream,
    bool isVideo,
  ) {
    // 基础信息
    final id = stream['id'];
    final codecs = stream['codecs'] ?? (isVideo ? 'avc1.64001E' : 'mp4a.40.2');
    final bandwidth = stream['bandwidth'];
    final width = stream['width'];
    final height = stream['height'];
    final frameRate = stream['frameRate'];
    // 优先使用 baseUrl，备用使用 backupUrl
    final baseUrl = stream['baseUrl'] ?? stream['base_url'];

    buffer.write(
      '      <Representation id="$id" codecs="$codecs" bandwidth="$bandwidth"',
    );
    if (isVideo) {
      buffer.write(' width="$width" height="$height" frameRate="$frameRate"');
      // 基本播放不需要 Sar / ScanType
    }
    buffer.writeln('>');

    // 基础 URL
    // 对 URL 进行 XML 转义以防万一
    final escapedUrl = baseUrl
        .toString()
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');

    buffer.writeln('        <BaseURL>$escapedUrl</BaseURL>');

    // 备用 URL (CDN 容灾)
    if (stream['backupUrl'] != null && stream['backupUrl'] is List) {
      for (final backup in stream['backupUrl']) {
        if (backup != null && backup is String && backup.isNotEmpty) {
          final escapedBackup = backup
              .replaceAll('&', '&amp;')
              .replaceAll('<', '&lt;')
              .replaceAll('>', '&gt;')
              .replaceAll('"', '&quot;')
              .replaceAll("'", '&apos;');
          buffer.writeln('        <BaseURL>$escapedBackup</BaseURL>');
        }
      }
    }

    // 初始化范围 (分片 MP4 必须)
    // Bilibili 通常通过 SegmentBase 提供 Initialization 和 indexRange

    if (stream['SegmentBase'] != null) {
      final seg = stream['SegmentBase'];
      final init = seg['Initialization'];
      final index = seg['indexRange'];
      buffer.writeln('        <SegmentBase indexRange="$index">');
      buffer.writeln('          <Initialization range="$init"/>');
      buffer.writeln('        </SegmentBase>');
    }

    buffer.writeln('      </Representation>');
  }
}
