import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter/services.dart';

import 'app_log.dart';
import 'desktop_media.dart';
import 'desktop_video_media_tools.dart';

class DesktopPlayer {
  DesktopPlayer(this.id, this.emit) {
    video = VideoController(player);
    void event(String type, dynamic value) {
      if (!disposed) emit({'playerId': id, 'type': type, 'value': value});
    }

    subscriptions.addAll([
      player.stream.position.listen((v) => event('position', v.inMilliseconds)),
      player.stream.duration.listen((v) => event('duration', v.inMilliseconds)),
      player.stream.playing.listen((v) => event('playing', v)),
      player.stream.buffering.listen((v) => event('buffering', v)),
      player.stream.completed.listen((v) => event('completed', v)),
      player.stream.width.listen((_) => _size()),
      player.stream.height.listen((_) => _size()),
      player.stream.error.listen(
        (_) => event('error', {'message': '媒体播放失败，请重试或切换清晰度'}),
      ),
    ]);
    unawaited(
      video.waitUntilFirstFrameRendered.then((_) => event('firstFrame', true)),
    );
  }
  final int id;
  final void Function(Map<String, dynamic>) emit;
  final player = Player();
  late final VideoController video;
  final subscriptions = <StreamSubscription<dynamic>>[];
  final ready = Completer<void>();
  DesktopMedia? media;
  DesktopVideoMediaTools? tools;
  bool disposed = false;

  Future<void> open(String url, String key) async {
    ready.future.ignore();
    try {
      var playbackUrl = url;
      if (key.isNotEmpty) {
        final session = await DesktopMedia.open(url, key);
        if (disposed) {
          session.close();
          return;
        }
        media = session;
        playbackUrl = session.url;
      }
      // Plain streams must also work with origins that don't support Range.
      if (disposed) return;
      await player.open(Media(playbackUrl), play: false);
      if (disposed) return;
      tools = DesktopVideoMediaTools(player, playbackUrl);
      ready.complete();
      emit({'playerId': id, 'type': 'created', 'value': id});
      _size();
    } catch (_) {
      if (!ready.isCompleted) ready.completeError(StateError('无法打开媒体'));
      if (!disposed) {
        emit({
          'playerId': id,
          'type': 'error',
          'value': {'message': '媒体加载失败，请检查网络或重试'},
        });
      }
      media?.close();
    }
  }

  void _size() {
    if (!disposed) {
      emit({
        'playerId': id,
        'type': 'videoSize',
        'width': player.state.width ?? 0,
        'height': player.state.height ?? 0,
        'rotationCorrection': 0,
      });
    }
  }

  Future<dynamic> command(String method, Map args) async {
    await ready.future;
    if (disposed) return null;
    AppLog.d('desktop-player', 'id=$id command=$method');
    if (method.startsWith('desktop')) return tools!.command(method, args);
    switch (method) {
      case 'play':
        await player.play();
        emit({'playerId': id, 'type': 'playWhenReady', 'value': true});
      case 'pause':
        await player.pause();
        emit({'playerId': id, 'type': 'playWhenReady', 'value': false});
      case 'seek':
        await player.seek(
          Duration(milliseconds: (args['positionMs'] as num).toInt()),
        );
      case 'setRate':
        await player.setRate((args['rate'] as num).toDouble());
      case 'setVolume':
        await player.setVolume(
          (args['volume'] as num).toDouble().clamp(0, 1) * 100,
        );
      default:
        throw MissingPluginException(method);
    }
    return null;
  }

  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    tools?.close();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await player.dispose();
    media?.close();
  }
}
