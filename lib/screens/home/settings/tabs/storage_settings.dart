import 'package:flutter/material.dart';
import 'package:bili_tv_app/utils/toast_utils.dart';
import '../../../../services/settings_service.dart';
import '../widgets/setting_action_row.dart';

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
  static const Map<FocusedTitleDisplayMode, String> _modeSubtitles = {
    FocusedTitleDisplayMode.normal: '标题文字静态显示，超出部分省略',
    FocusedTitleDisplayMode.singleScroll: '标题文字滚动一次',
    FocusedTitleDisplayMode.loopScroll: '标题文字持续滚动',
  };

  double _cacheSizeMB = 0;
  bool _isClearing = false;
  FocusedTitleDisplayMode _focusedTitleDisplayMode =
      SettingsService.focusedTitleDisplayMode;
  final FocusNode _buttonFocusNode = FocusNode();

  String get _focusedTitleModeSubtitle =>
      _modeSubtitles[_focusedTitleDisplayMode] ?? '';

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  @override
  void dispose() {
    _buttonFocusNode.dispose();
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
          label: '视频卡片选中时标题显示方式',
          value: _focusedTitleModeSubtitle,
          buttonLabel: _focusedTitleDisplayMode.label,
          autofocus: true,
          isFirst: true,
          isLast: false,
          onMoveUp: widget.onMoveUp,
          sidebarFocusNode: widget.sidebarFocusNode,
          optionLabels: FocusedTitleDisplayMode.values
              .map((mode) => mode.label)
              .toList(),
          selectedOption: _focusedTitleDisplayMode.label,
          onTap: null,
          onOptionSelected: (selectedLabel) async {
            final selectedMode = FocusedTitleDisplayMode.values.firstWhere(
              (mode) => mode.label == selectedLabel,
              orElse: () => FocusedTitleDisplayMode.loopScroll,
            );
            await SettingsService.setFocusedTitleDisplayMode(selectedMode);
            if (!mounted) return;
            setState(() => _focusedTitleDisplayMode = selectedMode);
          },
        ),
        const SizedBox(height: 8),
        SettingActionRow(
          label: '清除图片缓存',
          value: '${_cacheSizeMB.toStringAsFixed(1)} MB',
          buttonLabel: _isClearing ? '清除中...' : '清除',
          autofocus: false,
          focusNode: _buttonFocusNode,
          isFirst: false,
          isLast: true,
          onMoveUp: widget.onMoveUp,
          sidebarFocusNode: widget.sidebarFocusNode,
          onTap: _isClearing ? null : _clearCache,
        ),
      ],
    );
  }
}
