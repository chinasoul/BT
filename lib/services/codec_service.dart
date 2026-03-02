import 'package:flutter/services.dart';

/// 编解码器服务 - 查询设备硬件解码能力
class CodecService {
  static const _channel = MethodChannel('com.bili.tv/codec');

  // 缓存硬件解码器列表
  static List<String>? _hardwareDecoders;

  /// 获取设备支持的硬件解码格式
  /// 返回: ['avc', 'hevc', 'av1', 'vp9'] 等
  static Future<List<String>> getHardwareDecoders() async {
    if (_hardwareDecoders != null) {
      return _hardwareDecoders!;
    }

    try {
      final result = await _channel.invokeMethod('getHardwareDecoders');
      _hardwareDecoders = List<String>.from(result ?? []);
      return _hardwareDecoders!;
    } catch (e) {
      // 如果查询失败，返回空列表（将使用所有编码器）
      return [];
    }
  }

  /// 检查是否支持指定格式的硬件解码
  static Future<bool> hasHardwareDecoder(String codec) async {
    final decoders = await getHardwareDecoders();
    return decoders.contains(codec.toLowerCase());
  }

  /// 检查是否支持 H.264 硬解
  static Future<bool> hasAvcHardware() => hasHardwareDecoder('avc');

  /// 检查是否支持 HEVC 硬解
  static Future<bool> hasHevcHardware() => hasHardwareDecoder('hevc');

  /// 检查是否支持 AV1 硬解
  static Future<bool> hasAv1Hardware() => hasHardwareDecoder('av1');

  /// 检查是否支持杜比视界硬解
  static Future<bool> hasDolbyVisionHardware() => hasHardwareDecoder('dolby-vision');
}
