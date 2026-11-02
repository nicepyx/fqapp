import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fqapp/pages/desktop_shortcuts_page.dart';
import 'package:fqapp/services/desktop_mini_reader.dart';
import 'package:fqapp/services/desktop_shortcuts.dart';
import 'package:fqapp/widgets/reader/desktop_mini_reader.dart';
import 'package:fqapp/widgets/reader/reader_ink_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _capture = bool.fromEnvironment('FQAPP_CAPTURE_LAYOUT');
const _boundary = ValueKey('interaction-preview');
final _mini = DesktopMiniReaderController.instance;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  const native = MethodChannel('fqapp/mini_reader');
  const windows = MethodChannel('window_manager');
  const screen = MethodChannel('dev.leanflutter.plugins/screen_retriever');
  final calls = <MethodCall>[];
  var failTargets = false;
  var unavailable = false;
  var targets = <Map<String, Object>>[];
  SharedPreferences.setMockInitialValues({});
  setUpAll(() async {
    if (!_capture) return;
    await (FontLoader('InteractionPreview')..addFont(
          File(
            r'C:\Windows\Fonts\msyh.ttc',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
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
    failTargets = false;
    unavailable = false;
    targets = [
      {'handle': 678, 'title': '测试应用窗口', 'application': 'example.exe'},
    ];
    calls.clear();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    messenger.setMockMethodCallHandler(native, (call) async {
      calls.add(call);
      if (call.method == 'windowTargets') {
        if (failTargets) throw PlatformException(code: 'failed');
        return targets;
      }
      if (call.method == 'bindWindow' && unavailable) {
        throw PlatformException(code: 'window_unavailable');
      }
      return switch (call.method) {
        'enter' || 'setBossKey' => true,
        _ => null,
      };
    });
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
    await _mini.leave();
    for (final channel in [native, windows, screen]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'settings contrast remains readable with $brightness app and either preset',
      (tester) async {
        await _mount(tester, brightness: brightness);
        final panel = find.byKey(const ValueKey('mini-settings-panel'));
        final background = tester.widget<Material>(panel).color!;
        for (final light in [false, true]) {
          await _tap(tester, find.byKey(ValueKey('mini-text-$light')));
          expect(tester.widget<Material>(panel).color, background);
          for (final label in ['小窗设置', '文字外观', '深浅预设', '字号', '背景', '文字颜色']) {
            final text = tester.renderObject<RenderParagraph>(find.text(label));
            final color = (text.text as TextSpan).style!.color!;
            expect(
              _contrast(background, color),
              greaterThanOrEqualTo(4.5),
              reason: label,
            );
          }
          final previews = tester.widgetList<ReaderInkText>(
            find.byType(ReaderInkText),
          );
          expect(previews, hasLength(2));
          expect(previews.every((w) => w.ink.color == _mini.ink.color), isTrue);
          await _captureImage(tester, 'contrast-${brightness.name}-$light');
        }
        const color = Color(0xff52b788);
        await _tap(tester, find.byKey(ValueKey('文字颜色-${color.toARGB32()}')));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('mini-text-true')),
            matching: find.byType(Icon),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('mini-text-false')),
            matching: find.byType(Icon),
          ),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'all effect sliders preserve other settings and on-screen values',
    (tester) async {
      await _mount(tester);
      await _tap(tester, find.byKey(const ValueKey('mini-outline-enabled')));
      await _tap(tester, find.byKey(const ValueKey('mini-shadow-enabled')));
      for (final name in ['描边粗细', '阴影强度', '阴影模糊', '阴影偏移']) {
        final slider = find.byKey(ValueKey(name));
        await tester.ensureVisible(slider);
        await tester.pumpAndSettle();
        final before = tester.widget<Slider>(slider).value;
        await tester.drag(slider, const Offset(30, 0));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Slider>(slider).value,
          isNot(before),
          reason: name,
        );
        expect(_mini.ink.outlineEnabled && _mini.ink.shadowEnabled, isTrue);
      }
      final saved = _mini.ink.toJson();
      await tester.pumpWidget(const SizedBox.shrink());
      await _mini.leave();
      await _mini.enter();
      expect(_mini.ink.toJson(), saved);
    },
  );

  testWidgets(
    'custom color supports HEX paste, Enter, slider adjustment and cancel',
    (tester) async {
      await _mount(tester);
      await _tap(tester, find.byTooltip('自定义文字颜色'));
      await tester.enterText(find.byType(TextField), '#35AA99');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_mini.ink.color, const Color(0xff35aa99));
      await _tap(tester, find.byTooltip('自定义文字颜色'));
      await tester.enterText(find.byType(TextField), '123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      final hue = find.byKey(const ValueKey('color-色相'));
      await tester.ensureVisible(hue);
      await tester.drag(hue, const Offset(30, 0));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byType(TextField))
            .controller!
            .text
            .length,
        6,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '确定'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(_mini.ink.color, const Color(0xff35aa99));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Escape cancels key capture first, then closes settings; close stays reachable',
    (tester) async {
      await _mount(tester);
      final input = find.byKey(const ValueKey('shortcut-miniNext-0'));
      await _tap(tester, find.byKey(const ValueKey('mini-settings-keys')));
      await _tap(tester, input);
      expect(DesktopShortcuts.instance.recording, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(DesktopShortcuts.instance.recording, isFalse);
      expect(find.byKey(const ValueKey('mini-settings-panel')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mini-settings-panel')), findsNothing);
      expect(_mini.active, isTrue);
      expect(_mini.menuOpen, isFalse);
      await tester.tap(find.byTooltip('小窗设置'));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('mini-settings-keys')));
      await tester.ensureVisible(find.text('管理所有快捷键'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭小窗设置'));
      await tester.pumpAndSettle();
      expect(_mini.menuOpen, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'font bounds, background and taskbar controls work without changing panel colors',
    (tester) async {
      await _mount(tester);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == '缩小字号',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('增大字号'));
      await tester.pumpAndSettle();
      expect(find.text('15'), findsOneWidget);
      for (var size = 15; size < 32; size++) {
        await tester.tap(find.byTooltip('增大字号'));
        await tester.pumpAndSettle();
      }
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == '增大字号',
              ),
            )
            .onPressed,
        isNull,
      );
      final background = find.byKey(const ValueKey('mini-background-opacity'));
      await tester.drag(background, const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(_mini.backgroundOpacity, greaterThan(0));
      final material = tester.widget<Material>(
        find.byKey(const ValueKey('mini-settings-panel')),
      );
      expect(material.color!.a, 1);
      await _tap(tester, find.byKey(const ValueKey('mini-settings-window')));
      await _tap(tester, find.byKey(const ValueKey('mini-taskbar')));
      expect(_mini.skipTaskbar, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'window picker handles errors, empty refresh, unavailable selection and retry',
    (tester) async {
      await _mount(tester);
      failTargets = true;
      await _tap(tester, find.byKey(const ValueKey('mini-settings-window')));
      await _tap(tester, find.text('绑定应用窗口'));
      expect(find.text('无法获取窗口列表，请重试'), findsOneWidget);
      failTargets = false;
      targets = [];
      await tester.tap(find.byTooltip('刷新窗口列表'));
      await tester.pumpAndSettle();
      expect(find.text('没有可绑定的应用窗口'), findsOneWidget);
      targets = [
        {'handle': 678, 'title': '测试应用窗口', 'application': 'example.exe'},
      ];
      await tester.tap(find.byTooltip('刷新窗口列表'));
      await tester.pumpAndSettle();
      unavailable = true;
      await tester.tap(find.text('测试应用窗口'));
      await tester.pumpAndSettle();
      expect(_mini.boundWindow, isNull);
      expect(find.text('目标窗口不可用，请刷新后重新选择'), findsOneWidget);
      unavailable = false;
      await _tap(tester, find.text('绑定应用窗口'));
      await tester.tap(find.text('测试应用窗口'));
      await tester.pumpAndSettle();
      expect(_mini.boundWindow?.handle, 678);
      await _tap(tester, find.byTooltip('解除绑定'));
      expect(_mini.boundWindow, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'shortcut management restores open menu on return and header toggles work',
    (tester) async {
      await _mount(tester);
      await _tap(tester, find.byKey(const ValueKey('mini-settings-keys')));
      await _tap(tester, find.text('管理所有快捷键'));
      expect(find.byType(DesktopShortcutsPage), findsOneWidget);
      expect(_mini.menuOpen, isTrue);
      final pageContext = tester.element(find.byType(DesktopShortcutsPage));
      Navigator.of(pageContext).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mini-settings-panel')), findsOneWidget);
      await tester.tap(find.byTooltip('关闭小窗设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('鼠标移开时隐身'));
      await tester.pumpAndSettle();
      expect(_mini.hoverHide, isTrue);
      expect(
        calls.any((c) => c.method == 'setHoverHide' && c.arguments == true),
        isTrue,
      );
      await tester.tap(find.byTooltip('窗口置顶'));
      await tester.pumpAndSettle();
      expect(_mini.pinned, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> _mount(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.binding.setSurfaceSize(const Size(460, 620));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await _mini.enter();
  var fontSize = 14.0;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        fontFamily: _capture ? 'InteractionPreview' : null,
      ),
      builder: (_, child) => RepaintBoundary(key: _boundary, child: child!),
      home: StatefulBuilder(
        builder: (context, setState) => ListenableBuilder(
          listenable: _mini,
          builder: (_, _) => DesktopMiniReader(
            title: '第一章',
            progress: .25,
            fontSize: fontSize,
            onFontSizeChanged: (v) => setState(() => fontSize = v),
            onTurnPage: (_) async {},
            onDirectory: () async {},
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('小窗设置'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

double _contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
}

Future<void> _captureImage(WidgetTester tester, String name) async {
  if (!_capture) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/validation/mini-reader/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
