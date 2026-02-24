import 'package:flutter/material.dart';
import '../../../../services/settings_service.dart';
import '../../../../config/app_style.dart';
import '../widgets/setting_toggle_row.dart';

class DeveloperSettings extends StatefulWidget {
  final VoidCallback onMoveUp;
  final FocusNode? sidebarFocusNode;

  const DeveloperSettings({
    super.key,
    required this.onMoveUp,
    this.sidebarFocusNode,
  });

  @override
  State<DeveloperSettings> createState() => _DeveloperSettingsState();
}

class _DeveloperSettingsState extends State<DeveloperSettings> {
  bool _developerMode = true;
  bool _showMemoryInfo = false;
  bool _showAppCpu = false;
  bool _showCoreFreq = false;
  bool _marquee60fps = true;

  final FocusNode _devToggleFocusNode = FocusNode();
  final FocusNode _memoryToggleFocusNode = FocusNode();
  final FocusNode _appCpuToggleFocusNode = FocusNode();
  final FocusNode _coreFreqToggleFocusNode = FocusNode();
  final FocusNode _fpsToggleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _developerMode = SettingsService.developerMode;
    _showMemoryInfo = SettingsService.showMemoryInfo;
    _showAppCpu = SettingsService.showAppCpu;
    _showCoreFreq = SettingsService.showCoreFreq;
    _marquee60fps = SettingsService.marqueeFps == 60;
  }

  @override
  void dispose() {
    _devToggleFocusNode.dispose();
    _memoryToggleFocusNode.dispose();
    _appCpuToggleFocusNode.dispose();
    _coreFreqToggleFocusNode.dispose();
    _fpsToggleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 开发者选项总开关
        SettingToggleRow(
          label: '开发者选项',
          subtitle: '关闭后此页面将隐藏，需重新在本机信息中触发',
          value: _developerMode,
          autofocus: true,
          focusNode: _devToggleFocusNode,
          isFirst: true,
          onMoveUp: widget.onMoveUp,
          onMoveDown: () => _memoryToggleFocusNode.requestFocus(),
          sidebarFocusNode: widget.sidebarFocusNode,
          onChanged: (v) {
            setState(() => _developerMode = v);
            SettingsService.setDeveloperMode(v);
          },
        ),
        const SizedBox(height: AppSpacing.settingItemGap),

        // 2. 显示 CPU/内存信息
        SettingToggleRow(
          label: '显示CPU/内存信息',
          subtitle: '左下角显示占用率和内存',
          value: _showMemoryInfo,
          focusNode: _memoryToggleFocusNode,
          onMoveUp: () => _devToggleFocusNode.requestFocus(),
          onMoveDown: () => _appCpuToggleFocusNode.requestFocus(),
          sidebarFocusNode: widget.sidebarFocusNode,
          onChanged: (v) {
            setState(() => _showMemoryInfo = v);
            SettingsService.setShowMemoryInfo(v);
          },
        ),
        const SizedBox(height: AppSpacing.settingItemGap),

        // 3. 显示 APP 占用率
        SettingToggleRow(
          label: '显示APP占用率',
          subtitle: '额外显示进程CPU整机百分比',
          value: _showAppCpu,
          focusNode: _appCpuToggleFocusNode,
          onMoveUp: () => _memoryToggleFocusNode.requestFocus(),
          onMoveDown: () => _coreFreqToggleFocusNode.requestFocus(),
          sidebarFocusNode: widget.sidebarFocusNode,
          onChanged: (v) {
            setState(() => _showAppCpu = v);
            SettingsService.setShowAppCpu(v);
          },
        ),
        const SizedBox(height: AppSpacing.settingItemGap),

        // 4. 显示核心频率
        SettingToggleRow(
          label: '显示核心频率',
          subtitle: '额外显示各CPU核心当前频率',
          value: _showCoreFreq,
          focusNode: _coreFreqToggleFocusNode,
          onMoveUp: () => _appCpuToggleFocusNode.requestFocus(),
          onMoveDown: () => _fpsToggleFocusNode.requestFocus(),
          sidebarFocusNode: widget.sidebarFocusNode,
          onChanged: (v) {
            setState(() => _showCoreFreq = v);
            SettingsService.setShowCoreFreq(v);
          },
        ),
        const SizedBox(height: AppSpacing.settingItemGap),

        // 5. 滚动文字帧率
        SettingToggleRow(
          label: '滚动文字60帧',
          subtitle: '关闭后降至30帧，减少CPU占用',
          value: _marquee60fps,
          focusNode: _fpsToggleFocusNode,
          isLast: true,
          onMoveUp: () => _coreFreqToggleFocusNode.requestFocus(),
          sidebarFocusNode: widget.sidebarFocusNode,
          onChanged: (v) {
            setState(() => _marquee60fps = v);
            SettingsService.setMarqueeFps(v ? 60 : 30);
          },
        ),
      ],
    );
  }
}
