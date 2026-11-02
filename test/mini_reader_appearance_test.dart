import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fqapp/models/media_item.dart';
import 'package:fqapp/pages/reader_page.dart';
import 'package:fqapp/services/desktop_mini_reader.dart';
import 'package:fqapp/services/desktop_platform.dart';
import 'package:fqapp/services/reader_preferences.dart';
import 'package:fqapp/widgets/desktop_app_frame.dart';
import 'package:fqapp/widgets/reader/reader_ink_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  final mini = DesktopMiniReaderController.instance;
  const native = MethodChannel('fqapp/mini_reader');
  const windows = MethodChannel('window_manager');
  const screen = MethodChannel('dev.leanflutter.plugins/screen_retriever');
  SharedPreferences.setMockInitialValues({});
  setUp(() async {
    await (await SharedPreferences.getInstance()).clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    messenger.setMockMethodCallHandler(
      native,
      (call) async => switch (call.method) {
        'enter' || 'setBossKey' => true,
        _ => null,
      },
    );
    messenger.setMockMethodCallHandler(
      windows,
      (call) async => switch (call.method) {
        'isMaximized' || 'isAlwaysOnTop' || 'isSkipTaskbar' => false,
        'getBounds' => {'x': 0.0, 'y': 0.0, 'width': 1280.0, 'height': 800.0},
        _ => null,
      },
    );
    messenger.setMockMethodCallHandler(
      screen,
      (_) async => {
        'id': 'primary',
        'size': {'width': 1920.0, 'height': 1080.0},
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

  for (final mode in ReaderPageMode.values) {
    testWidgets('appearance controls update actual $mode reader text', (
      tester,
    ) async {
      await ReaderPreferences(
        pageMode: mode,
        keepScreenOn: false,
        showParagraphBubbles: false,
      ).save();
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: DesktopPlatform.navigatorKey,
          builder: (_, child) => DesktopAppFrame(child: child!),
          home: ReaderPage(
            bookId: 'appearance-book',
            title: '文字外观测试',
            startIndex: 0,
            chapters: [
              Chapter(itemId: 'chapter-1', title: '第一章', volumeName: ''),
            ],
            readerStore: MemoryReaderStore(),
            chapterCache: MemoryChapterCache(),
            chapterLoader: (_) async =>
                List.filled(30, '清晨的风带着草木的清香，他翻开书，继续昨天的故事。').join('\n'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await mini.enter();
      await tester.binding.setSurfaceSize(const Size(460, 620));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('小窗设置'));
      await tester.pumpAndSettle();
      const color = Color(0xffe05263);
      final swatch = find.byKey(ValueKey('文字颜色-${color.toARGB32()}'));
      await tester.ensureVisible(swatch);
      await tester.tap(swatch);
      await tester.pumpAndSettle();
      for (final name in ['mini-outline-enabled', 'mini-shadow-enabled']) {
        final toggle = find.byKey(ValueKey(name));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      }
      final paragraphs = find.byWidgetPredicate(
        (w) =>
            w is ReaderInkText && (w.semanticsLabel?.contains('草木') ?? false),
      );
      expect(paragraphs, findsWidgets);
      for (final text in tester.widgetList<ReaderInkText>(paragraphs)) {
        expect(text.ink.color, color);
        expect(text.ink.outlineEnabled, isTrue);
        expect(text.ink.shadowEnabled, isTrue);
      }
      final paints = tester
          .widgetList<RichText>(
            find.descendant(
              of: paragraphs.first,
              matching: find.byType(RichText),
            ),
          )
          .map((w) => w.text as TextSpan)
          .toList();
      expect(paints.first.style!.foreground!.style, PaintingStyle.stroke);
      expect(paints.last.style!.color, color);
      expect(paints.last.style!.shadows, hasLength(1));
      await tester.tap(find.byTooltip('小窗设置'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
