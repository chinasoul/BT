class FavoriteFolder {
  final int id;
  final String title;
  final int mediaCount;
  final bool isDefault;

  const FavoriteFolder({
    required this.id,
    required this.title,
    this.mediaCount = 0,
    this.isDefault = false,
  });

  /// 序列化为 Map (用于本地缓存)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'mediaCount': mediaCount,
      'isDefault': isDefault,
    };
  }

  /// 从本地缓存 Map 反序列化
  factory FavoriteFolder.fromMap(Map<String, dynamic> json) {
    return FavoriteFolder(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      mediaCount: json['mediaCount'] ?? 0,
      isDefault: json['isDefault'] ?? false,
    );
  }

  factory FavoriteFolder.fromJson(Map<String, dynamic> json) {
    return FavoriteFolder(
      id: _toInt(json['id']),
      title: (json['title'] ?? '').toString(),
      mediaCount: _toInt(json['media_count']),
      isDefault: (json['fav_state'] ?? 0) == 0,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
