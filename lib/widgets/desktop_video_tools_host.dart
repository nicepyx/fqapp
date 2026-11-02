import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../services/desktop_mini_reader.dart';
import '../services/desktop_shortcuts.dart';
import '../services/desktop_video_controller.dart';
import 'desktop_video_tools_panel.dart';
import 'video_moment_editor.dart';
import 'video_player_chrome.dart';

class DesktopVideoToolsScope extends InheritedNotifier<DesktopVideoController> {
  const DesktopVideoToolsScope({
    super.key,
    required DesktopVideoController controller,
    required super.child,
    this.onOpenMoment,
  }) : super(notifier: controller);
  final Future<void> Function(String episodeId, Duration position)?
  onOpenMoment;
  static DesktopVideoController of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DesktopVideoToolsScope>()!
      .notifier!;
  static Future<void> Function(String, Duration) navigationOf(
    BuildContext context,
  ) => context
      .dependOnInheritedWidgetOfExactType<DesktopVideoToolsScope>()!
      .onOpenMoment!;
}

class DesktopVideoToolsHost extends StatefulWidget {
  const DesktopVideoToolsHost({
    super.key,
    required this.configuration,
    required this.rate,
    required this.onSeek,
    required this.child,
  });
  final VideoPlayerChrome configuration;
  final double rate;
  final Future<void> Function(Duration) onSeek;
  final Widget child;
  @override
  State<DesktopVideoToolsHost> createState() => _DesktopVideoToolsHostState();
}

class _DesktopVideoToolsHostState extends State<DesktopVideoToolsHost>
    with WidgetsBindingObserver {
  late final _controller = DesktopVideoController(onError: _error);
  LogicalKeyboardKey? _heldKey;
  VideoPlayerChrome get c => widget.configuration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DesktopMiniReaderController.instance.addListener(_visibilityChanged);
    _update();
    unawaited(_controller.loadPreferences().catchError(_error));
  }

  void _update() {
    _controller.playlistIds = c.episodes
        .map((episode) => episode.itemId)
        .toSet();
    final episode = c.episodes.isEmpty ? null : c.episodes[c.currentIndex];
    _controller.update(
      player: c.player,
      episodeId: episode?.itemId ?? '',
      seriesTitle: c.seriesTitle.isEmpty ? c.title : c.seriesTitle,
      episodeTitle: episode?.title ?? c.title,
      enabled: c.enabled && c.player?.isCreated == true,
      rate: widget.rate,
    );
  }

  @override
  void didUpdateWidget(covariant DesktopVideoToolsHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _heldKey = null;
      unawaited(_controller.endBoost().catchError(_error));
    }
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('播放工具操作失败，请重试')));
  }

  void _visibilityChanged() {
    if (DesktopMiniReaderController.instance.hidden && _controller.boosting) {
      _heldKey = null;
      unawaited(_controller.endBoost().catchError(_error));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DesktopMiniReaderController.instance.removeListener(_visibilityChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DesktopVideoToolsScope(
    controller: _controller,
    onOpenMoment: (episodeId, position) async {
      final index = c.episodes.indexWhere(
        (episode) => episode.itemId == episodeId,
      );
      if (index != c.currentIndex) {
        await c.onSelectEpisode(index);
        await WidgetsBinding.instance.endOfFrame;
      }
      await widget.onSeek(position);
    },
    child: Builder(
      builder: (context) => Focus(
        onFocusChange: (focused) {
          if (!focused) {
            _heldKey = null;
            unawaited(_controller.endBoost().catchError(_error));
          }
        },
        onKeyEvent: (_, event) {
          if (event is KeyUpEvent && event.logicalKey == _heldKey) {
            _heldKey = null;
            unawaited(_controller.endBoost().catchError(_error));
            return KeyEventResult.handled;
          }
          if (event is! KeyDownEvent ||
              c.interactionBlocked ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.inactive ||
              ModalRoute.of(context)?.isCurrent == false ||
              FocusManager.instance.primaryFocus?.context
                      ?.findAncestorWidgetOfExactType<EditableText>() !=
                  null) {
            return KeyEventResult.ignored;
          }
          final command = DesktopShortcuts.instance.match(
            DesktopShortcutGroup.video,
            event,
          );
          if (command == DesktopCommand.videoBoost) {
            _heldKey = event.logicalKey;
            unawaited(_controller.beginBoost().catchError(_error));
          } else if (command == DesktopCommand.videoBookmark) {
            unawaited(openVideoMomentEditor(context));
          } else if (command == DesktopCommand.videoTools) {
            unawaited(openDesktopVideoTools(context, onSeek: widget.onSeek));
          } else {
            return KeyEventResult.ignored;
          }
          return KeyEventResult.handled;
        },
        child: widget.child,
      ),
    ),
  );
}

class DesktopVideoToolsButton extends StatelessWidget {
  const DesktopVideoToolsButton({super.key, required this.onSeek});
  final Future<void> Function(Duration) onSeek;
  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('video-tools'),
    tooltip: '播放工具',
    icon: const Icon(LucideIcons.ellipsis, size: 20),
    onPressed: () => openDesktopVideoTools(context, onSeek: onSeek),
  );
}

class DesktopVideoSurface extends StatelessWidget {
  const DesktopVideoSurface({
    super.key,
    required this.child,
    this.subtitleBottom = 12,
  });
  final Widget child;
  final double subtitleBottom;
  @override
  Widget build(BuildContext context) {
    final tools = DesktopVideoToolsScope.of(context);
    return GestureDetector(
      key: const ValueKey('video-boost-surface'),
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (_) => unawaited(tools.run(tools.beginBoost())),
      onLongPressEnd: (_) => unawaited(tools.run(tools.endBoost())),
      onLongPressCancel: () => unawaited(tools.run(tools.endBoost())),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (tools.subtitleVisible && tools.subtitles.isNotEmpty)
            StreamBuilder<Duration>(
              stream: tools.player?.positionStream,
              initialData: tools.player?.position ?? Duration.zero,
              builder: (context, snapshot) => Positioned(
                left: 8,
                right: 8,
                bottom: subtitleBottom,
                child: IgnorePointer(
                  child: Text(
                    tools
                        .cuesAt(snapshot.data!)
                        .map((cue) => cue.data)
                        .join('\n'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.white,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black),
                        Shadow(offset: Offset(1, 1), color: Colors.black),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (tools.boosting)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: ColoredBox(
                    color: const Color(0xcc101114),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${tools.boostRate}x',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> openDesktopVideoTools(
  BuildContext context, {
  required Future<void> Function(Duration) onSeek,
}) async {
  final tools = DesktopVideoToolsScope.of(context);
  final navigation = DesktopVideoToolsScope.navigationOf(context);
  final player = tools.player;
  final resume = player?.playWhenReady == true;
  await tools.endBoost();
  if (player?.isCreated == true) await player!.pause();
  if (!context.mounted) return;
  final mini = DesktopMiniReaderController.instance;
  if (mini.videoActive) await mini.setMenuOpen(true);
  try {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => DesktopVideoToolsScope(
        controller: tools,
        onOpenMoment: navigation,
        child: DesktopVideoToolsPanel(onSeek: onSeek),
      ),
    );
  } finally {
    if (mini.videoActive) await mini.setMenuOpen(false);
    if (resume && player!.isCreated && !mini.hidden) await player.play();
  }
}
