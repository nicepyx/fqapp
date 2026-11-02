import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fqapp/services/desktop_shortcuts.dart';
import 'package:fqapp/widgets/desktop_shortcut_editor.dart';
import 'package:fqapp/widgets/desktop_shortcut_scope.dart';
import 'package:fqapp/widgets/video_player_chrome.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

void main() {
  final store = DesktopShortcuts.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store.endRecording(store);
    await store.load();
  });
  tearDown(() {
    store.endRecording(store);
    store.onRecordingChanged = null;
    debugDefaultTargetPlatformOverride = null;
  });

  test('conflicts respect module overlap and global boss key', () {
    const space = SingleActivator(LogicalKeyboardKey.space);
    expect(store.conflict(DesktopCommand.readerNext, space), isNull);
    expect(
      store.conflict(DesktopCommand.dramaNext, space),
      DesktopCommand.videoPlay,
    );
    expect(
      store.conflict(DesktopCommand.miniBoss, space),
      DesktopCommand.audioPlay,
    );
    expect(
      store.conflict(
        DesktopCommand.audioPlay,
        DesktopCommand.search.defaults.first,
      ),
      DesktopCommand.search,
    );
    expect(
      store.conflict(
        DesktopCommand.miniSettings,
        DesktopCommand.settings.defaults.first,
      ),
      isNull,
    );
  });

  test('custom bindings and disabled commands persist across reload', () async {
    const key = SingleActivator(LogicalKeyboardKey.keyJ, shift: true);
    await store.setKeys(DesktopCommand.readerNext, [key]);
    await store.setKeys(DesktopCommand.videoPlay, []);
    await store.load();
    expect(
      DesktopShortcuts.sameKey(
        store.keys(DesktopCommand.readerNext).single,
        key,
      ),
      isTrue,
    );
    expect(store.keys(DesktopCommand.videoPlay), isEmpty);
    expect(
      store.keys(DesktopCommand.audioPlay),
      DesktopCommand.audioPlay.defaults,
    );
  });

  test(
    'legacy page key migrates and explicit new setting takes precedence',
    () async {
      final prefs = await SharedPreferences.getInstance();
      const legacy = SingleActivator(LogicalKeyboardKey.keyA, control: true);
      await prefs.setString(
        'mini_reader_previous_key',
        jsonEncode(DesktopShortcuts.encode(legacy)),
      );
      await store.load();
      expect(
        DesktopShortcuts.sameKey(
          store.keys(DesktopCommand.miniPrevious).first,
          legacy,
        ),
        isTrue,
      );
      expect(
        store.keys(DesktopCommand.miniPrevious).last.trigger,
        LogicalKeyboardKey.pageUp,
      );
      await store.setKeys(DesktopCommand.miniPrevious, []);
      await store.load();
      expect(store.keys(DesktopCommand.miniPrevious), isEmpty);
    },
  );

  test('Windows global key encodes function and modifier keys', () {
    expect(
      DesktopShortcuts.windowsHotkey(
        const SingleActivator(
          LogicalKeyboardKey.f12,
          control: true,
          shift: true,
        ),
      ),
      {'key': 0x7b, 'modifiers': 6},
    );
    expect(
      DesktopShortcuts.windowsHotkey(
        const SingleActivator(
          LogicalKeyboardKey.keyQ,
          control: true,
          alt: true,
        ),
      ),
      {'key': 0x51, 'modifiers': 3},
    );
  });

  testWidgets('editor rejects overlap, captures, removes and restores keys', (
    tester,
  ) async {
    final recording = <bool>[];
    store.onRecordingChanged = (value) async => recording.add(value);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DesktopShortcutEditor(command: DesktopCommand.miniNext),
        ),
      ),
    );
    final input = find.byKey(const ValueKey('shortcut-miniNext-0'));
    await tester.tap(input);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('已用于小窗：上一页'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(store.keys(DesktopCommand.miniNext).first.control, isTrue);
    expect(
      store.keys(DesktopCommand.miniNext).first.trigger,
      LogicalKeyboardKey.keyJ,
    );
    expect(recording, [true, false]);
    expect(find.text('已用于小窗：上一页'), findsNothing);
    await tester.tap(find.byTooltip('移除按键').first);
    await tester.pumpAndSettle();
    expect(store.keys(DesktopCommand.miniNext).length, 1);
    await tester.tap(find.byTooltip('恢复默认'));
    await tester.pumpAndSettle();
    expect(
      store.keys(DesktopCommand.miniNext),
      DesktopCommand.miniNext.defaults,
    );
  });

  testWidgets('switching shortcut editors keeps key recording active', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              DesktopShortcutEditor(command: DesktopCommand.readerNext),
              DesktopShortcutEditor(command: DesktopCommand.readerPrevious),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('shortcut-readerNext-0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('shortcut-readerPrevious-0')));
    await tester.pump();
    expect(store.recording, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();
    expect(
      store.keys(DesktopCommand.readerPrevious).first.trigger,
      LogicalKeyboardKey.keyJ,
    );
  });

  testWidgets('module scope uses configured keys and leaves text input alone', (
    tester,
  ) async {
    var calls = 0;
    const key = SingleActivator(LogicalKeyboardKey.keyJ);
    await store.setKeys(DesktopCommand.audioPlay, [key]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopShortcutScope(
            group: DesktopShortcutGroup.audio,
            actions: {DesktopCommand.audioPlay: () => calls++},
            child: const TextField(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    expect(calls, 1);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('configured video keys drive real chrome playback and seeking', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await store.setKeys(DesktopCommand.videoPlay, [
      const SingleActivator(LogicalKeyboardKey.keyJ),
    ]);
    await store.setKeys(DesktopCommand.videoForward, [
      const SingleActivator(LogicalKeyboardKey.keyL),
    ]);
    final player = FakeNativePlayer();
    await tester.pumpWidget(
      MaterialApp(
        home: VideoPlayerChrome(
          player: player,
          title: '测试',
          episodes: const [],
          currentIndex: 0,
          duration: const Duration(minutes: 2),
          playing: false,
          enabled: true,
          onSelectEpisode: (_) async {},
          onError: (error) => fail('$error'),
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(player.calls, isNot(contains('play')));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pump();
    expect(player.calls, contains('play'));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.pump();
    expect(player.position, const Duration(seconds: 30));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pump();
    expect(player.calls.last, 'pause');
    await tester.pumpWidget(const SizedBox.shrink());
    await player.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
