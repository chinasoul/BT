import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'base_api.dart';
import '../../models/videoshot.dart';

/// 视频快照 API
class VideoshotApi {
  /// 获取视频快照(雪碧图)数据
  ///
  /// [bvid] 视频 BV 号
  /// [cid] 视频分P的 cid (可选，不传则获取默认分P)
  static Future<VideoshotData?> getVideoshot({
    required String bvid,
    int? cid,
    bool preloadAllImages = true,
  }) async {
    try {
      final params = <String, String>{'bvid': bvid};
      if (cid != null) {
        params['cid'] = cid.toString();
      }

      final uri = Uri.parse(
        '${BaseApi.apiBase}/x/player/videoshot',
      ).replace(queryParameters: params);

      final response = await http.get(uri, headers: BaseApi.getHeaders());

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 0 && json['data'] != null) {
          final data = json['data'] as Map<String, dynamic>;
          final images = data['image'] as List<dynamic>?;

          // 检查是否有有效的雪碧图
          if (images != null && images.isNotEmpty) {
            final videoshotData = VideoshotData.fromJson(data);

            // 异步加载 pvdata（精确时间戳）和图片资源
            if (videoshotData.pvdataUrl != null) {
              _loadPvdata(videoshotData);
            }
            if (preloadAllImages) {
              _preloadImages(videoshotData);
            }

            return videoshotData;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to get videoshot: $e');
    }
    return null;
  }

  /// 异步加载 pvdata.bin 并解析帧时间戳
  static Future<void> _loadPvdata(VideoshotData data) async {
    if (data.pvdataUrl == null) return;

    try {
      final response = await http.get(
        Uri.parse(data.pvdataUrl!),
        headers: BaseApi.getHeaders(),
      );

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final timestamps = VideoshotData.parsePvdata(Uint8List.fromList(bytes));
        data.setTimestamps(timestamps);
        debugPrint('Loaded ${timestamps.length} frame timestamps from pvdata');
      }
    } catch (e) {
      debugPrint('Failed to load pvdata: $e');
      // 加载失败时继续使用均匀分布估算
    }
  }

  /// 自定义缓存管理器，用于管理雪碧图
  /// 增加最大缓存数量(1000)和保留时间(7天)，避免频繁清理导致重新下载
  static final cacheManager = CacheManager(
    Config(
      'videoshot_cache',
      stalePeriod: const Duration(hours: 5),
      maxNrOfCacheObjects: 100,
      repo: JsonCacheInfoRepository(databaseName: 'videoshot_cache'),
      fileService: HttpFileService(),
    ),
  );

  /// 预加载雪碧图图片到缓存
  static Future<void> _preloadImages(VideoshotData data) async {
    try {
      for (final url in data.images) {
        // 使用自定义缓存管理器预下载
        cacheManager.downloadFile(url);
      }
      debugPrint('Started preloading ${data.images.length} videoshot images');
    } catch (e) {
      debugPrint('Failed to preload images: $e');
    }
  }

  /// 预加载单张雪碧图到 Flutter 内存缓存 (GPU)
  ///
  /// [context] Flutter BuildContext
  /// [url] 雪碧图 URL
  static Future<void> precacheSprite(BuildContext context, String url) async {
    try {
      final provider = CachedNetworkImageProvider(
        url,
        cacheManager: cacheManager,
        headers: const {
          'Referer': 'https://www.bilibili.com',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36',
        },
      );
      await precacheImage(provider, context);
      debugPrint('Precached sprite to GPU: ${url.split('/').last}');
    } catch (e) {
      debugPrint('Failed to precache sprite: $e');
    }
  }

  /// 从 Flutter 内存缓存中移除雪碧图
  ///
  /// [url] 雪碧图 URL
  static void evictSprite(String url) {
    try {
      final provider = CachedNetworkImageProvider(
        url,
        cacheManager: cacheManager,
        headers: const {
          'Referer': 'https://www.bilibili.com',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36',
        },
      );
      provider.evict();
      debugPrint('Evicted sprite from GPU: ${url.split('/').last}');
    } catch (e) {
      debugPrint('Failed to evict sprite: $e');
    }
  }
}
