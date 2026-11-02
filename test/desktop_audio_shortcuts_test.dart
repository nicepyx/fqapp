import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fqapp/models/chapter_media.dart';
import 'package:fqapp/models/media_item.dart';
import 'package:fqapp/pages/audio_page.dart';
import 'package:fqapp/services/audio_preferences.dart';
import 'package:fqapp/services/desktop_shortcuts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/controlled_player.dart';
import 'support/fakes.dart';

void main() {
  testWidgets('desktop audio uses customized playback, seek and chapter keys', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    AudioPreferences.instance.resetForTest();
    final keys = DesktopShortcuts.instance;
    await keys.load();
    await keys.setKeys(DesktopCommand.audioPlay, [
      const SingleActivator(LogicalKeyboardKey.keyJ),
    ]);
    await keys.setKeys(DesktopCommand.audioForward, [
      const SingleActivator(LogicalKeyboardKey.keyL),
    ]);
    await keys.setKeys(DesktopCommand.audioNext, [
      const SingleActivator(LogicalKeyboardKey.keyN),
    ]);
    final players = <ControlledNativePlayer>[];
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: AudioPage(
          bookId: 'audio-shortcuts',
          title: '测试听书',
          chapters: [
            for (var i = 1; i <= 2; i++)
              Chapter(itemId: '$i', title: '第$i章', volumeName: ''),
          ],
          historyStore: MemoryReaderStore(),
          voicesLoader: () async => const [],
          sourceLoader: (id, {toneId}) async => AudioSource(
            itemId: id,
            url: 'https://example.invalid/$id.mp3',
            toneId: toneId ?? '0',
          ),
          playerFactory: () {
            final player = ControlledNativePlayer();
            players.add(player);
            return player;
          },
        ),
      ),
    );
    await _flush(tester);
    final first = players.single;
    expect(first.isPlaying, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await _flush(tester);
    expect(first.isPlaying, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await _flush(tester);
    expect(first.isPlaying, isFalse);
    first.emitPosition(const Duration(seconds: 20));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await _flush(tester);
    expect(first.position, const Duration(seconds: 35));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await _flush(tester);
    expect(players.length, 2);
    expect(first.disposed, isTrue);
    expect(
      players.last.calls,
      contains('create:https://example.invalid/2.mp3'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await _flush(tester);
    debugDefaultTargetPlatformOverride = null;
    await tester.binding.setSurfaceSize(null);
  });
}

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}
