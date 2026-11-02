import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fqapp/models/media_item.dart';
import 'package:fqapp/pages/library_page.dart';
import 'package:fqapp/pages/home_page.dart';
import 'package:fqapp/pages/home_provider.dart';
import 'package:fqapp/pages/drama_page.dart';
import 'package:fqapp/models/channel_tab.dart';
import 'package:fqapp/services/api_client.dart';
import 'package:fqapp/services/drama_channel_preferences.dart';
import 'package:fqapp/services/app_theme.dart';
import 'package:fqapp/services/library_store.dart';
import 'package:fqapp/services/shelf_store.dart';
import 'package:fqapp/widgets/desktop_app_frame.dart';
import 'package:fqapp/widgets/home/home_design.dart';
import 'package:fqapp/widgets/home/home_skeleton.dart';
import 'dart:async';

const _capture = bool.fromEnvironment('FQAPP_CAPTURE_LAYOUT');
const _boundary = ValueKey('interface-preview');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    if (!_capture) return;
    await (FontLoader('InterfacePreview')..addFont(
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
    SharedPreferences.setMockInitialValues({});
    DramaChannelPreferences.reset();
    directory = await Directory.systemTemp.createTemp('fqapp-interface-');
    Hive.init(directory.path);
    await LibraryStore.instance.init();
    await ShelfStore.instance.init();
    desktopTab.value = 2;
  });

  tearDown(() async {
    desktopTab.value = 0;
    einkModeNotifier.value = false;
    debugDefaultTargetPlatformOverride = null;
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final (name, size, desktop, brightness, scale) in [
    ('desktop', const Size(1280, 800), true, Brightness.light, 1.0),
    ('desktop-dark', const Size(1280, 800), true, Brightness.dark, 1.0),
    ('desktop-compact', const Size(800, 700), true, Brightness.light, 1.0),
    ('mobile', const Size(390, 844), false, Brightness.light, 1.0),
    ('mobile-large-text', const Size(320, 640), false, Brightness.dark, 1.6),
  ]) {
    testWidgets('$name shelf navigation and all layouts fit', (tester) async {
      debugDefaultTargetPlatformOverride = desktop
          ? TargetPlatform.windows
          : TargetPlatform.android;
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.runAsync(() async {
        for (final (index, title) in [
          '山海之间',
          '长安十二时辰',
          '时间深处的来信',
          '漫长的季节',
          '在群星之间旅行',
          '风起时想起你',
          '明天也要好好生活',
          '人间烟火',
          '故事从这里开始',
        ].indexed) {
          await ShelfStore.instance.add(
            MediaItem(
              id: 'preview-$index',
              title: title,
              author: '故事收藏',
              cover: '',
              badge: '',
              ep: '120',
              kind: 'book',
            ),
          );
          await LibraryStore.instance.addHistory({
            'id': 'preview-$index',
            'kind': 'book',
            'title': title,
            'episode': 15 + index,
            'chapterCount': 120,
            'progress': .12 + index * .06,
            'time': DateTime.now().millisecondsSinceEpoch + index,
          });
        }
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.createTheme(brightness).copyWith(
            textTheme: AppTheme.createTheme(
              brightness,
            ).textTheme.apply(fontFamily: _capture ? 'InterfacePreview' : null),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(
              key: _boundary,
              child: desktop ? DesktopAppFrame(child: child!) : child!,
            ),
          ),
          home: const LibraryPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _screenshot(tester, '$name-grid');

      if (desktop) {
        expect(
          tester.getSize(find.byKey(const Key('desktop-navigation'))).width,
          size.width >= 1100 ? 184 : 80,
        );
        await tester.tap(find.byKey(const ValueKey('desktop-tab-0')));
        await tester.pumpAndSettle();
        expect(desktopTab.value, 0);
        await tester.tap(find.byKey(const ValueKey('desktop-tab-2')));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const Key('shelf-layout-double')));
      await tester.pumpAndSettle();
      final grid = tester.widget<GridView>(
        find.byKey(const Key('shelf-double-view')),
      );
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(
        delegate.crossAxisCount,
        desktop && size.width >= 1100 ? greaterThan(2) : 2,
      );
      expect(tester.takeException(), isNull);
      await _screenshot(tester, '$name-double');

      await tester.tap(find.byKey(const Key('shelf-layout-list')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shelf-list-view')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('shelf-layout-grid')));
      await tester.pumpAndSettle();
      if (desktop) {
        await tester.tap(
          find.byKey(const ValueKey('shelf-grid-book:preview-8')),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();
        expect(find.text('已选择 1 本'), findsOneWidget);
        await tester.tap(find.byKey(const Key('shelf-edit-done')));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    });
  }

  for (final (name, size, desktop, brightness, scale) in [
    ('desktop', const Size(1280, 800), true, Brightness.light, 1.0),
    ('desktop-dark', const Size(1280, 800), true, Brightness.dark, 1.0),
    ('desktop-compact', const Size(800, 700), true, Brightness.light, 1.0),
    ('mobile', const Size(390, 844), false, Brightness.light, 1.0),
    ('mobile-large-text', const Size(320, 640), false, Brightness.dark, 1.6),
  ]) {
    for (final drama in [false, true]) {
      testWidgets('$name ${drama ? 'drama' : 'home'} loading and refresh fit', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = desktop
            ? TargetPlatform.windows
            : TargetPlatform.android;
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
        desktopTab.value = drama ? 1 : 0;
        DramaChannelPreferences.selectedType = kChannelVideoEpisode;
        var gate = Completer<void>();
        final titles = [
          '山海之间',
          '长安十二时辰',
          '时间深处的来信',
          '漫长的季节',
          '在群星之间旅行',
          '风起时想起你',
        ];
        final notifier = HomeNotifier(
          initialTabIndex: drama ? HomeNotifier.tabs.indexOf('看剧') : 0,
          usesLocalTabs: true,
          homepageLoader:
              ({int tabType = 2, int offset = 0, String? sessionId}) async {
                await gate.future;
                return HomepagePage(
                  items: [
                    for (var i = 0; i < 18; i++)
                      MediaItem(
                        id: 'feed-$i',
                        title: titles[i % titles.length],
                        cover: '',
                        author: '故事收藏',
                        badge: '',
                        ep: drama ? '全24集' : '',
                        kind: drama ? 'video' : 'book',
                        categories: drama ? ['都市', '悬疑'] : [],
                      ),
                  ],
                  nextOffset: null,
                  sessionId: null,
                );
              },
          searchLoader: (query, {int page = 1}) async => [],
        );
        final theme = AppTheme.createTheme(brightness);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              if (drama)
                dramaProvider.overrideWith(() => notifier)
              else
                homeProvider.overrideWith(() => notifier),
            ],
            child: MaterialApp(
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(
                  fontFamily: _capture ? 'InterfacePreview' : null,
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(
                  key: _boundary,
                  child: desktop ? DesktopAppFrame(child: child!) : child!,
                ),
              ),
              home: drama
                  ? DramaPage(
                      channelLoader: () async =>
                          const ChannelTable(tabs: [], defaultIndex: -1),
                    )
                  : const HomePage(),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(HomeSkeleton), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _screenshot(tester, '$name-${drama ? 'drama' : 'home'}-loading');
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.byType(HomeSkeleton), findsNothing);
        expect(find.text(titles.first), findsWidgets);
        expect(tester.takeException(), isNull);
        await _screenshot(tester, '$name-${drama ? 'drama' : 'home'}');
        gate = Completer<void>();
        final refresh = notifier.load(manualRefresh: true);
        await tester.pump();
        expect(find.byType(HomeSkeleton), findsNothing);
        expect(find.text(titles.first), findsWidgets);
        if (desktop) {
          final refreshButton = tester.widget<IconButton>(
            find.byKey(
              Key(drama ? 'drama_refresh_button' : 'home_refresh_button'),
            ),
          );
          expect(refreshButton.onPressed, isNull);
        }
        gate.complete();
        await refresh;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }

  testWidgets('static skeleton schedules no animation frames', (tester) async {
    for (final eink in [false, true]) {
      einkModeNotifier.value = eink;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: !eink),
            child: const SingleChildScrollView(child: HomeSkeleton()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('motion respects system preference and e-ink mode', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (value) {
              context = value;
              return const HomeEntrance(child: Text('故事'));
            },
          ),
        ),
      ),
    );
    expect(HomeMotion.duration(context, 160), Duration.zero);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(
      HomeMotion.duration(context, 160),
      const Duration(milliseconds: 160),
    );
    einkModeNotifier.value = true;
    expect(HomeMotion.duration(context, 220), Duration.zero);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _screenshot(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/app_logo.webp'),
      tester.element(find.byKey(_boundary)),
    ),
  );
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/validation/interface/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
