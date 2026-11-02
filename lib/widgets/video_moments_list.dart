import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:media_kit/media_kit.dart';

import '../services/desktop_video_controller.dart';
import '../services/video_moments_store.dart';

class VideoMomentsList extends StatefulWidget {
  const VideoMomentsList({
    super.key,
    required this.tools,
    required this.onOpen,
  });
  final DesktopVideoController tools;
  final Future<void> Function(VideoMoment) onOpen;
  @override
  State<VideoMomentsList> createState() => _VideoMomentsListState();
}

class _VideoMomentsListState extends State<VideoMomentsList> {
  late Future<List<VideoMoment>> _items = widget.tools.store.load();
  final _search = TextEditingController();
  Player? _audio;
  String? _playing;
  StreamSubscription<bool>? _completed;
  String _query = '';
  bool _exporting = false;

  @override
  void dispose() {
    _completed?.cancel();
    unawaited(_audio?.dispose());
    _search.dispose();
    super.dispose();
  }

  Future<void> _play(VideoMoment moment) async {
    if (_playing == moment.id) {
      await _audio!.pause();
      setState(() => _playing = null);
      return;
    }
    final file = await widget.tools.store.mediaFile(moment, 'wav');
    final audio = _audio ??= Player();
    _completed ??= audio.stream.completed.listen((done) {
      if (done && mounted) setState(() => _playing = null);
    });
    await audio.open(Media(file.path));
    if (mounted) setState(() => _playing = moment.id);
  }

  Future<void> _export(VideoMoment moment) async {
    final location = await getSaveLocation(
      suggestedName: '片段-${moment.id}.zip',
      acceptedTypeGroups: [
        const XTypeGroup(label: '片段收藏', extensions: ['zip']),
      ],
    );
    if (location == null || !mounted) return;
    setState(() => _exporting = true);
    try {
      final archive = Archive()
        ..addFile(ArchiveFile.string('片段.json', jsonEncode(moment.toJson())));
      final store = widget.tools.store;
      for (final extension in [
        if (moment.hasImage) 'jpg',
        if (moment.hasAudio) 'wav',
      ]) {
        archive.addFile(
          ArchiveFile.bytes(
            '片段.$extension',
            await (await store.mediaFile(moment, extension)).readAsBytes(),
          ),
        );
      }
      await File(location.path).writeAsBytes(ZipEncoder().encode(archive));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _remove(VideoMoment moment) async {
    if (_playing == moment.id) {
      await _audio?.pause();
      _playing = null;
    }
    await widget.tools.store.remove(moment);
    if (mounted) setState(() => _items = widget.tools.store.load());
  }

  void _run(Future<void> action) async {
    try {
      await action;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('片段操作失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _search,
          decoration: const InputDecoration(
            prefixIcon: Icon(LucideIcons.search),
            labelText: '搜索剧名、台词或备注',
            isDense: true,
          ),
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<VideoMoment>>(
          future: _items,
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('收藏读取失败'));
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data!
                .where(
                  (item) =>
                      widget.tools.playlistIds.contains(item.episodeId) &&
                      '${item.seriesTitle} ${item.caption} ${item.note}'
                          .toLowerCase()
                          .contains(_query),
                )
                .toList();
            if (items.isEmpty) return const Center(child: Text('暂无片段收藏'));
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => _moment(items[index]),
            );
          },
        ),
      ),
    ],
  );

  Widget _moment(VideoMoment item) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${item.seriesTitle} · ${item.episodeTitle}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (item.hasImage)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FutureBuilder<File>(
              future: widget.tools.store.mediaFile(item, 'jpg'),
              builder: (context, snapshot) => snapshot.hasData
                  ? SizedBox(
                      height: 120,
                      child: Image.file(snapshot.data!, fit: BoxFit.contain),
                    )
                  : const SizedBox(height: 120),
            ),
          ),
        if (item.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SelectableText(item.caption),
          ),
        if (item.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(item.note),
          ),
        _actions(item),
      ],
    ),
  );

  Widget _actions(VideoMoment item) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      TextButton.icon(
        onPressed: () => _run(widget.onOpen(item)),
        icon: const Icon(LucideIcons.corner_up_left, size: 16),
        label: Text(videoTime(Duration(milliseconds: item.positionMs))),
      ),
      if (item.hasAudio)
        IconButton(
          tooltip: _playing == item.id ? '暂停声音片段' : '播放声音片段',
          icon: Icon(
            _playing == item.id ? LucideIcons.pause : LucideIcons.volume_2,
          ),
          onPressed: () => _run(_play(item)),
        ),
      IconButton(
        tooltip: '导出片段',
        icon: const Icon(LucideIcons.download),
        onPressed: _exporting ? null : () => _run(_export(item)),
      ),
      IconButton(
        tooltip: '删除片段',
        icon: const Icon(LucideIcons.trash),
        onPressed: () => _run(_remove(item)),
      ),
    ],
  );
}
