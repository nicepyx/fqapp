import 'package:flutter/material.dart';

import '../services/desktop_mini_reader.dart';
import '../services/desktop_video_controller.dart';
import 'desktop_video_tools_host.dart';

Future<void> openVideoMomentEditor(
  BuildContext context, {
  bool card = false,
}) async {
  final tools = DesktopVideoToolsScope.of(context);
  if (!tools.enabled) return;
  final player = tools.player!;
  final resume = player.playWhenReady;
  await tools.endBoost();
  await player.pause();
  if (!context.mounted) return;
  final mini = DesktopMiniReaderController.instance;
  final wasMenuOpen = mini.menuOpen;
  if (mini.videoActive) await mini.setMenuOpen(true);
  try {
    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VideoMomentEditor(tools: tools, card: card),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('已保存片段')));
    }
  } finally {
    if (mini.videoActive) await mini.setMenuOpen(wasMenuOpen);
    if (resume && player.isCreated && !mini.hidden) await player.play();
  }
}

class VideoMomentEditor extends StatefulWidget {
  const VideoMomentEditor({super.key, required this.tools, this.card = false});
  final DesktopVideoController tools;
  final bool card;
  @override
  State<VideoMomentEditor> createState() => _VideoMomentEditorState();
}

class _VideoMomentEditorState extends State<VideoMomentEditor> {
  final _note = TextEditingController();
  late final _caption = TextEditingController(
    text: widget.tools
        .cuesAt(widget.tools.player!.position)
        .map((cue) => cue.data)
        .join('\n'),
  );
  late bool _card = widget.card;
  int _seconds = 10;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.tools.saveMoment(
        note: _note.text.trim(),
        caption: _caption.text.trim(),
        card: _card,
        audioSeconds: _seconds,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '片段保存失败，请检查片源后重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(
        _card ? '图文声音收藏卡' : '片段书签',
        style: const TextStyle(fontSize: 18),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.tools.episodeTitle} · ${videoTime(widget.tools.player!.position)}',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                enabled: !_saving,
                maxLines: 2,
                decoration: const InputDecoration(labelText: '备注'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _caption,
                enabled: !_saving,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '台词'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('保存画面与声音'),
                value: _card,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _card = value),
              ),
              if (_card)
                DropdownButtonFormField<int>(
                  initialValue: _seconds,
                  decoration: const InputDecoration(labelText: '声音片段时长'),
                  items: [
                    for (final seconds in [5, 10, 15, 30])
                      DropdownMenuItem(
                        value: seconds,
                        child: Text('$seconds 秒'),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _seconds = value!),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中…' : '保存'),
        ),
      ],
    ),
  );
}
