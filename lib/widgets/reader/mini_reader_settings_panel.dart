import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../services/desktop_mini_reader.dart';
import '../home/home_design.dart';
import 'mini_reader_binding_settings.dart';
import 'mini_reader_ink_settings.dart';
import 'mini_reader_page_keys.dart';

class MiniReaderSettingsPanel extends StatefulWidget {
  const MiniReaderSettingsPanel({
    super.key,
    this.fontSize = 18,
    this.onFontSizeChanged,
    this.video = false,
    required this.onClose,
    required this.onOpenShortcuts,
  });
  final double fontSize;
  final ValueChanged<double>? onFontSizeChanged;
  final bool video;
  final VoidCallback onClose;
  final VoidCallback onOpenShortcuts;

  @override
  State<MiniReaderSettingsPanel> createState() =>
      _MiniReaderSettingsPanelState();
}

class _MiniReaderSettingsPanelState extends State<MiniReaderSettingsPanel> {
  final _scroll = ScrollController();
  final _controller = DesktopMiniReaderController.instance;
  int _section = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: HomePalette.accent,
      primary: HomePalette.accentStrong,
      onPrimary: Colors.white,
      brightness: Brightness.light,
      surface: const Color(0xfffafbfc),
      onSurface: const Color(0xff202124),
      onSurfaceVariant: const Color(0xff555b61),
    );
    final textTheme = Theme.of(context).textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final theme = ThemeData.from(colorScheme: scheme, textTheme: textTheme)
        .copyWith(
          dividerTheme: const DividerThemeData(
            color: Color(0xffe3e6ea),
            thickness: 1,
            space: 1,
          ),
          iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 18),
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              minimumSize: const Size(36, 36),
              padding: const EdgeInsets.all(8),
            ),
          ),
          listTileTheme: ListTileThemeData(
            iconColor: scheme.onSurfaceVariant,
            titleTextStyle: textTheme.bodyMedium!.copyWith(
              fontSize: 14,
              color: scheme.onSurface,
            ),
            subtitleTextStyle: textTheme.bodySmall!.copyWith(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
          sliderTheme: const SliderThemeData(
            trackHeight: 3,
            showValueIndicator: ShowValueIndicator.onlyForContinuous,
          ),
        );
    return Theme(
      data: theme,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
        },
        child: Focus(
          autofocus: true,
          child: DefaultTabController(
            length: 3,
            animationDuration: HomeMotion.duration(context, 160),
            child: Material(
              key: const ValueKey('mini-settings-panel'),
              color: scheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xffdce0e5)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(),
                  const Divider(height: 1),
                  TabBar(
                    dividerColor: const Color(0xffe3e6ea),
                    labelColor: HomePalette.accentStrong,
                    unselectedLabelColor: scheme.onSurfaceVariant,
                    indicatorColor: HomePalette.accent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    labelPadding: EdgeInsets.zero,
                    onTap: (section) {
                      if (_section == section) return;
                      _scroll.jumpTo(0);
                      setState(() => _section = section);
                    },
                    tabs: [
                      Tab(
                        key: const ValueKey('mini-settings-appearance'),
                        text: widget.video ? '画面' : '外观',
                        height: 40,
                      ),
                      const Tab(
                        key: ValueKey('mini-settings-window'),
                        text: '窗口',
                        height: 40,
                      ),
                      const Tab(
                        key: ValueKey('mini-settings-keys'),
                        text: '按键',
                        height: 40,
                      ),
                    ],
                  ),
                  Flexible(
                    child: Scrollbar(
                      controller: _scroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: ListenableBuilder(
                          listenable: _controller,
                          builder: (context, _) => _content(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
    child: Row(
      children: [
        const Icon(
          LucideIcons.sliders_horizontal,
          size: 17,
          color: HomePalette.accentStrong,
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            '小窗设置',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          tooltip: '关闭小窗设置',
          icon: const Icon(LucideIcons.x, size: 18),
          onPressed: widget.onClose,
        ),
      ],
    ),
  );

  Widget _content() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_section == 0 && !widget.video) ...[
        _heading('文字外观'),
        _readingSettings(),
        const MiniReaderInkSettings(),
      ] else if (_section == 0) ...[
        _heading('画面'),
        Row(
          children: [
            const Text('不透明度'),
            Expanded(
              child: Slider(
                key: const ValueKey('mini-video-opacity'),
                min: .2,
                value: _controller.videoOpacity,
                onChanged: (v) => unawaited(_controller.setVideoOpacity(v)),
              ),
            ),
            Text('${(_controller.videoOpacity * 100).round()}%'),
          ],
        ),
      ],
      if (_section == 1) ...[
        _heading('窗口行为'),
        const MiniReaderBindingSettings(),
        SwitchListTile.adaptive(
          key: const ValueKey('mini-taskbar'),
          contentPadding: EdgeInsets.zero,
          title: const Text('隐藏任务栏图标', style: TextStyle(fontSize: 14)),
          value: _controller.skipTaskbar,
          onChanged: (value) => unawaited(_controller.setSkipTaskbar(value)),
        ),
      ],
      if (_section == 2) ...[
        _heading(widget.video ? '播放与快捷键' : '翻页与快捷键'),
        const SizedBox(height: 12),
        if (!widget.video) const MiniReaderPageKeys(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.keyboard, size: 18),
          title: const Text('管理所有快捷键', style: TextStyle(fontSize: 14)),
          trailing: const Icon(LucideIcons.chevron_right, size: 18),
          onTap: widget.onOpenShortcuts,
        ),
      ],
    ],
  );

  Widget _heading(String text) => Text(
    text,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );

  Widget _readingSettings() => Column(
    children: [
      const SizedBox(height: 12),
      Row(
        children: [
          const Text('深浅预设'),
          const Spacer(),
          for (final (light, color) in const [
            (false, Color(0xff292724)),
            (true, Color(0xffd2d2d2)),
          ])
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Tooltip(
                message: light ? '浅色文字' : '深色文字',
                child: InkResponse(
                  key: ValueKey('mini-text-$light'),
                  onTap: () => unawaited(_controller.setLightText(light)),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(color: Colors.grey),
                    ),
                    child: _controller.ink.color == color
                        ? Icon(
                            LucideIcons.check,
                            size: 16,
                            color: light ? Colors.black : Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
      Row(
        children: [
          const Text('字号'),
          const Spacer(),
          IconButton(
            tooltip: '缩小字号',
            icon: const Icon(LucideIcons.minus, size: 18),
            onPressed: widget.fontSize <= 14
                ? null
                : () => widget.onFontSizeChanged!(widget.fontSize - 1),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${widget.fontSize.round()}',
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            tooltip: '增大字号',
            icon: const Icon(LucideIcons.plus, size: 18),
            onPressed: widget.fontSize >= 32
                ? null
                : () => widget.onFontSizeChanged!(widget.fontSize + 1),
          ),
        ],
      ),
      Row(
        children: [
          const Text('背景'),
          Expanded(
            child: Slider(
              key: const ValueKey('mini-background-opacity'),
              value: _controller.backgroundOpacity,
              divisions: 20,
              label: '${(_controller.backgroundOpacity * 100).round()}%',
              onChanged: (v) => unawaited(_controller.setBackgroundOpacity(v)),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text('${(_controller.backgroundOpacity * 100).round()}%'),
          ),
        ],
      ),
    ],
  );
}
