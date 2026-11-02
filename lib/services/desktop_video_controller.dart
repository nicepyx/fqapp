import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle/subtitle.dart';

import 'native_player.dart';
import 'platform_channel.dart';
import 'video_moments_store.dart';

String videoTime(Duration value) {
  final seconds = value.inSeconds.clamp(0, 359999);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

List<Subtitle> parseVideoSubtitles(String text) {
  final cues = SubtitleParser(
    SubtitleObject(
      data: text,
      type: text.trimLeft().startsWith('WEBVTT')
          ? SubtitleType.vtt
          : SubtitleType.srt,
    ),
  ).parsing();
  cues.removeWhere((cue) => cue.end <= cue.start || cue.data.trim().isEmpty);
  cues.sort((a, b) => a.compareTo(b));
  if (cues.isEmpty) throw const FormatException('未找到有效的 SRT/VTT 字幕');
  return cues;
}

class DesktopVideoController extends ChangeNotifier {
  DesktopVideoController({VideoMomentsStore? store, this.onError})
    : store = store ?? VideoMomentsStore.instance;
  final void Function(Object)? onError;
  final VideoMomentsStore store;
  static const channel = AppMethodChannel('fqapp/native_player');
  NativePlayer? player;
  String episodeId = '', seriesTitle = '', episodeTitle = '';
  Set<String> playlistIds = {};
  double rate = 1, boostRate = 2;
  bool night = false, boosting = false, enabled = false;
  List<Subtitle> subtitles = [];
  bool subtitlesLoaded = false, subtitlesLoading = false;
  String? subtitleError;
  int subtitleOffsetMs = 0;
  bool subtitleVisible = true;
  bool _closed = false;
  NativePlayer? _boostPlayer;
  Future<void>? _boostWrite;
  double _restoreRate = 1;

  Future<void> loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    night = preferences.getBool('desktop_video_night') ?? false;
    boostRate = preferences.getDouble('desktop_video_boost_rate') ?? 2;
    if (_closed) return;
    if (night && enabled) await setNight(true);
    notifyListeners();
  }

  void update({
    required NativePlayer? player,
    required String episodeId,
    required String seriesTitle,
    required String episodeTitle,
    required bool enabled,
    required double rate,
  }) {
    final changed = !identical(this.player, player);
    if (changed || this.episodeId != episodeId) {
      unawaited(run(endBoost()));
      subtitles = [];
      subtitlesLoaded = subtitlesLoading = false;
      subtitleError = null;
      subtitleOffsetMs = 0;
    }
    this.player = player;
    this.episodeId = episodeId;
    this.seriesTitle = seriesTitle;
    this.episodeTitle = episodeTitle;
    final becameReady = enabled && (!this.enabled || changed);
    this.enabled = enabled;
    this.rate = rate;
    if (becameReady) {
      if (night) unawaited(run(setNight(true)));
      unawaited(Future<void>(() => loadSubtitles(savedOnly: true)));
    }
  }

  Future<void> run(Future<void> action) async {
    try {
      await action;
    } catch (error) {
      if (!_closed) onError?.call(error);
    }
  }

  Future<T?> call<T>(
    String method, [
    Map<String, dynamic> arguments = const {},
  ]) => channel.invokeMethod<T>(method, {'id': player!.playerId, ...arguments});

  Future<void> setNight(bool value) async {
    await call<String>('desktopNightAudio', {'enabled': value});
    if (_closed) return;
    night = value;
    await (await SharedPreferences.getInstance()).setBool(
      'desktop_video_night',
      value,
    );
    if (!_closed) notifyListeners();
  }

  Future<void> setBoostRate(double value) async {
    boostRate = value;
    await (await SharedPreferences.getInstance()).setDouble(
      'desktop_video_boost_rate',
      value,
    );
    if (!_closed) notifyListeners();
  }

  Future<void> beginBoost() async {
    if (!enabled || boosting || player?.playWhenReady != true) return;
    boosting = true;
    _boostPlayer = player;
    _restoreRate = rate;
    _boostWrite = player!.setRate(boostRate);
    notifyListeners();
    await _boostWrite;
  }

  Future<void> endBoost() async {
    final previous = _boostPlayer;
    if (previous == null) return;
    final restoreRate = _restoreRate;
    _boostPlayer = null;
    boosting = false;
    // A quick release can arrive before the native speed change is acknowledged.
    await _boostWrite;
    if (previous.isCreated) await previous.setRate(restoreRate);
    if (!_closed) notifyListeners();
  }

  Future<Uint8List?> preview(Duration position) => call<Uint8List>(
    'desktopPreview',
    {'positionMs': position.inMilliseconds},
  );

  Future<void> loadSubtitles({bool savedOnly = false}) async {
    if (_closed || subtitlesLoaded || subtitlesLoading || !enabled) return;
    final id = episodeId;
    subtitlesLoading = true;
    subtitleError = null;
    notifyListeners();
    try {
      final saved = await store.subtitleFile(id);
      final exists = await saved.exists();
      if (savedOnly && !exists) return;
      final text = exists
          ? await saved.readAsString()
          : await call<String>('desktopSubtitles') ?? '';
      if (_closed || id != episodeId) return;
      subtitles = text.isEmpty ? [] : parseVideoSubtitles(text);
      if (subtitles.isNotEmpty) await call<void>('desktopSubtitleOverlay');
      subtitlesLoaded = true;
    } catch (_) {
      if (!_closed && id == episodeId) subtitleError = '字幕读取失败，可重试或导入本地字幕';
    } finally {
      if (!_closed && id == episodeId) {
        subtitlesLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> importSubtitles(String text) async {
    final cues = parseVideoSubtitles(text);
    await call<void>('desktopSubtitleOverlay');
    await (await store.subtitleFile(episodeId)).writeAsString(text);
    if (_closed) return;
    subtitles = cues;
    subtitlesLoaded = true;
    subtitleError = null;
    notifyListeners();
  }

  List<Subtitle> cuesAt(Duration position) {
    final time = position - Duration(milliseconds: subtitleOffsetMs);
    return subtitles
        .where((cue) => cue.start <= time && time < cue.end)
        .toList();
  }

  void setSubtitleOffset(int milliseconds) {
    subtitleOffsetMs = milliseconds;
    notifyListeners();
  }

  void setSubtitleVisible(bool value) {
    subtitleVisible = value;
    notifyListeners();
  }

  Future<VideoMoment> saveMoment({
    required String note,
    required String caption,
    required bool card,
    required int audioSeconds,
  }) async {
    final target = player!;
    final position = target.position;
    final available = (target.duration - position).inMilliseconds.clamp(
      0,
      audioSeconds * 1000,
    );
    final moment = VideoMoment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      episodeId: episodeId,
      seriesTitle: seriesTitle,
      episodeTitle: episodeTitle,
      positionMs: position.inMilliseconds,
      caption: caption,
      note: note,
      hasImage: card,
      hasAudio: card && available > 0,
      audioDurationMs: card ? available : 0,
    );
    final image = card
        ? await channel.invokeMethod<Uint8List>('desktopSnapshot', {
            'id': target.playerId,
          })
        : null;
    final audio = moment.hasAudio
        ? await channel.invokeMethod<Uint8List>('desktopAudioClip', {
            'id': target.playerId,
            'startMs': position.inMilliseconds,
            'durationMs': available,
          })
        : null;
    await store.save(moment, image: image, audio: audio);
    return moment;
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(run(endBoost()));
    super.dispose();
  }
}
