import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

class VideoMoment {
  const VideoMoment({
    required this.id,
    required this.episodeId,
    required this.seriesTitle,
    required this.episodeTitle,
    required this.positionMs,
    this.caption = '',
    this.note = '',
    this.hasImage = false,
    this.hasAudio = false,
    this.audioDurationMs = 0,
  });
  final String id, episodeId, seriesTitle, episodeTitle, caption, note;
  final int positionMs, audioDurationMs;
  final bool hasImage, hasAudio;

  Map<String, dynamic> toJson() => {
    'id': id,
    'episodeId': episodeId,
    'seriesTitle': seriesTitle,
    'episodeTitle': episodeTitle,
    'positionMs': positionMs,
    'caption': caption,
    'note': note,
    'hasImage': hasImage,
    'hasAudio': hasAudio,
    'audioDurationMs': audioDurationMs,
  };
  factory VideoMoment.fromJson(Map<String, dynamic> data) => VideoMoment(
    id: data['id'] as String,
    episodeId: data['episodeId'] as String,
    seriesTitle: data['seriesTitle'] as String,
    episodeTitle: data['episodeTitle'] as String,
    positionMs: data['positionMs'] as int,
    caption: data['caption'] as String,
    note: data['note'] as String,
    hasImage: data['hasImage'] as bool,
    hasAudio: data['hasAudio'] as bool,
    audioDurationMs: data['audioDurationMs'] as int,
  );
}

class VideoMomentsStore {
  VideoMomentsStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;
  static final instance = VideoMomentsStore();
  final Future<Directory> Function() _directory;

  Future<Directory> get root async => Directory(
    '${(await _directory()).path}/video_moments',
  ).create(recursive: true);

  Future<List<VideoMoment>> load() async {
    final file = File('${(await root).path}/index.json');
    if (!await file.exists()) return [];
    return (jsonDecode(await file.readAsString()) as List)
        .map((entry) => VideoMoment.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<File> mediaFile(VideoMoment moment, String extension) async =>
      File('${(await root).path}/${moment.id}.$extension');

  Future<void> save(
    VideoMoment moment, {
    Uint8List? image,
    Uint8List? audio,
  }) async {
    if (image != null) {
      await (await mediaFile(moment, 'jpg')).writeAsBytes(image);
    }
    if (audio != null) {
      await (await mediaFile(moment, 'wav')).writeAsBytes(audio);
    }
    final moments = await load();
    moments.removeWhere((item) => item.id == moment.id);
    moments.insert(0, moment);
    await File(
      '${(await root).path}/index.json',
    ).writeAsString(jsonEncode(moments.map((item) => item.toJson()).toList()));
  }

  Future<void> remove(VideoMoment moment) async {
    final moments = await load()
      ..removeWhere((item) => item.id == moment.id);
    await File(
      '${(await root).path}/index.json',
    ).writeAsString(jsonEncode(moments.map((item) => item.toJson()).toList()));
    for (final extension in ['jpg', 'wav']) {
      final file = await mediaFile(moment, extension);
      if (await file.exists()) await file.delete();
    }
  }

  Future<File> subtitleFile(String episodeId) async => File(
    '${(await root).path}/sub-${sha256.convert(utf8.encode(episodeId))}.txt',
  );
}
