import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../services/desktop_video_controller.dart';
import '../services/video_moments_store.dart';
import 'desktop_video_tools_host.dart';
import 'video_moment_editor.dart';
import 'video_moments_list.dart';

class DesktopVideoToolsPanel extends StatefulWidget {
  const DesktopVideoToolsPanel({super.key, required this.onSeek});
  final Future<void> Function(Duration) onSeek;
  @override
  State<DesktopVideoToolsPanel> createState() => _DesktopVideoToolsPanelState();
}

class _DesktopVideoToolsPanelState extends State<DesktopVideoToolsPanel> {
  final _search = TextEditingController();
  String _query = '';
  String? _error;
  bool _busy = false;
  bool _started = false;
  int _momentsRevision = 0;
  late DesktopVideoController _tools;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tools = DesktopVideoToolsScope.of(context);
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _tools.loadSubtitles(),
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _error = '操作失败，请检查文件或片源后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: '字幕', extensions: ['srt', 'vtt']),
      ],
    );
    if (file != null) await _tools.importSubtitles(await file.readAsString());
  }

  Future<void> _openMoment(VideoMoment moment) async {
    final position = Duration(milliseconds: moment.positionMs);
    // The active playlist owns loading and resuming the selected episode.
    final open = DesktopVideoToolsScope.navigationOf(context);
    await open(moment.episodeId, position);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffef5038),
        brightness: Theme.of(context).brightness,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    child: Dialog(
      insetPadding: const EdgeInsets.all(8),
      child: SizedBox(
        width: 740,
        height: 560,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(16) * 1.4 + 24,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '播放工具',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭播放工具',
                      icon: const Icon(LucideIcons.x, size: 18),
                      onPressed: _busy ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              TabBar(
                onTap: (index) {
                  if (index == 1) unawaited(_tools.loadSubtitles());
                  if (index == 2) setState(() => _momentsRevision++);
                },
                tabs: const [
                  Tab(text: '播放'),
                  Tab(text: '字幕'),
                  Tab(text: '收藏'),
                ],
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              Expanded(
                child: TabBarView(
                  children: [
                    _playback(),
                    _subtitles(),
                    VideoMomentsList(
                      key: ValueKey(_momentsRevision),
                      tools: _tools,
                      onOpen: _openMoment,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _playback() => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('夜间声音模式'),
        value: _tools.night,
        onChanged: !_tools.enabled || _busy
            ? null
            : (value) => _run(() => _tools.setNight(value)),
      ),
      DropdownButtonFormField<double>(
        initialValue: _tools.boostRate,
        decoration: const InputDecoration(labelText: '临时倍速'),
        items: [
          for (final rate in [1.5, 2.0, 2.5, 3.0])
            DropdownMenuItem(value: rate, child: Text('${rate}x')),
        ],
        onChanged: _busy
            ? null
            : (value) => _run(() => _tools.setBoostRate(value!)),
      ),
      const SizedBox(height: 16),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(LucideIcons.bookmark_plus),
        title: const Text('添加片段书签'),
        enabled: _tools.enabled && !_busy,
        onTap: () => _run(() async {
          await openVideoMomentEditor(context);
          if (mounted) setState(() => _momentsRevision++);
        }),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(LucideIcons.image_plus),
        title: const Text('制作图文声音收藏卡'),
        enabled: _tools.enabled && !_busy,
        onTap: () => _run(() async {
          await openVideoMomentEditor(context, card: true);
          if (mounted) setState(() => _momentsRevision++);
        }),
      ),
    ],
  );

  Widget _subtitles() => ListView(
    children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: '导入 SRT/VTT 字幕',
              icon: const Icon(LucideIcons.file_up),
              onPressed: _busy ? null : () => _run(_import),
            ),
            IconButton(
              tooltip: '重试读取字幕',
              icon: const Icon(LucideIcons.refresh_cw),
              onPressed: _tools.subtitlesLoading
                  ? null
                  : () => _tools.loadSubtitles(),
            ),
            IconButton(
              tooltip: _tools.subtitleVisible ? '隐藏字幕' : '显示字幕',
              icon: Icon(
                _tools.subtitleVisible
                    ? LucideIcons.captions
                    : LucideIcons.captions_off,
              ),
              onPressed: () =>
                  _tools.setSubtitleVisible(!_tools.subtitleVisible),
            ),
            IconButton(
              tooltip: '字幕提前 0.5 秒',
              icon: const Icon(LucideIcons.minus),
              onPressed: () =>
                  _tools.setSubtitleOffset(_tools.subtitleOffsetMs - 500),
            ),
            Text('${(_tools.subtitleOffsetMs / 1000).toStringAsFixed(1)}s'),
            IconButton(
              tooltip: '字幕延后 0.5 秒',
              icon: const Icon(LucideIcons.plus),
              onPressed: () =>
                  _tools.setSubtitleOffset(_tools.subtitleOffsetMs + 500),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: _search,
          decoration: const InputDecoration(
            labelText: '搜索台词',
            isDense: true,
            prefixIcon: Icon(LucideIcons.search),
          ),
          onChanged: (text) =>
              setState(() => _query = text.trim().toLowerCase()),
        ),
      ),
      if (_tools.subtitlesLoading)
        const Center(child: CircularProgressIndicator())
      else if (_tools.subtitles.isEmpty)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_tools.subtitleError ?? '当前片源没有独立字幕，可导入 SRT/VTT'),
        )
      else
        ..._subtitleRows(),
    ],
  );

  Iterable<Widget> _subtitleRows() sync* {
    for (final cue in _tools.subtitles.where(
      (cue) => cue.data.toLowerCase().contains(_query),
    )) {
      yield ListTile(
        title: Text(cue.data),
        leading: Text(videoTime(cue.start)),
        onTap: () => _run(() async {
          await widget.onSeek(
            Duration(
              milliseconds: (cue.start.inMilliseconds + _tools.subtitleOffsetMs)
                  .clamp(0, _tools.player!.duration.inMilliseconds),
            ),
          );
          if (mounted) Navigator.pop(context);
        }),
      );
    }
  }
}
