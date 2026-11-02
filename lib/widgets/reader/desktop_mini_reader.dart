import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:window_manager/window_manager.dart';

import '../../services/desktop_mini_reader.dart';
import 'mini_reader_settings_panel.dart';
import 'reader_ink_text.dart';
import '../../services/desktop_shortcuts.dart';
import '../../pages/desktop_shortcuts_page.dart';
import '../desktop_shortcut_scope.dart';
import '../home/home_design.dart';

class DesktopMiniReaderButton extends StatelessWidget {
  const DesktopMiniReaderButton({super.key, required this.onEnter});

  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('reader-mini-window'),
    tooltip: '小窗阅读',
    icon: const Icon(LucideIcons.picture_in_picture_2),
    onPressed: DesktopMiniReaderController.instance.changing
        ? null
        : () async {
            final messenger = ScaffoldMessenger.of(context);
            onEnter();
            try {
              await DesktopMiniReaderController.instance.enter();
              if (!DesktopMiniReaderController.instance.hotkeyAvailable &&
                  DesktopShortcuts.instance
                      .keys(DesktopCommand.miniBoss)
                      .isNotEmpty &&
                  messenger.mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      '${DesktopMiniReaderController.instance.bossKeyLabel} 已被占用，已启用鼠标恢复',
                    ),
                  ),
                );
              }
            } on PlatformException catch (error) {
              if (!messenger.mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text(error.message ?? '无法进入小窗阅读')),
              );
            }
          },
  );
}

class DesktopMiniReader extends StatefulWidget {
  const DesktopMiniReader({
    super.key,
    required this.title,
    required this.progress,
    required this.fontSize,
    required this.onFontSizeChanged,
    required this.onTurnPage,
    required this.onDirectory,
    required this.child,
  });

  final String title;
  final double progress;
  final double fontSize;
  final ValueChanged<double> onFontSizeChanged;
  final Future<void> Function(int) onTurnPage;
  final Future<void> Function() onDirectory;
  final Widget child;

  @override
  State<DesktopMiniReader> createState() => _DesktopMiniReaderState();
}

class _DesktopMiniReaderState extends State<DesktopMiniReader> {
  final _controller = DesktopMiniReaderController.instance;
  bool _settingsOpen = false;

  @override
  void dispose() {
    if (_controller.active) unawaited(_controller.setMenuOpen(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = _controller.lightText
        ? const Color(0xFFD2D2D2)
        : const Color(0xFF292724);
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Theme.of(context).colorScheme.primary,
          brightness: _controller.lightText
              ? Brightness.dark
              : Brightness.light,
        ),
        iconTheme: IconThemeData(color: ink, size: 18),
        textTheme: Theme.of(
          context,
        ).textTheme.apply(bodyColor: ink, displayColor: ink),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: ink,
            minimumSize: const Size(32, 32),
            maximumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      child: DesktopShortcutScope(
        group: DesktopShortcutGroup.mini,
        actions: {
          DesktopCommand.miniExit: () => _run(_controller.leave()),
          DesktopCommand.miniSettings: _toggleSettings,
        },
        child: Scaffold(
          key: const ValueKey('desktop-mini-reader'),
          backgroundColor: (_controller.lightText ? Colors.black : Colors.white)
              .withValues(alpha: _controller.backgroundOpacity),
          body: DragToResizeArea(
            resizeEdgeSize: 5,
            child: Stack(
              children: [
                Column(
                  children: [
                    _hoverControls(_header()),
                    Expanded(
                      child: ReaderInkScope(
                        ink: _controller.ink,
                        child: widget.child,
                      ),
                    ),
                    _hoverControls(_footer(ink)),
                  ],
                ),
                if (_settingsOpen)
                  Positioned(
                    top: 40,
                    left: 8,
                    right: 8,
                    bottom: 44,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: MiniReaderSettingsPanel(
                        fontSize: widget.fontSize,
                        onFontSizeChanged: widget.onFontSizeChanged,
                        onClose: _toggleSettings,
                        onOpenShortcuts: () => _run(_openShortcutSettings()),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hoverControls(Widget child) {
    final visible = _controller.hovered || _settingsOpen;
    return SizedBox(
      height: 40,
      child: IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: HomeMotion.duration(context, 120),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      children: [
        Expanded(
          child: DragToMoveArea(
            child: Tooltip(
              message: widget.title,
              child: SizedBox(
                height: 40,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: _controller.boundWindow == null ? '窗口置顶' : '正在跟随绑定窗口',
          isSelected: _controller.boundWindow == null && _controller.pinned,
          icon: const Icon(LucideIcons.pin_off),
          selectedIcon: const Icon(LucideIcons.pin),
          onPressed: _controller.boundWindow == null
              ? () => _run(_controller.setPinned(!_controller.pinned))
              : null,
        ),
        IconButton(
          tooltip: '鼠标移开时隐身',
          isSelected: _controller.hoverHide,
          icon: const Icon(LucideIcons.eye),
          selectedIcon: const Icon(LucideIcons.eye_off),
          onPressed: () =>
              _run(_controller.setHoverHide(!_controller.hoverHide)),
        ),
        IconButton(
          tooltip: '小窗设置',
          isSelected: _settingsOpen,
          icon: const Icon(LucideIcons.sliders_horizontal),
          onPressed: _toggleSettings,
        ),
        IconButton(
          key: const ValueKey('mini-reader-exit'),
          tooltip: '恢复正常阅读',
          icon: const Icon(LucideIcons.maximize_2),
          onPressed: _controller.changing
              ? null
              : () => _run(_controller.leave()),
        ),
      ],
    ),
  );

  Widget _footer(Color ink) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      children: [
        IconButton(
          tooltip: '上一页',
          icon: const Icon(LucideIcons.chevron_left),
          onPressed: () => _run(widget.onTurnPage(-1)),
        ),
        IconButton(
          tooltip: '目录',
          icon: const Icon(LucideIcons.list),
          onPressed: () => _run(_openDirectory()),
        ),
        Expanded(
          child: Text(
            '${(widget.progress * 100).toStringAsFixed(1)}%',
            textAlign: TextAlign.center,
            style: TextStyle(color: ink, fontSize: 11),
          ),
        ),
        IconButton(
          tooltip: _controller.hotkeyAvailable
              ? '老板键：隐藏／显示（${_controller.bossKeyLabel}）'
              : '临时隐藏（鼠标移出后移回显示）',
          icon: const Icon(LucideIcons.minimize_2),
          onPressed: () => _run(_controller.toggleHidden()),
        ),
        IconButton(
          tooltip: '下一页',
          icon: const Icon(LucideIcons.chevron_right),
          onPressed: () => _run(widget.onTurnPage(1)),
        ),
      ],
    ),
  );

  void _toggleSettings() {
    setState(() => _settingsOpen = !_settingsOpen);
    _run(_controller.setMenuOpen(_settingsOpen));
  }

  Future<void> _openShortcutSettings() async {
    await _controller.setMenuOpen(true);
    try {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const DesktopShortcutsPage(
            initialGroup: DesktopShortcutGroup.mini,
          ),
        ),
      );
    } finally {
      if (_controller.active) await _controller.setMenuOpen(_settingsOpen);
    }
  }

  Future<void> _openDirectory() async {
    await _controller.setMenuOpen(true);
    try {
      await widget.onDirectory();
    } finally {
      if (_controller.active) await _controller.setMenuOpen(_settingsOpen);
    }
  }

  void _run(Future<void> action) async {
    try {
      await action;
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? '小窗设置失败')));
    }
  }
}
