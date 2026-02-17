import 'package:flutter/material.dart';
import 'package:bili_tv_app/utils/toast_utils.dart';
import '../../../../services/settings_service.dart';
import '../../../../config/app_style.dart';
import '../widgets/setting_action_row.dart';
import '../widgets/setting_toggle_row.dart';

class StorageSettings extends StatefulWidget {
  final VoidCallback onMoveUp;
  final FocusNode? sidebarFocusNode;

  const StorageSettings({
    super.key,
    required this.onMoveUp,
    this.sidebarFocusNode,
  });

  @override
  State<StorageSettings> createState() => _StorageSettingsState();
}

class _StorageSettingsState extends State<StorageSettings> {
  double _cacheSizeMB = 0;
  bool _isClearing = false;
  bool _showMemoryInfo = false;
  final FocusNode _buttonFocusNode = FocusNode();
  final FocusNode _memoryToggleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _showMemoryInfo = SettingsService.showMemoryInfo;
    _loadCacheSize();
  }

  @override
  void dispose() {
    _buttonFocusNode.dispose();
    _memoryToggleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCacheSize() async {
    final size = await SettingsService.getImageCacheSizeMB();
    if (mounted) setState(() => _cacheSizeMB = size);
  }

  Future<void> _clearCache() async {
    setState(() => _isClearing = true);
    await SettingsService.clearImageCache();
    await _loadCacheSize();
    if (mounted) {
      setState(() => _isClearing = false);
      ToastUtils.show(context, '缓存已清除');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingActionRow(
          label: '清除图片缓存',
          value: '${_cacheSizeMB.toStringAsFixed(1)} MB',
          buttonLabel: _isClearing ? '清除中...' : '清除',
          autofocus: true,
          focusNode: _buttonFocusNode,
          isFirst: true,
          isLast: false,
          onMoveUp: widget.onMoveUp,
          onMoveDown: () => _memoryToggleFocusNode.requestFocus(),
          sidebarFocusNode: widget.sidebarFocusNode,
          onTap: _isClearing ? null : _clearCache,
        ),
        const SizedBox(height: AppSpacing.settingItemGap),
        SettingToggleRow(
          label: '显示CPU/内存信息(调试用)',
          subtitle: '左下角始终显示',
          value: _showMemoryInfo,
          focusNode: _memoryToggleFocusNode,
          isLast: true,
          onMoveUp: () => _buttonFocusNode.requestFocus(),
          sidebarFocusNode: widget.sidebarFocusNode,
          onChanged: (v) {
            setState(() => _showMemoryInfo = v);
            SettingsService.setShowMemoryInfo(v);
          },
        ),
      ],
    );
  }
}
