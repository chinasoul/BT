import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../auth_service.dart';
import 'base_api.dart';

/// Bilibili 直播 API
class LiveApi {
  /// 获取直播间信息 (包含真实 RoomID)
  static Future<Map<String, dynamic>?> getRoomInfo(int roomId) async {
    try {
      final url =
          'https://api.live.bilibili.com/room/v1/Room/get_info?room_id=$roomId';
      final response = await http.get(
        Uri.parse(url),
        headers: BaseApi.getHeaders(),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 0) {
          return json['data'];
        }
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// 获取直播播放地址 (v2 API - getRoomPlayInfo)
  /// [roomId] 房间号
  /// [qn] 画质 10000=原画
  static Future<Map<String, dynamic>?> getPlayUrl(
    int roomId, {
    int qn = 10000,
  }) async {
    try {
      final url =
          'https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo'
          '?room_id=$roomId&protocol=0,1&format=0,1,2&codec=0'
          '&qn=$qn&platform=web&ptype=8&dolby=5&panorama=1';

      final response = await http.get(
        Uri.parse(url),
        headers: BaseApi.getHeaders(withCookie: true),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 0 && json['data'] != null) {
          return json['data'];
        }
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// 获取弹幕服务器配置
  static Future<Map<String, dynamic>?> getDanmakuConf(int roomId) async {
    // 1. Try XLIVE API (New)
    try {
      final url =
          'https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo?id=$roomId&type=0';
      final headers = BaseApi.getHeaders(withCookie: true);
      headers['Referer'] = 'https://live.bilibili.com/$roomId';

      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 0) {
          debugPrint('LiveApi: XLIVE Danmaku Conf Success');
          return json['data'];
        } else {
          debugPrint(
            'LiveApi: XLIVE API Error: ${json['message']} (${json['code']}) - Trying Fallback...',
          );
        }
      }
    } catch (e) {
      debugPrint('LiveApi: XLIVE Exception: $e');
    }

    // 2. Try Legacy API (V1) - Fallback for -352 or other errors
    try {
      final url =
          'https://api.live.bilibili.com/room/v1/Danmu/getConf?room_id=$roomId&platform=pc&player=web';
      final headers = BaseApi.getHeaders(withCookie: true);
      headers['Referer'] = 'https://live.bilibili.com/$roomId';

      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 0) {
          debugPrint('LiveApi: Legacy Danmaku Conf Success');
          final data = json['data'];
          // Normalize field names
          if (data['host_server_list'] != null) {
            data['host_list'] = data['host_server_list'];
          }
          return data;
        } else {
          debugPrint(
            'LiveApi: Legacy API Error: ${json['message']} (${json['code']})',
          );
        }
      }
    } catch (e) {
      debugPrint('LiveApi: Legacy Exception: $e');
    }

    return null;
  }

  /// 获取推荐直播列表
  static Future<List<dynamic>> getRecommended({
    int page = 1,
    int pageSize = 30,
    int parentId = 0,
    int areaId = 0,
  }) async {
    try {
      if (parentId > 0) {
        // 使用 v3 接口获取指定父分区的内容 (v1 接口忽略 parent_area_id)
        final url =
            'https://api.live.bilibili.com/room/v3/area/getRoomList?parent_area_id=$parentId&area_id=$areaId&sort_type=online&page=$page&page_size=$pageSize';

        final response = await http.get(
          Uri.parse(url),
          headers: BaseApi.getHeaders(),
        );
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['code'] == 0 && json['data'] != null) {
            return json['data']['list'] as List;
          }
        }
      } else {
        // 使用 v1 接口获取推荐 (全部/默认)
        final url =
            'https://api.live.bilibili.com/room/v1/Area/getListByAreaID?areaId=$areaId&sort=online&pageSize=$pageSize&page=$page&parent_area_id=$parentId';

        final response = await http.get(
          Uri.parse(url),
          headers: BaseApi.getHeaders(),
        );
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['code'] == 0 && json['data'] != null) {
            return json['data'] as List;
          }
        }
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  /// 获取我的关注正在直播
  static Future<List<dynamic>> getFollowedLive({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final url =
          'https://api.live.bilibili.com/relation/v1/feed/feed_list?page=$page&pagesize=$pageSize';
      final response = await http.get(
        Uri.parse(url),
        headers: BaseApi.getHeaders(withCookie: true),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 0 && json['data'] != null) {
          final list = json['data']['list'] as List? ?? [];
          if (list.isNotEmpty) {
            debugPrint('LiveApi: Feed Item Raw: ${list.first}');
          }
          // feed_list returns "your following who are live", so no need to filter by status
          return list;
        }
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  /// 获取直播分区列表 (父分区)
  /// 如: 网游, 手游, 单机, 娱乐
  static Future<List<dynamic>> getParentAreas() async {
    // 简化版：手动定义几个常用分区，或者调用 API
    // https://api.live.bilibili.com/room/v1/Area/getList?need_entrance=1&parent_area_id=0
    try {
      final url =
          'https://api.live.bilibili.com/room/v1/Area/getList?need_entrance=1&parent_area_id=0';
      final response = await http.get(
        Uri.parse(url),
        headers: BaseApi.getHeaders(),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 0) {
          return json['data'] as List;
        }
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  /// 获取与用户的关系 (关注状态)
  /// [fid] 目标用户 UID
  static Future<Map<String, dynamic>?> getRelation(int fid) async {
    try {
      final url = 'https://api.bilibili.com/x/relation?fid=$fid';
      final response = await http.get(
        Uri.parse(url),
        headers: BaseApi.getHeaders(withCookie: true),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 0) {
          return json['data'];
        }
      }
    } catch (e) {
      debugPrint('LiveApi: Get Relation Error: $e');
    }
    return null;
  }

  /// 修改关注关系
  /// [fid] 目标用户 UID
  /// [act] 1=关注, 2=取消关注
  static Future<bool> modifyRelation(int fid, int act) async {
    try {
      final url = 'https://api.bilibili.com/x/relation/modify';
      final body = {
        'fid': fid.toString(),
        'act': act.toString(),
        're_src': '11',
        'csrf': AuthService.biliJct ?? '',
      };

      final response = await http.post(
        Uri.parse(url),
        headers: BaseApi.getHeaders(withCookie: true),
        body: body,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 0) {
          return true;
        } else {
          debugPrint('LiveApi: Modify Relation Failed: ${json['message']}');
        }
      }
    } catch (e) {
      debugPrint('LiveApi: Modify Relation Error: $e');
    }
    return false;
  }
}
