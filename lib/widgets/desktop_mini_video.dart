import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:window_manager/window_manager.dart';

import '../pages/desktop_shortcuts_page.dart';
import '../services/desktop_mini_reader.dart';
import '../services/desktop_platform.dart';
import '../services/desktop_shortcuts.dart';
import 'player/playlet_danmaku_layer.dart';
import 'reader/mini_reader_settings_panel.dart';
import 'video_player_chrome.dart';
import 'desktop_mini_video_catalog.dart';
import 'desktop_video_tools_host.dart';
import 'desktop_video_seekbar.dart';

class DesktopMiniVideo extends StatefulWidget {
  const DesktopMiniVideo({
    super.key,
    required this.configuration,
    required this.onToggle,
    required this.onSeek,
    required this.onRateSelected,
    required this.onVolumeSelected,
    required this.position,
    required this.rate,
    required this.volume,
  });

  final VideoPlayerChrome configuration;
  final Future<void> Function() onToggle;
  final Future<void> Function(Duration) onSeek;
  final Future<void> Function(double) onRateSelected, onVolumeSelected;
  final ValueNotifier<Duration> position;
  final double rate, volume;

  @override
  State<DesktopMiniVideo> createState() => _DesktopMiniVideoState();
}

class _DesktopMiniVideoState extends State<DesktopMiniVideo> {
  final _mini = DesktopMiniReaderController.instance;
  final _focus = FocusNode();
  bool _settings = false, _catalog = false;
  double? _scrub;
  DateTime? _lastWheel;
  VideoPlayerChrome get c => widget.configuration;
  bool get _ready => c.enabled && c.player?.isCreated == true;
  bool get _panelOpen => _settings || _catalog;

  @override
  void dispose() {
    _focus.dispose();
    if (_mini.videoActive) unawaited(_mini.setMenuOpen(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData.dark(useMaterial3: true).copyWith(
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          maximumSize: const Size(32, 32),
          padding: EdgeInsets.zero,
          foregroundColor: Colors.white,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    ),
    child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _run(_mini.leave());
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _key,
        child: Scaffold(
          key: const ValueKey('desktop-mini-video'),
          backgroundColor: Colors.transparent,
          body: DragToResizeArea(resizeEdgeSize: 5, child: _body()),
        ),
      ),
    ),
  );

