import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fqapp/pages/desktop_shortcuts_page.dart';
import 'package:fqapp/services/desktop_mini_reader.dart';
import 'package:fqapp/services/desktop_shortcuts.dart';
import 'package:fqapp/services/mini_reader_ink.dart';
import 'package:fqapp/widgets/reader/desktop_mini_reader.dart';
import 'package:fqapp/widgets/reader/mini_reader_color_picker.dart';
import 'package:fqapp/widgets/reader/reader_ink_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _capture = bool.fromEnvironment('FQAPP_CAPTURE_LAYOUT');
const _boundary = ValueKey('settings-preview');

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  final mini = DesktopMiniReaderController.instance;
  const channel = MethodChannel('fqapp/mini_reader');
  const windows = MethodChannel('window_manager');
  const screen = MethodChannel('dev.leanflutter.plugins/screen_retriever');
  final calls = <MethodCall>[];
  final windowCalls = <MethodCall>[];
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    if (!_capture) return;
    await (FontLoader('SettingsPreview')..addFont(
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
    await DesktopShortcuts.instance.load();
    calls.clear();
    windowCalls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'enter' || 'setBossKey' => true,
        'windowTargets' => [
          {
            'handle': 12345,
            'title': 'ChatGPT · 测试窗口',
            'application': 'ChatGPT.exe',
          },
        ],
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(windows, (call) async {
      windowCalls.add(call);
      return switch (call.method) {
        'isMaximized' || 'isAlwaysOnTop' || 'isSkipTaskbar' => false,
        'getBounds' => {'x': 0.0, 'y': 0.0, 'width': 1280.0, 'height': 800.0},
        _ => null,
      };
    });
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
    for (final value in [channel, windows, screen]) {
      messenger.setMockMethodCallHandler(value, null);
    }
  });

  test('ink settings survive leaving and entering mini mode', () async {
    await mini.enter();
    const ink = MiniReaderInk(
      color: Colors.green,
      outlineEnabled: true,
      outlineWidth: 1.4,
      outlineColor: Colors.white,
      shadowEnabled: true,
      shadowColor: Colors.red,
      shadowOpacity: .4,
      shadowBlur: 5,
      shadowOffset: 3,
    );
    await mini.setInk(ink);
    await mini.leave();
    await mini.enter();
    expect(mini.ink.toJson(), ink.toJson());
  });

  test(
    'binding uses selected HWND and target close restores pin preference',
    () async {
      await mini.enter();
      final target = (await mini.windowTargets()).single;
      expect(target.application, 'ChatGPT.exe');
      await mini.bindWindow(target);
      expect(mini.boundWindow, target);
      expect(calls.last.method, 'bindWindow');
      expect(calls.last.arguments, 12345);
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('targetClosed'),
        ),
        (_) {},
      );
      expect(mini.boundWindow, isNull);
      expect(windowCalls.last.method, 'setAlwaysOnTop');
      expect(windowCalls.last.arguments, {'isAlwaysOnTop': true});
      expect(mini.active, isTrue);
    },
  );

  test(
    'changing, recording and disabling boss key updates native registration',
    () async {
      await mini.enter();
      final store = DesktopShortcuts.instance;
      await store.setKeys(DesktopCommand.miniBoss, [
        const SingleActivator(LogicalKeyboardKey.f8, control: true),
      ]);
      expect(calls.last.arguments, {'key': 0x77, 'modifiers': 2});
      store.beginRecording(store);
      expect(calls.last.arguments, isNull);
      store.endRecording(store);
      expect(calls.last.arguments, {'key': 0x77, 'modifiers': 2});
      await store.setKeys(DesktopCommand.miniBoss, []);
      expect(calls.last.arguments, isNull);
      expect(mini.bossKeyLabel, '未设置');
    },
  );

  testWidgets('stroke and shadow preserve text layout and semantics', (
    tester,
  ) async {
    var ink = const MiniReaderInk();
    Widget content() => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 180,
          child: ReaderInkText(
            key: const ValueKey('text'),
            span: const TextSpan(
              text: '正文文字跨行显示，描边不能改变分页布局。',
              style: TextStyle(fontSize: 20),
            ),
            ink: ink,
            textScaler: TextScaler.noScaling,
            semanticsLabel: '正文',
          ),
        ),
      ),
    );
    await tester.pumpWidget(content());
    final size = tester.getSize(find.byKey(const ValueKey('text')));
    ink = ink.copyWith(
      outlineEnabled: true,
      outlineWidth: 1.5,
      shadowEnabled: true,
    );
    await tester.pumpWidget(content());
    expect(tester.getSize(find.byKey(const ValueKey('text'))), size);
    final rich = tester.widgetList<RichText>(find.byType(RichText)).toList();
    expect(rich.length, 2);
    final stroke = rich.first.text as TextSpan;
    final fill = rich.last.text as TextSpan;
    expect(stroke.style!.foreground!.style, PaintingStyle.stroke);
    expect(stroke.style!.foreground!.strokeWidth, 3);
    expect(fill.style!.color, ink.color);
    expect(fill.style!.shadows!.single.blurRadius, ink.shadowBlur);
    expect(find.byType(ExcludeSemantics), findsWidgets);
  });

  testWidgets('mini appearance controls refresh and preserve preceding edits', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(460, 620));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mini.enter();
    await tester.pumpWidget(
      _app(
        ListenableBuilder(
          listenable: mini,
          builder: (_, _) => DesktopMiniReader(
            title: '测试章节',
            progress: .25,
            fontSize: 18,
            onFontSizeChanged: (_) {},
            onTurnPage: (_) async {},
            onDirectory: () async {},
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('小窗设置'));
    await tester.pumpAndSettle();
    const color = Color(0xff52b788);
    final swatch = find.byKey(ValueKey('文字颜色-${color.toARGB32()}'));
    await tester.ensureVisible(swatch);
    await tester.tap(swatch);
    await tester.pumpAndSettle();
    final outline = find.byKey(const ValueKey('mini-outline-enabled'));
    await tester.ensureVisible(outline);
    await tester.tap(outline);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(outline).value, isTrue);
    expect(mini.ink.color, color);
    expect(find.byKey(const ValueKey('描边粗细')), findsOneWidget);
    final shadow = find.byKey(const ValueKey('mini-shadow-enabled'));
    await tester.ensureVisible(shadow);
    await tester.tap(shadow);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(shadow).value, isTrue);
    expect(mini.ink.outlineEnabled, isTrue);
    expect(mini.ink.color, color);
    final blur = find.byKey(const ValueKey('阴影模糊'));
    await tester.ensureVisible(blur);
    await tester.drag(blur, const Offset(36, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(blur).value, mini.ink.shadowBlur);
    expect(mini.ink.shadowBlur, isNot(2));
    for (final preview in tester.widgetList<ReaderInkText>(
      find.byType(ReaderInkText),
    )) {
      expect(preview.ink.toJson(), mini.ink.toJson());
    }
    final saved = mini.ink.toJson();
    await tester.pumpWidget(const SizedBox.shrink());
    await mini.leave();
    await mini.enter();
    expect(mini.ink.toJson(), saved);
  });

  testWidgets('custom color dialog validates HEX and fits minimum window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 280));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mini.enter();
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: MiniReaderColorPicker(
            label: '文字颜色',
            value: mini.ink.color,
            onChanged: (color) => mini.setInk(mini.ink.copyWith(color: color)),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('自定义文字颜色'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '确定'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '35AA99');
    await tester.pumpAndSettle();
    await _screenshot(tester, 'custom-color-minimum');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(mini.ink.color, const Color(0xff35aa99));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [const Size(460, 620), const Size(320, 280)]) {
    testWidgets('mini settings and effects fit $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mini.enter();
      await mini.setInk(
        const MiniReaderInk(outlineEnabled: true, shadowEnabled: true),
      );
      await tester.pumpWidget(
        _app(
          ListenableBuilder(
            listenable: mini,
            builder: (_, _) => DesktopMiniReader(
              title: '第一章：清晨的故事',
              progress: .25,
              fontSize: 18,
              onFontSizeChanged: (_) {},
              onTurnPage: (_) async {},
              onDirectory: () async {},
              child: const ReaderInkText(
                span: TextSpan(
                  text: '清晨的风从窗边吹来，带着山间草木的清香。\n他推开木窗，翻开书，继续读着昨天的故事。',
                  style: TextStyle(fontSize: 18, height: 1.8),
                ),
                ink: MiniReaderInk(outlineEnabled: true, shadowEnabled: true),
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _screenshot(tester, 'effects-${size.width.toInt()}');
      await tester.tap(find.byTooltip('小窗设置'));
      await tester.pumpAndSettle();
      await _screenshot(tester, 'ink-settings-${size.width.toInt()}');
      await tester.ensureVisible(find.byKey(const ValueKey('阴影偏移')));
      await tester.pumpAndSettle();
      await _screenshot(tester, 'shadow-settings-${size.width.toInt()}');
      await tester.tap(find.byKey(const ValueKey('mini-settings-window')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('绑定应用窗口'));
      await tester.tap(find.text('绑定应用窗口'));
      await tester.pumpAndSettle();
      await _screenshot(tester, 'binding-picker-${size.width.toInt()}');
      await tester.tap(find.text('ChatGPT · 测试窗口'));
      await tester.pumpAndSettle();
      expect(mini.boundWindow?.handle, 12345);
      expect(find.text('ChatGPT · 测试窗口'), findsOneWidget);
      final unlink = find.byTooltip('解除绑定');
      await tester.ensureVisible(unlink);
      await tester.tap(unlink);
      await tester.pumpAndSettle();
      expect(find.text('未绑定'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final size in [const Size(900, 700), const Size(320, 480)]) {
    testWidgets('shortcut groups and controls fit $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          const DesktopShortcutsPage(initialGroup: DesktopShortcutGroup.mini),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('通用'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('shortcut-miniBoss-0')),
        180,
      );
      await tester.pumpAndSettle();
      await _screenshot(tester, 'shortcuts-${size.width.toInt()}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Widget _app(Widget home) => MaterialApp(
  theme: ThemeData(fontFamily: _capture ? 'SettingsPreview' : null),
  builder: (_, child) => RepaintBoundary(key: _boundary, child: child!),
  home: home,
);

Future<void> _screenshot(WidgetTester tester, String name) async {
  if (!_capture) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/validation/mini-reader/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
