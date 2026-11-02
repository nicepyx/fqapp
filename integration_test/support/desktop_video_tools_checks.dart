import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:fqapp/services/native_player.dart';
import 'package:fqapp/widgets/desktop_video_tools_host.dart';

Future<void> verifyDesktopVideoTools(
  WidgetTester tester,
  NativePlayer player,
) async {
  final ffmpeg = File(
    '${File(Platform.resolvedExecutable).parent.path}/ffmpeg.exe',
  );
  final version = await Process.run(
    ffmpeg.existsSync() ? ffmpeg.path : 'ffmpeg',
    ['-version'],
  );
  expect(version.exitCode, 0, reason: 'FFmpeg launch: ${version.stderr}');
  final tools = DesktopVideoToolsScope.of(
    tester.element(find.byKey(const ValueKey('video-tools'))),
  );
  await player.pause();
  await tester.pump(const Duration(milliseconds: 300));
  await tools.setNight(true);
  await player.play();
  await tester.pump(const Duration(milliseconds: 300));
  await Future<void>.delayed(const Duration(milliseconds: 300));
  expect(player.lastError, isNull);
  final filter = await tools.call<String>('desktopNightAudio', {
    'enabled': true,
  });
  expect(filter, contains('acompressor'));
  await tools.setNight(false);
  await player.pause();
  await tester.pump(const Duration(milliseconds: 300));
  final position = player.position;
  final preview = await tools.preview(const Duration(seconds: 2));
  final frame = img.decodeJpg(preview!);
  expect(frame, isNotNull);
  expect(frame!.width, greaterThan(0));
  expect(frame.width, lessThanOrEqualTo(256));
  expect(
    player.position,
    position,
    reason: 'Preview must not seek the main video',
  );
  final moment = await tools.saveMoment(
    note: 'Windows integration fixture',
    caption: 'Fixture dialogue',
    card: true,
    audioSeconds: 2,
  );
  try {
    final items = await tools.store.load();
    expect(items.any((item) => item.id == moment.id), true);
    final screenshot = await (await tools.store.mediaFile(
      moment,
      'jpg',
    )).readAsBytes();
    expect(img.decodeJpg(screenshot), isNotNull);
    final sound = await (await tools.store.mediaFile(
      moment,
      'wav',
    )).readAsBytes();
    expect(String.fromCharCodes(sound.take(4)), 'RIFF');
    expect(sound.length, greaterThan(40000));
  } finally {
    await tools.store.remove(moment);
  }
  await tools.importSubtitles(
    '1\n00:00:00,000 --> 00:00:08,000\nFixture dialogue\n',
  );
  expect(
    tools.cuesAt(const Duration(seconds: 2)).single.data,
    'Fixture dialogue',
  );
  await tester.pump();
  expect(find.text('Fixture dialogue'), findsOneWidget);
  await player.play();
  await tester.pump(const Duration(milliseconds: 300));
  await tools.beginBoost();
  expect(tools.boosting, true);
  await tools.endBoost();
  expect(tools.boosting, false);
  await player.pause();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byKey(const ValueKey('video-tools')));
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.text('夜间声音模式'), findsOneWidget);
  await captureToolsPanel(tester);
  await tester.tap(find.byTooltip('关闭播放工具'));
  await tester.pump(const Duration(milliseconds: 300));
  await (await tools.store.subtitleFile('fixture')).delete();
}

Future<void> captureToolsPanel(WidgetTester tester) async {
  final boundary = tester
      .element(find.byType(Dialog))
      .findAncestorRenderObjectOfType<RenderRepaintBoundary>();
  if (boundary == null) return;
  final image = await boundary.toImage(pixelRatio: 1);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final output = File('build/validation/windows-video-tools.png');
  await output.parent.create(recursive: true);
  await output.writeAsBytes(png!.buffer.asUint8List());
}
