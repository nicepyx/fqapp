import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fqapp/services/desktop_video_controller.dart';
import 'package:fqapp/services/video_moments_store.dart';
import 'package:fqapp/widgets/desktop_video_seekbar.dart';
import 'package:fqapp/widgets/desktop_video_tools_host.dart';
import 'package:fqapp/widgets/desktop_video_tools_panel.dart';
import 'package:fqapp/widgets/video_moment_editor.dart';

import 'support/fakes.dart';

const subtitles = '''1
00:00:01,000 --> 00:00:03,000
First dialogue

2
00:00:05,500 --> 00:00:08,000
Second dialogue
''';

Future<void> settleIO(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('fqapp/native_player');
  late Directory directory;
  late VideoMomentsStore store;
  late DesktopVideoController tools;
  late FakeNativePlayer player;
  late Uint8List jpeg;
  final calls = <MethodCall>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('fqapp-video-tools-');
    store = VideoMomentsStore(directory: () async => directory);
    player = FakeNativePlayer();
    tools = DesktopVideoController(store: store);
    tools.playlistIds = {'episode'};
    tools.update(
      player: player,
      episodeId: 'episode',
      seriesTitle: 'Series',
      episodeTitle: 'Episode 1',
      enabled: true,
      rate: 1.5,
    );
    jpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 4, height: 4)));
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return switch (call.method) {
        'desktopSubtitles' => subtitles,
        'desktopPreview' || 'desktopSnapshot' => jpeg,
        'desktopAudioClip' => Uint8List.fromList([82, 73, 70, 70]),
        'desktopNightAudio' => call.arguments['enabled'] == true ? 'lavfi' : '',
        _ => null,
      };
    });
  });

  tearDown(() async {
    tools.dispose();
    await player.dispose();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });

  test(
    'parses real SRT and named VTT cues and applies subtitle offset',
    () async {
      final parsed = parseVideoSubtitles(subtitles);
      expect(parsed.map((cue) => cue.data), [
        'First dialogue',
        'Second dialogue',
      ]);
      expect(parsed.last.start, const Duration(milliseconds: 5500));
      final vtt = parseVideoSubtitles(
        'WEBVTT\n\nintro\n00:01.000 --> 00:03.000\nHello\n',
      );
      expect(vtt.single.data, 'Hello');
      expect(() => parseVideoSubtitles('invalid'), throwsFormatException);
      await tools.importSubtitles(subtitles);
      tools.setSubtitleOffset(500);
      expect(tools.cuesAt(const Duration(milliseconds: 1200)), isEmpty);
      expect(
        tools.cuesAt(const Duration(milliseconds: 1600)).single.data,
        'First dialogue',
      );
      expect(
        await (await store.subtitleFile('episode')).readAsString(),
        subtitles,
      );
    },
  );

  test(
    'temporary speed restores the previous rate without saving it',
    () async {
      await player.play();
      await tools.beginBoost();
      expect(player.rate, 2);
      expect(tools.boosting, isTrue);
      await tools.endBoost();
      expect(player.rate, 1.5);
      expect(tools.boosting, isFalse);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      await player.pause();
      await tools.beginBoost();
      expect(tools.boosting, isFalse);
    },
  );

  test(
    'night mode applies the native filter and persists its setting',
    () async {
      await tools.setNight(true);
      expect(calls.last.method, 'desktopNightAudio');
      expect(calls.last.arguments['enabled'], true);
      expect(tools.night, true);
      expect(
        (await SharedPreferences.getInstance()).getBool('desktop_video_night'),
        true,
      );
      await tools.setNight(false);
      expect(calls.last.arguments['enabled'], false);
    },
  );

  test(
    'bookmarks and media cards survive reloading and delete their media',
    () async {
      final bookmark = await tools.saveMoment(
        note: 'Return here',
        caption: '',
        card: false,
        audioSeconds: 10,
      );
      expect(calls.where((call) => call.method == 'desktopSnapshot'), isEmpty);
      final card = await tools.saveMoment(
        note: 'Card',
        caption: 'A line',
        card: true,
        audioSeconds: 10,
      );
      final reopened = VideoMomentsStore(directory: () async => directory);
      final items = await reopened.load();
      expect(items.map((item) => item.id), [card.id, bookmark.id]);
      expect(items.first.caption, 'A line');
      expect(items.first.positionMs, 20000);
      expect(await (await reopened.mediaFile(card, 'jpg')).readAsBytes(), jpeg);
      expect(calls.last.arguments['durationMs'], 10000);
      await reopened.remove(card);
      expect((await reopened.load()).single.id, bookmark.id);
      expect(await (await reopened.mediaFile(card, 'jpg')).exists(), false);
      expect(await (await reopened.mediaFile(card, 'wav')).exists(), false);
    },
  );

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(800, 640),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopVideoToolsScope(
            controller: tools,
            onOpenMoment: (_, position) => player.seek(position),
            child: child,
          ),
        ),
      ),
    );
    await settleIO(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'holding the actual picture changes speed and releasing restores it',
    (tester) async {
      await player.play();
      await mount(
        tester,
        const SizedBox(
          width: 300,
          height: 300,
          child: DesktopVideoSurface(child: ColoredBox(color: Colors.red)),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('video-boost-surface'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(player.rate, 2);
      expect(find.text('2.0x'), findsOneWidget);
      await gesture.up();
      await tester.pump();
      expect(player.rate, 1.5);
      await finish(tester);
    },
  );

  testWidgets('hover preview uses its own command and reuses cached images', (
    tester,
  ) async {
    await mount(
      tester,
      Center(
        child: SizedBox(
          width: 400,
          child: DesktopVideoSeekbar(
            value: 20000,
            max: 120000,
            onChanged: (_) {},
            onChangeEnd: (_) {},
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    final center = tester.getCenter(find.byType(Slider));
    await mouse.moveTo(center);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(calls.where((call) => call.method == 'desktopPreview').length, 1);
    expect(find.byType(Image), findsOneWidget);
    expect(player.position, const Duration(seconds: 20));
    expect(player.calls.where((call) => call.startsWith('seek:')), isEmpty);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await mouse.moveTo(center);
    await tester.pump(const Duration(milliseconds: 250));
    expect(calls.where((call) => call.method == 'desktopPreview').length, 1);
    await mouse.removePointer();
    await finish(tester);
  });

  for (final size in [const Size(800, 640), const Size(320, 200)]) {
    testWidgets('all tool tabs remain usable at $size', (tester) async {
      await mount(
        tester,
        DesktopVideoToolsPanel(onSeek: player.seek),
        size: size,
      );
      for (final label in ['字幕', '收藏', '播放']) {
        await tester.tap(find.text(label));
        await settleIO(tester);
        expect(tester.takeException(), isNull);
      }
      await finish(tester);
    });
  }

  testWidgets(
    'subtitle search filters real cues and clicking seeks to the offset',
    (tester) async {
      await tester.runAsync(() => tools.importSubtitles(subtitles));
      tools.setSubtitleOffset(500);
      await mount(tester, DesktopVideoToolsPanel(onSeek: player.seek));
      await tester.tap(find.text('字幕'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '搜索台词'), 'Second');
      await tester.pumpAndSettle();
      expect(find.text('First dialogue'), findsNothing);
      await tester.tap(find.text('Second dialogue'));
      await tester.pumpAndSettle();
      expect(player.position, const Duration(seconds: 6));
      await finish(tester);
    },
  );

  testWidgets('bookmark editor saves entered text through the real store', (
    tester,
  ) async {
    await mount(tester, VideoMomentEditor(tools: tools));
    await tester.enterText(find.widgetWithText(TextField, '备注'), 'Important');
    await tester.tap(find.text('保存'));
    await settleIO(tester);
    expect((await tester.runAsync(store.load))!.single.note, 'Important');
    await finish(tester);
  });
}
