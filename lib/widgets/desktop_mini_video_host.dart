import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/desktop_mini_reader.dart';
import '../services/desktop_platform.dart';
import '../services/desktop_shortcuts.dart';
import '../services/native_player.dart';
import 'desktop_mini_video.dart';
import 'video_player_chrome.dart';

class DesktopMiniVideoHost extends StatefulWidget {
  const DesktopMiniVideoHost({
    super.key,
    required this.configuration,
    required this.normalBuilder,
    required this.onToggle,
    required this.onSeek,
    required this.onRateSelected,
    required this.onVolumeSelected,
    required this.position,
    required this.rate,
    required this.volume,
  });

  final VideoPlayerChrome configuration;
  final Widget Function(VoidCallback onEnter) normalBuilder;
  final Future<void> Function() onToggle;
  final Future<void> Function(Duration) onSeek;
  final Future<void> Function(double) onRateSelected, onVolumeSelected;
  final ValueNotifier<Duration> position;
  final double rate, volume;

  @override
  State<DesktopMiniVideoHost> createState() => _DesktopMiniVideoHostState();
}

class _DesktopMiniVideoHostState extends State<DesktopMiniVideoHost> {
  final _mini = DesktopMiniReaderController.instance;
  final _owner = Object();
  NativePlayer? _pausedPlayer;
  bool _wasMini = false;
  bool get _isMini => _mini.videoActive && identical(_mini.videoOwner, _owner);

  @override
  void initState() {
    super.initState();
    _mini.addListener(_modeChanged);
  }

  @override
  void didUpdateWidget(covariant DesktopMiniVideoHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isMini) _syncPlayback();
  }

  @override
  void dispose() {
    _mini.removeListener(_modeChanged);
    if (_isMini) unawaited(_mini.leave());
    super.dispose();
  }

  void _modeChanged() {
    if (_isMini || _wasMini) _syncPlayback();
    _wasMini = _isMini;
    setState(() {});
  }

  // Native visibility covers hover hiding, the boss key and target minimization.
  void _syncPlayback() {
    final player = widget.configuration.player;
    if (_isMini && _mini.hidden) {
      if (player?.isCreated == true && player!.playWhenReady) {
        _pausedPlayer = player;
        unawaited(player.pause().catchError(widget.configuration.onError));
      }
    } else {
      final resume = _pausedPlayer;
      _pausedPlayer = null;
      if (resume != null && identical(resume, player) && resume.isCreated) {
        unawaited(resume.play().catchError(widget.configuration.onError));
      }
    }
  }

  Future<void> _enter() async {
    if (_mini.active || _mini.changing) return;
    try {
      if (DesktopPlatform.fullscreen.value) {
        await DesktopPlatform.instance.setFullscreen(false);
      }
      final player = widget.configuration.player;
      await _mini.enter(
        videoOwner: _owner,
        videoAspectRatio: player != null && player.videoHeight > 0
            ? player.videoWidth / player.videoHeight
            : 9 / 16,
      );
      if (!_mini.hotkeyAvailable &&
          DesktopShortcuts.instance.keys(DesktopCommand.miniBoss).isNotEmpty &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_mini.bossKeyLabel} 已被占用，已启用鼠标恢复')),
        );
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? '无法进入视频小窗')));
    }
  }

  @override
  Widget build(BuildContext context) => _isMini
      ? DesktopMiniVideo(
          configuration: widget.configuration,
          onToggle: widget.onToggle,
          onSeek: widget.onSeek,
          onRateSelected: widget.onRateSelected,
          onVolumeSelected: widget.onVolumeSelected,
          position: widget.position,
          rate: widget.rate,
          volume: widget.volume,
        )
      : widget.normalBuilder(() => unawaited(_enter()));
}
