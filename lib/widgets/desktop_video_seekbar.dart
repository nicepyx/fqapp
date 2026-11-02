import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/desktop_video_controller.dart';
import 'desktop_video_tools_host.dart';

class DesktopVideoSeekbar extends StatefulWidget {
  const DesktopVideoSeekbar({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    this.sliderKey,
  });
  final Key? sliderKey;
  final double value, max;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double> onChangeEnd;
  @override
  State<DesktopVideoSeekbar> createState() => _DesktopVideoSeekbarState();
}

class _DesktopVideoSeekbarState extends State<DesktopVideoSeekbar> {
  final _cache = <int, Uint8List>{};
  Timer? _timer;
  String _episode = '';
  int? _hoverMs;
  double _x = 0;
  bool _loading = false;
  String? _error;
  Uint8List? _image;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _hover(double x, double width, DesktopVideoController tools) {
    if (!tools.enabled || widget.onChanged == null) return;
    if (_episode != tools.episodeId) {
      _episode = tools.episodeId;
      _cache.clear();
      _image = null;
    }
    final milliseconds =
        (((x - 24) / (width - 48)).clamp(0, 1) *
                (widget.max - 100).clamp(0, widget.max))
            .round();
    final bucket = milliseconds ~/ 1000;
    setState(() {
      _x = x;
      _hoverMs = milliseconds;
      _image = _cache[bucket];
      _error = null;
    });
    _timer?.cancel();
    if (_image == null) {
      _timer = Timer(const Duration(milliseconds: 180), () => _load(tools));
    }
  }

  Future<void> _load(DesktopVideoController tools) async {
    if (_loading || _hoverMs == null) return;
    _loading = true;
    final position = _hoverMs!;
    final episode = tools.episodeId;
    try {
      final bytes = await tools.preview(Duration(milliseconds: position));
      if (!mounted || episode != tools.episodeId) return;
      if (bytes != null) {
        if (_cache.length >= 32) _cache.remove(_cache.keys.first);
        _cache[position ~/ 1000] = bytes;
      }
      if (_hoverMs != null && _hoverMs! ~/ 1000 == position ~/ 1000) {
        setState(() => _image = bytes);
      }
    } catch (_) {
      if (mounted) setState(() => _error = '预览暂不可用');
    } finally {
      _loading = false;
      if (mounted &&
          _hoverMs != null &&
          _hoverMs! ~/ 1000 != position ~/ 1000) {
        unawaited(_load(tools));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tools = DesktopVideoToolsScope.of(context);
    return LayoutBuilder(
      builder: (context, bounds) => MouseRegion(
        onHover: (event) =>
            _hover(event.localPosition.dx, bounds.maxWidth, tools),
        onExit: (_) {
          _timer?.cancel();
          setState(() => _hoverMs = null);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Slider(
              key: widget.sliderKey,
              value: widget.value,
              max: widget.max,
              label: videoTime(Duration(milliseconds: widget.value.round())),
              semanticFormatterCallback: (value) =>
                  videoTime(Duration(milliseconds: value.round())),
              onChanged: widget.onChanged,
              onChangeEnd: widget.onChangeEnd,
            ),
            if (_hoverMs != null)
              Positioned(
                bottom: 40,
                left: (_x - 82).clamp(
                  0,
                  (bounds.maxWidth - 164).clamp(0, double.infinity),
                ),
                child: _preview(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _preview() => IgnorePointer(
    child: Material(
      elevation: 4,
      color: const Color(0xff202124),
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 164,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 94,
              child: _image != null
                  ? Image.memory(
                      _image!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    )
                  : Center(
                      child: _error != null
                          ? Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            )
                          : const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                    ),
            ),
            Text(
              videoTime(Duration(milliseconds: _hoverMs!)),
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    ),
  );
}
