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
import 'package:fqapp/pages/reader_page.dart';
import 'package:fqapp/services/desktop_mini_reader.dart';
import 'package:fqapp/services/desktop_platform.dart';
import 'package:fqapp/services/reader_preferences.dart';
import 'package:fqapp/widgets/desktop_app_frame.dart';
import 'package:fqapp/widgets/reader/reader_paged_view.dart';
import 'package:fqapp/widgets/reader/reader_directory_sheet.dart';

import 'support/fakes.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  const native = MethodChannel('fqapp/mini_reader');
  const windows = MethodChannel('window_manager');
  const screen = MethodChannel('dev.leanflutter.plugins/screen_retriever');
  final mini = DesktopMiniReaderController.instance;
  final windowCalls = <MethodCall>[];
  final nativeCalls = <MethodCall>[];
  var hotkeyAvailable = true;
  var maximized = false;
  var pinned = false;
  var skipTaskbar = false;

  SharedPreferences.setMockInitialValues({});
  setUpAll(() async {
    if (!_capture) return;
    final loader = FontLoader('MiniReaderPreview')
      ..addFont(
        File(
          r'C:\Windows\Fonts\msyh.ttc',
        ).readAsBytes().then(ByteData.sublistView),
      );
    await loader.load();
    await (FontLoader('packages/flutter_lucide/lucide')..addFont(
          rootBundle.load('packages/flutter_lucide/lib/fonts/lucide.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() async {
    await (await SharedPreferences.getInstance()).clear();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    windowCalls.clear();
    nativeCalls.clear();
    hotkeyAvailable = true;
    maximized = false;
    pinned = false;
    skipTaskbar = false;
    messenger.setMockMethodCallHandler(native, (call) async {
      nativeCalls.add(call);
      if (call.method == 'enter' || call.method == 'setBossKey') {
        return hotkeyAvailable;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(windows, (call) async {
      windowCalls.add(call);
      return switch (call.method) {
        'getBounds' => {
          'x': 110.0,
          'y': 70.0,
          'width': 1280.0,
          'height': 800.0,
        },
        'isMaximized' => maximized,
        'isAlwaysOnTop' => pinned,
        'isSkipTaskbar' => skipTaskbar,
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
    debugDefaultTargetPlatformOverride = null;
    for (final channel in [native, windows, screen]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  test(
    'enter and leave restore the original window and saved preferences',
    () async {
      maximized = true;
      pinned = true;
      skipTaskbar = true;
      await mini.enter();
      expect(mini.active, isTrue);
      expect(
        windowCalls.map((call) => call.method),
        contains('setAsFrameless'),
      );
      expect(windowCalls.map((call) => call.method), contains('unmaximize'));
      final size = windowCalls.lastWhere((call) => call.method == 'setBounds');
      expect(size.arguments['width'], 460);
      expect(size.arguments['height'], 620);
      await mini.setHoverHide(true);
      await mini.setSkipTaskbar(true);
      await mini.setPinned(false);
      await mini.setBackgroundOpacity(.35);
      await mini.setLightText(false);
      await mini.setPageKey(-1, const SingleActivator(LogicalKeyboardKey.keyA));
      await mini.setPageKey(
        1,
        const SingleActivator(LogicalKeyboardKey.keyD, control: true),
      );
      await mini.toggleHidden();
      expect(nativeCalls.last.method, 'toggleHidden');
      await mini.leave();
      expect(mini.active, isFalse);
      expect(windowCalls.last.method, 'maximize');
      final bounds = windowCalls.lastWhere(
        (call) => call.method == 'setBounds',
      );
      expect(bounds.arguments['x'], 110);
      expect(bounds.arguments['y'], 70);
      expect(bounds.arguments['width'], 1280);
      expect(bounds.arguments['height'], 800);
      expect(
        windowCalls
            .lastWhere((call) => call.method == 'setAlwaysOnTop')
            .arguments,
        {'isAlwaysOnTop': true},
      );
      expect(
        windowCalls
            .lastWhere((call) => call.method == 'setSkipTaskbar')
            .arguments,
        {'isSkipTaskbar': true},
      );
      await mini.enter();
      expect(mini.hoverHide, isTrue);
      expect(mini.skipTaskbar, isTrue);
      expect(mini.pinned, isFalse);
      expect(mini.lightText, isFalse);
      expect(mini.backgroundOpacity, .35);
      expect(mini.previousPageKey.trigger, LogicalKeyboardKey.keyA);
      expect(mini.nextPageKey.trigger, LogicalKeyboardKey.keyD);
      expect(mini.nextPageKey.control, isTrue);
    },
  );

  test(
    'a conflicting boss key still allows mini mode and mouse hiding',
    () async {
      hotkeyAvailable = false;
      await mini.enter();
      expect(mini.active, isTrue);
      expect(mini.hotkeyAvailable, isFalse);
      expect(mini.changing, isFalse);
      expect(
        windowCalls.map((call) => call.method),
        contains('setAsFrameless'),
      );
      await mini.setSkipTaskbar(true);
      await mini.toggleHidden();
      expect(mini.skipTaskbar, isTrue);
      expect(nativeCalls.last.method, 'toggleHidden');
      await mini.leave();
      hotkeyAvailable = true;
      await mini.enter();
      expect(mini.hotkeyAvailable, isTrue);
    },
  );

  _testWindows(
    'real reader keeps its text anchor across mini mode and resize',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = MemoryReaderStore();
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      final readerState = tester.state(find.byType(ReaderPage));
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      final anchor = store.entry!['textOffset'] as int;
      expect(anchor, greaterThan(0));
      await tester.tapAt(tester.getCenter(_surface));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reader-mini-window')));
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(460, 620));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ReaderPage)), same(readerState));
      expect(find.byKey(const Key('desktop-navigation')), findsNothing);
      final pager = _pager(tester);
      expect(pager.backgroundColor, Colors.transparent);
      expect(pager.turnStyle, ReaderPageTurnStyle.none);
      _expectAnchor(tester, anchor);
      final scaffold = tester.widget<Scaffold>(
        find.byKey(const ValueKey('desktop-mini-reader')),
      );
      expect(scaffold.backgroundColor!.a, 0);
      expect(pager.layout.spec.bodyStyle.color!.a, 1);
      await _capturePreview(tester, 'reading');
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      final nextAnchor = store.entry!['textOffset'] as int;
      expect(nextAnchor, greaterThan(anchor));
      await tester.tap(find.byKey(const ValueKey('mini-reader-exit')));
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ReaderPage)), same(readerState));
      expect(find.byKey(const Key('desktop-navigation')), findsOneWidget);
      _expectAnchor(tester, nextAnchor);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  _testWindows('scroll reading keeps its paragraph through mini mode', (
    tester,
  ) async {
    await (await SharedPreferences.getInstance()).setString(
      'reader_page_mode',
      'scroll',
    );
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryReaderStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    final readerState = tester.state(find.byType(ReaderPage));
    await tester.drag(_surface, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    final anchor = store.entry!['textOffset'];
    expect(anchor, greaterThan(0));
    await mini.enter();
    await tester.binding.setSurfaceSize(const Size(460, 620));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderPagedView), findsNothing);
    expect(store.entry!['textOffset'], anchor);
    expect(tester.state(find.byType(ReaderPage)), same(readerState));
    await mini.leave();
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpAndSettle();
    expect(store.entry!['textOffset'], anchor);
    expect(tester.takeException(), isNull);
  });

  _testWindows('mini reader wheel and configured keys turn the real page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(460, 620));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mini.enter();
    await tester.pumpWidget(_app(MemoryReaderStore()));
    await tester.pumpAndSettle();
    Future<void> wheel(double delta, Finder target) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(target),
          scrollDelta: Offset(0, delta),
        ),
      );
      await tester.pumpAndSettle();
    }

    final start = _pager(tester).pageIndex;
    await wheel(120, _surface);
    expect(_pager(tester).pageIndex, start + 1);
    await wheel(-120, _surface);
    expect(_pager(tester).pageIndex, start);
    await tester.tap(find.byTooltip('小窗设置'));
    await tester.pumpAndSettle();
    final nextKey = find.byKey(const ValueKey('mini-page-key-1'));
    await tester.tap(find.byKey(const ValueKey('mini-settings-keys')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(nextKey);
    await tester.tap(nextKey);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(mini.nextPageKey.trigger, LogicalKeyboardKey.arrowRight);
    expect(find.text('已用于小窗：上一页'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(mini.nextPageKey.trigger, LogicalKeyboardKey.keyD);
    expect(mini.nextPageKey.control, isTrue);
    await _capturePreview(tester, 'page-keys');
    expect(_pager(tester).pageIndex, start);
    await wheel(120, nextKey);
    expect(_pager(tester).pageIndex, start);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();
    expect(_pager(tester).pageIndex, start);
    await tester.tap(find.byTooltip('小窗设置'));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(_surface));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(_pager(tester).pageIndex, start + 1);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(_pager(tester).pageIndex, start + 1);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    expect(_pager(tester).pageIndex, start);
    expect(tester.takeException(), isNull);
  });

  _testWindows('hotkey conflict does not block the mouse entry or exit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(MemoryReaderStore()));
    await tester.pumpAndSettle();
    hotkeyAvailable = false;
    await tester.tapAt(tester.getCenter(_surface));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reader-mini-window')));
    await tester.pumpAndSettle();
    expect(find.text('Ctrl+Alt+Q 已被占用，已启用鼠标恢复'), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-mini-reader')), findsOneWidget);
    expect(find.byKey(const Key('desktop-navigation')), findsNothing);
    expect(mini.active, isTrue);
    expect(find.byTooltip('临时隐藏（鼠标移出后移回显示）'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mini-reader-exit')));
    await tester.pumpAndSettle();
    expect(mini.active, isFalse);
    expect(find.byKey(const Key('desktop-navigation')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  _testWindows(
    'minimum size settings, hover controls and final page stay usable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 280));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mini.enter();
      await tester.pumpWidget(_app(MemoryReaderStore()));
      await tester.pumpAndSettle();
      final surface = tester.getRect(_surface);
      await messenger.handlePlatformMessage(
        native.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('hover', false),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('下一页').hitTestable(), findsNothing);
      expect(tester.getRect(_surface), surface);
      await messenger.handlePlatformMessage(
        native.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('hover', true),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('目录'));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderDirectorySheet), findsOneWidget);
      expect(nativeCalls.last.method, 'setMenuOpen');
      expect(nativeCalls.last.arguments, isTrue);
      DesktopPlatform.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(nativeCalls.last.arguments, isFalse);
      await tester.tap(find.byTooltip('小窗设置'));
      await tester.pumpAndSettle();
      expect(nativeCalls.last.method, 'setMenuOpen');
      expect(nativeCalls.last.arguments, isTrue);
      await tester.tap(find.byKey(const ValueKey('mini-text-false')));
      await tester.pumpAndSettle();
      expect(mini.lightText, isFalse);
      await tester.tap(find.byTooltip('增大字号'));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('mini-background-opacity')),
      );
      slider.onChanged!(.5);
      await tester.pumpAndSettle();
      final scaffold = tester.widget<Scaffold>(
        find.byKey(const ValueKey('desktop-mini-reader')),
      );
      expect(scaffold.backgroundColor!.a, closeTo(.5, .01));
      expect(_pager(tester).layout.spec.bodyStyle.color!.a, 1);
      await _capturePreview(tester, 'settings-minimum-size');
      await tester.tap(find.byKey(const ValueKey('mini-settings-keys')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('mini-page-key-1')));
      await tester.pumpAndSettle();
      await _capturePreview(tester, 'page-keys-minimum-size');
      await tester.tap(find.byKey(const ValueKey('mini-settings-window')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('mini-taskbar')));
      await tester.tap(find.byKey(const ValueKey('mini-taskbar')));
      await tester.pumpAndSettle();
      expect(mini.skipTaskbar, isTrue);
      await tester.tap(find.byTooltip('小窗设置'));
      await tester.pumpAndSettle();
      expect(nativeCalls.last.arguments, isFalse);
      final endPage = _pager(tester).endPage! as ColoredBox;
      expect(endPage.color, Colors.transparent);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await mini.leave();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

void _testWindows(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

final _surface = find.byKey(const ValueKey('reader-page-surface'));
const _capture = bool.fromEnvironment('FQAPP_CAPTURE_LAYOUT');
const _captureBoundary = ValueKey('mini-reader-preview');
ReaderPagedView _pager(WidgetTester tester) =>
    tester.widget<ReaderPagedView>(find.byType(ReaderPagedView));

void _expectAnchor(WidgetTester tester, int anchor) {
  final pager = _pager(tester);
  final page = pager.layout.pages[pager.pageIndex];
  expect(page.start, lessThanOrEqualTo(anchor));
  expect(page.end, greaterThanOrEqualTo(anchor));
}

Widget _app(MemoryReaderStore store) => MaterialApp(
  navigatorKey: DesktopPlatform.navigatorKey,
  theme: ThemeData(fontFamily: _capture ? 'MiniReaderPreview' : null),
  builder: (_, child) => RepaintBoundary(
    key: _captureBoundary,
    child: DesktopAppFrame(child: child!),
  ),
  home: ReaderPage(
    bookId: 'mini-book',
    title: '小窗阅读测试',
    chapters: [Chapter(itemId: 'chapter-1', title: '第一章', volumeName: '正文')],
    startIndex: 0,
    readerStore: store,
    chapterCache: MemoryChapterCache(),
    chapterLoader: (_) async => List.generate(
      80,
      (i) => '第$i段。清晨的风从窗边吹来，带着山间草木的清香。他推开木窗，翻开书，继续读着昨天的故事。',
    ).join('\n'),
  ),
);

Future<void> _capturePreview(WidgetTester tester, String name) async {
  if (!_capture) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureBoundary),
  );
  await tester.runAsync(() async {
    final picture = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/validation/mini-reader/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      picture.dispose();
    }
  });
}
