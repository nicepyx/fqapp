import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../pages/search_page.dart';
import '../pages/settings_page.dart';
import '../services/desktop_platform.dart';
import '../services/desktop_mini_reader.dart';
import '../services/desktop_shortcuts.dart';
import 'desktop_shortcut_scope.dart';
import 'home/home_design.dart';

final desktopTab = ValueNotifier<int>(0);

class DesktopAppFrame extends StatelessWidget {
  const DesktopAppFrame({super.key, required this.child});
  static final _windowModeChanges = Listenable.merge([
    DesktopPlatform.fullscreen,
    DesktopMiniReaderController.instance,
  ]);
  bool get _readerOnly =>
      DesktopPlatform.fullscreen.value ||
      DesktopMiniReaderController.instance.active;
  final Widget child;
  void _select(int index) {
    DesktopPlatform.navigatorKey.currentState?.popUntil(
      (route) => route.isFirst,
    );
    desktopTab.value = index;
  }

  void _search(String query) {
    DesktopPlatform.navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => SearchPage(initialQuery: query.isEmpty ? null : query),
      ),
    );
  }

  void _settings() => DesktopPlatform.navigatorKey.currentState?.push(
    MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
  );

  @override
  // MaterialApp.builder is above its Navigator. The frame's own tooltips need
  // an overlay here; the page Navigator below cannot host a sibling's tooltip.
  Widget build(BuildContext context) => DesktopShortcutScope(
    group: DesktopShortcutGroup.general,
    actions: {
      if (!DesktopMiniReaderController.instance.active) ...{
        DesktopCommand.search: () => _search(''),
        DesktopCommand.settings: _settings,
        DesktopCommand.back: () =>
            DesktopPlatform.navigatorKey.currentState?.maybePop(),
      },
    },
    child: _frame(context),
  );

  Widget _frame(BuildContext context) => Overlay.wrap(
    child: ListenableBuilder(
      listenable: _windowModeChanges,
      builder: (context, _) {
        if (_readerOnly) return child;
        final palette = HomePalette.of(context);
        return LayoutBuilder(
          builder: (context, constraints) {
            final expanded = constraints.maxWidth >= 1100;
            return Material(
              color: palette.canvas,
              child: Row(
                children: [
                  _sidebar(context, palette, expanded),
                  VerticalDivider(width: 1, color: palette.line),
                  Expanded(
                    child: Column(
                      children: [
                        _header(palette, expanded),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );

  Widget _sidebar(BuildContext context, HomePalette palette, bool expanded) =>
      SizedBox(
        key: const Key('desktop-navigation'),
        width: expanded ? 184 : 80,
        child: ColoredBox(
          color: palette.surface,
          child: Column(
            children: [
              SizedBox(
                height: 72,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/images/app_logo.webp',
                        width: 32,
                        height: 32,
                      ),
                    ),
                    if (expanded) ...[
                      const SizedBox(width: 12),
                      Text(
                        '什锦铺',
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ValueListenableBuilder<int>(
                    valueListenable: desktopTab,
                    builder: (context, selected, _) => Column(
                      children: [
                        for (final (index, icon, label) in const [
                          (0, LucideIcons.house, '首页'),
                          (1, LucideIcons.clapperboard, '短剧'),
                          (2, LucideIcons.library_big, '书架'),
                          (3, LucideIcons.circle_user_round, '我的'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _DesktopDestination(
                              key: ValueKey('desktop-tab-$index'),
                              icon: icon,
                              label: label,
                              selected: selected == index,
                              expanded: expanded,
                              onTap: () => _select(index),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: _DesktopDestination(
                  key: const Key('desktop-settings'),
                  icon: LucideIcons.settings,
                  label: '设置',
                  expanded: expanded,
                  onTap: _settings,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _header(HomePalette palette, bool expanded) => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: palette.surface,
      border: Border(bottom: BorderSide(color: palette.line)),
    ),
    child: ValueListenableBuilder<int>(
      valueListenable: desktopTab,
      builder: (context, tab, _) => Row(
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: () =>
                DesktopPlatform.navigatorKey.currentState?.maybePop(),
            style: IconButton.styleFrom(
              foregroundColor: palette.muted,
              minimumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(LucideIcons.arrow_left, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            expanded ? const ['首页', '短剧', '书架', '我的'][tab] : '什锦铺',
            style: TextStyle(
              color: palette.ink,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            // 短剧页已有独立搜索，壳层只为其它分区提供搜索入口。
            child: tab == 1
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: TextField(
                        key: const Key('desktop-search'),
                        onSubmitted: _search,
                        style: TextStyle(fontSize: 13, color: palette.ink),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: '搜索作品、作者或作品 ID',
                          hintStyle: TextStyle(color: palette.muted),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          prefixIcon: Icon(
                            LucideIcons.search,
                            size: 17,
                            color: palette.muted,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 38,
                            minHeight: 36,
                          ),
                          filled: true,
                          fillColor: palette.canvas,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: palette.line),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: palette.accentText),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

class _DesktopDestination extends StatelessWidget {
  const _DesktopDestination({
    super.key,
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);
    final foreground = selected ? palette.accentText : palette.muted;
    return Semantics(
      selected: selected,
      button: true,
      child: Tooltip(
        message: label,
        child: Material(
          animationDuration: HomeMotion.duration(context, 160),
          color: selected ? palette.soft : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            hoverColor: palette.ink.withValues(alpha: .05),
            focusColor: palette.accentText.withValues(alpha: .12),
            child: SizedBox(
              height: expanded ? 44 : 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    child: AnimatedContainer(
                      duration: HomeMotion.duration(context, 160),
                      width: 3,
                      height: selected ? 18 : 0,
                      decoration: BoxDecoration(
                        color: palette.accentText,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (expanded)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(icon, size: 20, color: foreground),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 20, color: foreground),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: TextStyle(fontSize: 11, color: foreground),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
