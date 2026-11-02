import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';

class DesktopVideoMediaTools {
  DesktopVideoMediaTools(this.player, this.url);
  final Player player;
  final String url;
  final _processes = <Process>{};

  Future<dynamic> command(String method, Map args) async {
    switch (method) {
      case 'desktopPreview':
        return _ffmpeg([
          '-ss',
          '${(args['positionMs'] as num) / 1000}',
          '-i',
          url,
          '-frames:v',
          '1',
          '-an',
          '-sn',
          '-vf',
          'scale=256:256:force_original_aspect_ratio=decrease',
          '-f',
          'image2pipe',
          '-c:v',
          'mjpeg',
          'pipe:1',
        ]);
      case 'desktopSnapshot':
        final bytes = await player.screenshot(format: 'image/jpeg');
        if (bytes == null) throw StateError('当前画面暂不可用');
        return bytes;
      case 'desktopAudioClip':
        return _ffmpeg([
          '-ss',
          '${(args['startMs'] as num) / 1000}',
          '-i',
          url,
          '-t',
          '${(args['durationMs'] as num) / 1000}',
          '-vn',
          '-sn',
          '-ac',
          '1',
          '-ar',
          '22050',
          '-c:a',
          'pcm_s16le',
          '-f',
          'wav',
          'pipe:1',
        ]);
      case 'desktopSubtitles':
        final tracks = player.state.tracks.subtitle.where(
          (track) => track.id != 'auto' && track.id != 'no',
        );
        if (tracks.isEmpty) return '';
        return utf8.decode(
          await _ffmpeg(['-i', url, '-map', '0:s:0', '-f', 'srt', 'pipe:1']),
        );
      case 'desktopSubtitleOverlay':
        await player.setSubtitleTrack(SubtitleTrack.no());
        return null;
      case 'desktopNightAudio':
        final native = player.platform as NativePlayer;
        await native.setProperty(
          'af',
          args['enabled'] == true
              ? 'lavfi=[acompressor=threshold=0.125:ratio=4:attack=10:release=250:makeup=2,alimiter=limit=0.89]'
              : '',
        );
        return native.getProperty('af');
      default:
        throw UnsupportedError(method);
    }
  }

  Future<Uint8List> _ffmpeg(List<String> arguments) async {
    final bundled = File(
      '${File(Platform.resolvedExecutable).parent.path}/ffmpeg.exe',
    );
    final process = await Process.start(
      bundled.existsSync() ? bundled.path : 'ffmpeg',
      ['-hide_banner', '-loglevel', 'error', '-nostdin', ...arguments],
    );
    _processes.add(process);
    final output = process.stdout.fold(
      BytesBuilder(),
      (bytes, chunk) => bytes..add(chunk),
    );
    final errors = process.stderr.drain<void>();
    try {
      final code = await process.exitCode;
      final bytes = (await output).takeBytes();
      await errors;
      if (code != 0 || bytes.isEmpty) throw StateError('媒体处理失败，请检查片源后重试');
      return bytes;
    } finally {
      _processes.remove(process);
    }
  }

  void close() {
    for (final process in _processes) {
      process.kill();
    }
  }
}
