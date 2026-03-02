// Imports removed

class MpdGenerator {
  /// 生成 DASH MPD 文件
  /// [dashData] 是 Bilibili API 返回的 dash 对象
  /// [selectedQn] 若指定，则只保留该画质等级 (id) 的视频 Representation，
  ///   阻止 ExoPlayer ABR 自动降级到低分辨率
  /// [selectedCodec] 若指定，则只保留 codecs 以此前缀开头的视频 Representation，
  ///   确保 ExoPlayer 使用正确的解码器（如 dvhe → video/dolby-vision）
  static Future<String> generate(
    Map<String, dynamic> dashData, {
    int? selectedQn,
    String? selectedCodec,
  }) async {
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

    // 杜比视界视频（dash.dolby.video）—— DV 流在此，优先于 dash.video
    bool hasDolbyVideo = false;
    if (selectedCodec != null &&
        (selectedCodec!.startsWith('dvhe') ||
            selectedCodec!.startsWith('dvh1') ||
            selectedCodec!.startsWith('dvav')) &&
        dashData['dolby'] != null &&
        dashData['dolby']['video'] is List) {
      final dolbyVideos = dashData['dolby']['video'] as List;
      if (dolbyVideos.isNotEmpty) {
        hasDolbyVideo = true;
        buffer.writeln(
          '    <AdaptationSet mimeType="video/mp4" contentType="video" subsegmentAlignment="true" subsegmentStartsWithSAP="1">',
        );
        for (var video in dolbyVideos) {
          if (video is Map<String, dynamic>) {
            _writeRepresentation(buffer, video, true);
          }
        }
        buffer.writeln('    </AdaptationSet>');
      }
    }

    // 普通视频自适应集（DV 流已单独处理时跳过）
    if (!hasDolbyVideo && dashData['video'] != null) {
      buffer.writeln(
        '    <AdaptationSet mimeType="video/mp4" contentType="video" subsegmentAlignment="true" subsegmentStartsWithSAP="1">',
      );
      for (var video in dashData['video']) {
        if (selectedQn != null && (video['id'] as int?) != selectedQn) {
          continue;
        }
        if (selectedCodec != null) {
          final codecs = (video['codecs'] as String?) ?? '';
          if (!codecs.startsWith(selectedCodec!)) continue;
        }
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

    // 杜比全景声音频（E-AC-3 / ec-3）
    if (dashData['dolby'] != null && dashData['dolby']['audio'] is List) {
      final dolbyAudios = dashData['dolby']['audio'] as List;
      if (dolbyAudios.isNotEmpty) {
        buffer.writeln(
          '    <AdaptationSet mimeType="audio/mp4" contentType="audio" subsegmentAlignment="true" subsegmentStartsWithSAP="1" lang="dolby">',
        );
        for (var audio in dolbyAudios) {
          if (audio is Map<String, dynamic>) {
            _writeRepresentation(buffer, audio, false);
          }
        }
        buffer.writeln('    </AdaptationSet>');
      }
    }

    // Hi-Res FLAC 音频
    if (dashData['flac'] != null && dashData['flac']['audio'] != null) {
      final flacAudio = dashData['flac']['audio'];
      if (flacAudio is Map<String, dynamic>) {
        buffer.writeln(
          '    <AdaptationSet mimeType="audio/mp4" contentType="audio" subsegmentAlignment="true" subsegmentStartsWithSAP="1" lang="flac">',
        );
        _writeRepresentation(buffer, flacAudio, false);
        buffer.writeln('    </AdaptationSet>');
      }
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