  Widget _body() => Stack(
    fit: StackFit.expand,
    children: [
      Opacity(
        opacity: _mini.videoOpacity,
        child: ColoredBox(
          color: Colors.black,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _focus.requestFocus();
              if (_ready) _run(widget.onToggle());
            },
            onDoubleTap: () => _run(_mini.leave()),
            child: Listener(
              onPointerSignal: _wheel,
              child: Center(
                child: AspectRatio(
                  aspectRatio:
                      c.player != null &&
                          c.player!.videoHeight > 0 &&
                          c.player!.videoWidth > 0
                      ? c.player!.videoWidth / c.player!.videoHeight
                      : 9 / 16,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DesktopVideoSurface(subtitleBottom: 100, child: c.child),
                      if (c.danmakuEnabled)
                        IgnorePointer(
                          child: PlayletDanmakuLayer(
                            entries: c.danmaku,
                            position: widget.position,
                            playing: c.playing,
                            enabled: true,
                            settings: c.danmakuSettings,
                            rate: widget.rate,
                            landscape: false,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(top: 0, left: 0, right: 0, child: _controls(_header())),
      Positioned(bottom: 0, left: 0, right: 0, child: _controls(_transport())),
      if (_panelOpen)
        Positioned(
          top: _settings ? 8 : 40,
          bottom: _settings ? 8 : 92,
          left: 6,
          right: 6,
          child: _settings
              ? MiniReaderSettingsPanel(
                  video: true,
                  onClose: () => _panel(),
                  onOpenShortcuts: () => _run(_shortcuts()),
                )
              : DesktopMiniVideoCatalog(
                  configuration: c,
                  onClose: () => _panel(),
                  onSelect: (index) {
                    _panel();
                    _select(index);
                  },
                ),
        ),
    ],
  );

  Widget _controls(Widget child) {
    final visible = _mini.hovered || _panelOpen || !c.playing;
    return IgnorePointer(
      ignoring: !visible,
      child: Opacity(
        opacity: visible ? 1 : 0,
        child: ColoredBox(color: const Color(0xcc101114), child: child),
      ),
    );
  }

  Widget _header() => SizedBox(
    height: 40,
    child: Row(
      children: [
        const SizedBox(width: 8),
        Expanded(
          child: DragToMoveArea(
            child: SizedBox(
              height: 40,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Tooltip(
                  message: c.title,
                  child: Text(
                    c.title,
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
          tooltip: _mini.boundWindow == null ? '窗口置顶' : '正在跟随绑定窗口',
          icon: Icon(
            _mini.pinned ? LucideIcons.pin : LucideIcons.pin_off,
            size: 17,
          ),
          onPressed: _mini.boundWindow == null
              ? () => _run(_mini.setPinned(!_mini.pinned))
              : null,
        ),
        IconButton(
          tooltip: '鼠标移开时隐身',
          icon: Icon(
            _mini.hoverHide ? LucideIcons.eye_off : LucideIcons.eye,
            size: 17,
          ),
          onPressed: () => _run(_mini.setHoverHide(!_mini.hoverHide)),
        ),
        IconButton(
          tooltip: '小窗设置',
          icon: const Icon(LucideIcons.sliders_horizontal, size: 17),
          onPressed: () => _panel(settings: !_settings),
        ),
        DesktopVideoToolsButton(onSeek: widget.onSeek),
        IconButton(
          key: const ValueKey('mini-video-exit'),
          tooltip: '恢复正常播放',
          icon: const Icon(LucideIcons.maximize_2, size: 17),
          onPressed: _mini.changing ? null : () => _run(_mini.leave()),
        ),
        const SizedBox(width: 4),
      ],
    ),
  );

  Widget _transport() => ValueListenableBuilder<Duration>(
    valueListenable: widget.position,
    builder: (context, position, _) {
      final end = math.max(1, c.duration.inMilliseconds).toDouble();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  Text(_time(position), style: const TextStyle(fontSize: 10)),
                  Expanded(
                    child: DesktopVideoSeekbar(
                      sliderKey: const ValueKey('mini-video-progress'),
                      value: (_scrub ?? position.inMilliseconds.toDouble())
                          .clamp(0, end),
                      max: end,
                      onChanged: _ready
                          ? (v) => setState(() => _scrub = v)
                          : null,
                      onChangeEnd: (v) {
                        _run(widget.onSeek(Duration(milliseconds: v.round())));
                        setState(() => _scrub = null);
                      },
                    ),
                  ),
                  Text(_time(c.duration), style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: '上一集',
                    icon: const Icon(LucideIcons.skip_back, size: 18),
                    onPressed: c.currentIndex > 0
                        ? () => _select(c.currentIndex - 1)
                        : null,
                  ),
                  IconButton(
                    tooltip: '快退 10 秒',
                    icon: const Icon(LucideIcons.rotate_ccw, size: 18),
                    onPressed: _ready
                        ? () => _run(
                            widget.onSeek(
                              position - const Duration(seconds: 10),
                            ),
                          )
                        : null,
                  ),
                  IconButton(
                    tooltip: '播放 / 暂停',
                    icon: Icon(
                      c.playing ? LucideIcons.pause : LucideIcons.play,
                      size: 22,
                    ),
                    onPressed: _ready ? () => _run(widget.onToggle()) : null,
                  ),
                  IconButton(
                    tooltip: '下一集',
                    icon: const Icon(LucideIcons.skip_forward, size: 18),
                    onPressed: c.currentIndex + 1 < c.episodes.length
                        ? () => _select(c.currentIndex + 1)
                        : null,
                  ),
                  IconButton(
                    tooltip: '选集',
                    icon: const Icon(LucideIcons.list_video, size: 18),
                    onPressed: () => _panel(catalog: !_catalog),
                  ),
                  IconButton(
                    tooltip: widget.volume == 0 ? '取消静音' : '静音',
                    icon: Icon(
                      widget.volume == 0
                          ? LucideIcons.volume_x
                          : LucideIcons.volume_2,
                      size: 18,
                    ),
                    onPressed: () => _run(
                      widget.onVolumeSelected(widget.volume == 0 ? 1 : 0),
                    ),
                  ),
                  PopupMenuButton<double>(
                    tooltip: '播放速度',
                    initialValue: widget.rate,
                    constraints: const BoxConstraints(minWidth: 88),
                    padding: EdgeInsets.zero,
                    icon: const Icon(LucideIcons.gauge, size: 18),
                    onOpened: () => _run(_mini.setMenuOpen(true)),
                    onCanceled: () => _run(_mini.setMenuOpen(_panelOpen)),
                    onSelected: (rate) {
                      _run(widget.onRateSelected(rate));
                      _run(_mini.setMenuOpen(_panelOpen));
                    },
                    itemBuilder: (_) => [
                      for (final rate in [0.75, 1.0, 1.25, 1.5, 2.0, 3.0])
                        CheckedPopupMenuItem(
                          value: rate,
                          checked: rate == widget.rate,
                          child: Text('${rate}x'),
                        ),
                    ],
                  ),
                  IconButton(
                    tooltip: '临时隐藏',
                    icon: const Icon(LucideIcons.minimize_2, size: 18),
                    onPressed: () => _run(_mini.toggleHidden()),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  void _panel({bool settings = false, bool catalog = false}) {
    setState(() {
      _settings = settings;
      _catalog = catalog;
    });
    _run(_mini.setMenuOpen(_panelOpen));
    if (!_panelOpen) _focus.requestFocus();
  }

  void _select(int index) => _run(c.onSelectEpisode(index));

  void _wheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        _panelOpen ||
        c.interactionBlocked ||
        event.scrollDelta.dy == 0) {
      return;
    }
    final now = DateTime.now();
    if (_lastWheel != null &&
        now.difference(_lastWheel!) < const Duration(milliseconds: 600)) {
      return;
    }
    final index = c.currentIndex + (event.scrollDelta.dy > 0 ? 1 : -1);
    if (index < 0 || index >= c.episodes.length) return;
    _lastWheel = now;
    _focus.requestFocus();
    _select(index);
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        DesktopShortcuts.instance.recording ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent == false ||
        c.interactionBlocked ||
        FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<EditableText>() !=
            null) {
      return KeyEventResult.ignored;
    }
    if (_panelOpen) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _panel();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final shortcuts = DesktopShortcuts.instance;
    final mini = shortcuts.match(DesktopShortcutGroup.mini, event);
    final video = shortcuts.match(DesktopShortcutGroup.video, event);
    if (mini == DesktopCommand.miniExit || video == DesktopCommand.videoMini) {
      _run(_mini.leave());
    } else if (mini == DesktopCommand.miniSettings) {
      _panel(settings: true);
    } else if (video == DesktopCommand.videoPlay && _ready) {
      _run(widget.onToggle());
    } else if ((video == DesktopCommand.videoBack ||
            video == DesktopCommand.videoForward) &&
        _ready) {
      _run(
        widget.onSeek(
          widget.position.value +
              Duration(seconds: video == DesktopCommand.videoBack ? -10 : 10),
        ),
      );
    } else if (video == DesktopCommand.videoVolumeUp ||
        video == DesktopCommand.videoVolumeDown) {
      _run(
        widget.onVolumeSelected(
          (widget.volume + (video == DesktopCommand.videoVolumeUp ? .05 : -.05))
              .clamp(0, 1),
        ),
      );
    } else if (video == DesktopCommand.videoFullscreen) {
      _run(_fullscreen());
    } else if (video == DesktopCommand.videoExitFullscreen) {
      _run(_mini.leave());
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Future<void> _fullscreen() async {
    await _mini.leave();
    await DesktopPlatform.instance.setFullscreen(true);
  }

  Future<void> _shortcuts() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DesktopShortcutsPage(
          initialGroup: DesktopShortcutGroup.video,
        ),
      ),
    );
    if (_mini.videoActive) await _mini.setMenuOpen(_panelOpen);
  }

  void _run(Future<void> action) async {
    try {
      await action;
    } catch (error) {
      c.onError(error);
    }
  }

  String _time(Duration duration) {
    final seconds = math.max(0, duration.inSeconds);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
