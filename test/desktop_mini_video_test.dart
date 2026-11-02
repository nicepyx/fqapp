import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fqapp/models/media_item.dart';
import 'package:fqapp/services/desktop_mini_reader.dart';
import 'package:fqapp/services/desktop_shortcuts.dart';
import 'package:fqapp/widgets/desktop_mini_video.dart';
import 'package:fqapp/widgets/desktop_video_seekbar.dart';
import 'package:fqapp/widgets/video_player_chrome.dart';

import 'support/fakes.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  final mini = DesktopMiniReaderController.instance;
  const native = MethodChannel('fqapp/mini_reader');
  const windows = MethodChannel('window_manager');
  const screen = MethodChannel('dev.leanflutter.plugins/screen_retriever');
  final calls = <MethodCall>[];
  late FakeNativePlayer player;
  late ValueNotifier<int> episode;
  final selections = <int>[];
  final errors = <Object>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DesktopShortcuts.instance.load();
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    player = FakeNativePlayer(width: 720, height: 1280);
    episode = ValueNotifier(1);
    selections.clear();
    errors.clear();
    calls.clear();
    messenger.setMockMethodCallHandler(native, (call) async {
      calls.add(call);
      return switch (call.method) {
        'enter' || 'setBossKey' => true,
        'windowTargets' => [
          {'handle': 123, 'title': 'ChatGPT', 'application': 'ChatGPT.exe'},
        ],
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(windows, (call) async {
      calls.add(call);
      return switch (call.method) {
        'getBounds' => {
          'x': 100.0,
          'y': 70.0,
          'width': 1280.0,
          'height': 800.0,
        },
        'isMaximized' || 'isAlwaysOnTop' || 'isSkipTaskbar' => false,
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(
      screen,
      (_) async => {
        'id': 'primary',
        'size': {'width': 1920.0, 'height': 1080.0},
        'visibleSize': {'width': 1920.0, 'height': 1040.0},
      },
    );
  });

  tearDown(() async {
    await mini.leave();
    await player.dispose();
    episode.dispose();
    debugDefaultTargetPlatformOverride = null;
    for (final channel in [native, windows, screen]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  Future<void> nativeEvent(String method, bool value) =>
      messenger.handlePlatformMessage(
        native.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, value)),
        (_) {},
      );

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    double scale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: _captureLayout ? 'PlayerPreview' : null),
        builder: (context, child) => RepaintBoundary(
          key: const ValueKey('desktop-player-preview'),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: StreamBuilder<bool>(
          stream: player.playingStream,
          builder: (context, _) => ValueListenableBuilder<int>(
            valueListenable: episode,
            builder: (context, index, _) => VideoPlayerChrome(
              player: player,
              title: '测试短剧 第 ${index + 1} 集',
              seriesTitle: '测试短剧',
              episodes: [
                for (var i = 0; i < 20; i++)
                  Chapter(itemId: '$i', title: '第 ${i + 1} 集', volumeName: ''),
              ],
              currentIndex: index,
              duration: player.duration,
              playing: player.playing,
              enabled: true,
              shortSeries: true,
              defaultMute: false,
              onSelectEpisode: (index) async {
                selections.add(index);
                episode.value = index;
              },
              onError: errors.add,
              child: const ColoredBox(
                key: ValueKey('video-surface'),
                color: Colors.red,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enter(
    WidgetTester tester, {
    Size size = const Size(360, 640),
  }) async {
    await tester.tap(find.byKey(const ValueKey('video-mini-window')));
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(size);
    await tester.pumpAndSettle();
    expect(find.byType(DesktopMiniVideo), findsOneWidget);
    expect(errors, isEmpty);
    expect(tester.takeException(), isNull);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  }

  setUpAll(() async {
    if (!_captureLayout) return;
    await (FontLoader('PlayerPreview')..addFont(
          File(
            r'C:\Windows\Fonts\msyh.ttc',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/flutter_lucide/lucide')..addFont(
          rootBundle.load('packages/flutter_lucide/lib/fonts/lucide.ttf'),
        ))
        .load();
  });

  for (final layout in [
    (name: 'wide', size: const Size(1280, 800), scale: 1.0),
    (name: 'compact', size: const Size(480, 420), scale: 1.0),
    (name: 'large-text', size: const Size(480, 420), scale: 2.0),
  ]) {
    testWidgets('desktop toolbar stays reachable at ${layout.name}', (
      tester,
    ) async {
      await mount(tester, size: layout.size, scale: layout.scale);
      expect(tester.takeException(), isNull);
      final actions = find.byKey(const ValueKey('desktop-video-actions'));
      final scroll = tester.widget<SingleChildScrollView>(actions).controller!;
      if (layout.size.width < 680) {
        expect(scroll.position.maxScrollExtent, greaterThan(0));
        await tester.drag(actions, const Offset(-900, 0));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('video-mini-window')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
      }
      if (_captureLayout) await _capturePlayer(tester, layout.name);
      await finish(tester);
    });
  }

  testWidgets('desktop scrubbing previews time without seeking until release', (
    tester,
  ) async {
    await mount(tester);
    final seekbar = tester.widget<DesktopVideoSeekbar>(
      find.byType(DesktopVideoSeekbar),
    );
    seekbar.onChanged!(65000);
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('desktop-video-position')))
          .data,
      '1:05',
    );
    expect(player.position, const Duration(seconds: 20));
    expect(player.calls.where((call) => call.startsWith('seek:')), isEmpty);
    seekbar.onChangeEnd(65000);
    await tester.pumpAndSettle();
    expect(player.position, const Duration(seconds: 65));
    expect(player.playing, isFalse);
    await finish(tester);
  });

  testWidgets(
    'desktop controls stay visible while hovered and resume hiding after exit',
    (tester) async {
      await player.play();
      await mount(tester);
      final transport = find.byKey(const ValueKey('desktop-video-transport'));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(transport));
      await tester.pump(const Duration(seconds: 4));
      expect(tester.widget<AnimatedOpacity>(transport).opacity, 1);
      await mouse.moveTo(const Offset(200, 80));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<AnimatedOpacity>(transport).opacity, 0);
      expect(
        find.ancestor(
          of: transport,
          matching: find.byWidgetPredicate(
            (widget) => widget is ExcludeFocus && widget.excluding,
          ),
        ),
        findsOneWidget,
      );
      await mouse.removePointer();
      await finish(tester);
    },
  );

  testWidgets('keyboard focus and popup keep desktop controls visible', (
    tester,
  ) async {
    await player.play();
    await mount(tester, size: const Size(800, 600));
    final transport = find.byKey(const ValueKey('desktop-video-transport'));
    final playIcon = find.descendant(
      of: find.byTooltip('播放 / 暂停（空格）'),
      matching: find.byType(Icon),
    );
    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      if (Focus.of(tester.element(playIcon)).hasFocus) break;
    }
    expect(Focus.of(tester.element(playIcon)).hasFocus, isTrue);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.widget<AnimatedOpacity>(transport).opacity, 1);
    await tester.tap(find.byTooltip('倍速'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(tester.widget<AnimatedOpacity>(transport).opacity, 1);
    await tester.tap(find.text('1.5x').last);
    await tester.pumpAndSettle();
    expect(player.rate, 1.5);
    await finish(tester);
  });

  testWidgets('enter and restore preserve the player and position', (
    tester,
  ) async {
    await player.play();
    await mount(tester);
    await enter(tester);
    expect(mini.videoActive, isTrue);
    expect(mini.readerActive, isFalse);
    expect(player.position, const Duration(seconds: 20));
    expect(player.calls.where((call) => call == 'play' || call == 'pause'), [
      'play',
    ]);
    final surface = tester.getSize(find.byKey(const ValueKey('video-surface')));
    expect(surface.width / surface.height, closeTo(9 / 16, .001));
    await tester.tap(find.byKey(const ValueKey('mini-video-exit')));
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpAndSettle();
    expect(mini.active, isFalse);
    expect(player.position, const Duration(seconds: 20));
    expect(player.disposed, isFalse);
    expect(find.byKey(const ValueKey('video-mini-window')), findsOneWidget);
    final restored = calls.lastWhere((call) => call.method == 'setBounds');
    expect(restored.arguments['width'], 1280.0);
    expect(restored.arguments['height'], 800.0);
    await finish(tester);
  });

  testWidgets('keyboard, wheel, seek, mute and speed operate the same player', (
    tester,
  ) async {
    await mount(tester);
    await enter(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(player.calls, contains('play'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(player.position, const Duration(seconds: 30));
    await tester.tap(find.byTooltip('快退 10 秒'));
    await tester.pumpAndSettle();
    expect(player.position, const Duration(seconds: 20));
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('mini-video-progress')),
    );
    slider.onChangeEnd!(60000);
    await tester.pumpAndSettle();
    expect(player.position, const Duration(minutes: 1));
    await tester.tap(find.byTooltip('静音'));
    await tester.pumpAndSettle();
    expect(player.volume, 0);
    await tester.tap(find.byTooltip('取消静音'));
    await tester.pumpAndSettle();
    expect(player.volume, 1);
    await tester.tap(find.byTooltip('播放速度'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('1.5x'),
        matching: find.byType(CheckedPopupMenuItem<double>),
      ),
    );
    await tester.pumpAndSettle();
    expect(player.rate, 1.5);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final center = tester.getCenter(
      find.byKey(const ValueKey('video-surface')),
    );
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
    await tester.pumpAndSettle();
    expect(selections, [2]);
    await tester.tap(find.byTooltip('选集'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第 4 集'));
    await tester.pumpAndSettle();
    expect(selections, [2, 3]);
    expect(mini.menuOpen, isFalse);
    await finish(tester);
  });

  testWidgets('hiding pauses and resumes only playback that was active', (
    tester,
  ) async {
    await player.play();
    await mount(tester);
    await enter(tester);
    await nativeEvent('hidden', true);
    await tester.pumpAndSettle();
    expect(player.playWhenReady, isFalse);
    expect(player.calls.last, 'pause');
    await nativeEvent('hidden', false);
    await tester.pumpAndSettle();
    expect(player.playWhenReady, isTrue);
    expect(player.calls.last, 'play');
    await tester.tap(find.byTooltip('播放 / 暂停'));
    await tester.pumpAndSettle();
    expect(player.playWhenReady, isFalse);
    final before = player.calls.length;
    await nativeEvent('hidden', true);
    await nativeEvent('hidden', false);
    await tester.pumpAndSettle();
    expect(player.calls.length, before);
    await finish(tester);
  });

  testWidgets(
    'video settings bind windows without changing reader preferences',
    (tester) async {
      await mount(tester);
      await enter(tester);
      await tester.tap(find.byTooltip('鼠标移开时隐身'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('小窗设置'));
      await tester.pumpAndSettle();
      expect(find.text('文字外观'), findsNothing);
      final opacity = tester.widget<Slider>(
        find.byKey(const ValueKey('mini-video-opacity')),
      );
      opacity.onChanged!(.5);
      await tester.pumpAndSettle();
      expect(mini.videoOpacity, .5);
      await tester.tap(find.byKey(const ValueKey('mini-settings-window')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('绑定应用窗口'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ChatGPT'));
      await tester.pumpAndSettle();
      expect(mini.boundWindow?.handle, 123);
      expect(
        calls.where((call) => call.method == 'bindWindow').last.arguments,
        123,
      );
      await tester.tap(find.byTooltip('关闭小窗设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mini-video-exit')));
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpAndSettle();
      await mini.enter();
      expect(mini.readerActive, isTrue);
      expect(mini.hoverHide, isFalse);
      await mini.leave();
      await finish(tester);
    },
  );

  for (final size in [
    const Size(320, 200),
    const Size(360, 640),
    const Size(560, 315),
  ]) {
    testWidgets('controls and panels fit at $size', (tester) async {
      await mount(tester);
      await enter(tester, size: size);
      await tester.tap(find.byTooltip('小窗设置'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('关闭小窗设置'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭小窗设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('选集'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭选集'));
      await tester.pumpAndSettle();
      await finish(tester);
    });
  }

  testWidgets(
    'custom entry and exit shortcut and disposal restore the window',
    (tester) async {
      await DesktopShortcuts.instance.setKeys(DesktopCommand.videoMini, [
        const SingleActivator(LogicalKeyboardKey.keyJ, control: true),
      ]);
      await mount(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(mini.videoActive, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(mini.active, isFalse);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(mini.videoActive, isTrue);
      await finish(tester);
      await tester.pumpAndSettle();
      expect(mini.active, isFalse);
      expect(calls.map((call) => call.method), contains('leave'));
    },
  );

  testWidgets(
    'held speed shortcut works in normal and mini mode and restores on hide',
    (tester) async {
      await player.play();
      await mount(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(player.rate, 2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(player.rate, 1);
      await enter(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(player.rate, 2);
      await nativeEvent('hidden', true);
      await tester.pumpAndSettle();
      expect(player.rate, 1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyL);
      await nativeEvent('hidden', false);
      await tester.pumpAndSettle();
      await finish(tester);
    },
  );

  testWidgets('long press is reachable through real normal and mini controls', (
    tester,
  ) async {
    await player.play();
    await mount(tester);
    for (final inMini in [false, true]) {
      if (inMini) await enter(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('video-surface'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(player.rate, 2);
      await gesture.up();
      await tester.pump();
      expect(player.rate, 1);
      expect(player.playWhenReady, true);
    }
    await finish(tester);
  });
}

const _captureLayout = bool.fromEnvironment('FQAPP_CAPTURE_LAYOUT');

Future<void> _capturePlayer(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('desktop-player-preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/validation/reading-player/player-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
