import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/media_item.dart';
import '../services/desktop_mini_reader.dart';
import '../services/desktop_platform.dart';
import '../services/desktop_shortcuts.dart';
import 'desktop_chapter_sidebar.dart';

class DesktopReaderFrame extends StatelessWidget {
  const DesktopReaderFrame({
    super.key,
    required this.chapters,
    required this.currentIndex,
    required this.backgroundColor,
    required this.onChapterSelected,
    required this.onTurnPage,
    required this.onPointerSignal,
    required this.child,
    this.onDirectory,
    this.onAppearance,
    this.onMini,
  });

  final List<Chapter> chapters;
  final int currentIndex;
  final Color backgroundColor;
  final ValueChanged<int> onChapterSelected;
  final Future<void> Function(int) onTurnPage;
  final void Function(PointerSignalEvent) onPointerSignal;
  final Widget child;
  final VoidCallback? onDirectory, onAppearance, onMini;

  @override
  Widget build(BuildContext context) {
    final mini = DesktopMiniReaderController.instance.readerActive;
    return LayoutBuilder(
      builder: (context, bounds) => ColoredBox(
        color: mini ? Colors.transparent : backgroundColor,
        child: Row(
          children: [
            if (!mini && bounds.maxWidth >= 1000)
              DesktopChapterSidebar(
                chapters: chapters,
                currentIndex: currentIndex,
                onSelected: onChapterSelected,
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Focus(
                        autofocus: true,
                        onKeyEvent: _onKeyEvent,
                        child: Builder(
                          builder: (context) => Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (_) {
                              if (mini &&
                                  !DesktopMiniReaderController
                                      .instance
                                      .menuOpen) {
                                Focus.of(context).requestFocus();
                              }
                            },
                            onPointerSignal: onPointerSignal,
                            child: child,
                          ),
                        ),
                      ),
                      if (!mini)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ValueListenableBuilder<double>(
                              valueListenable: DesktopPlatform.readerBrightness,
                              builder: (_, brightness, _) => ColoredBox(
                                color: Colors.black.withValues(
                                  alpha: 1 - brightness,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<EditableText>() !=
            null) {
      return KeyEventResult.ignored;
    }
    final mini = DesktopMiniReaderController.instance;
    if (mini.readerActive &&
        (mini.menuOpen ||
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return KeyEventResult.ignored;
    }
    final command = DesktopShortcuts.instance.match(
      mini.readerActive
          ? DesktopShortcutGroup.mini
          : DesktopShortcutGroup.reader,
      event,
    );
    if (command == DesktopCommand.readerNext ||
        command == DesktopCommand.miniNext) {
      unawaited(onTurnPage(1));
      return KeyEventResult.handled;
    }
    if (command == DesktopCommand.readerPrevious ||
        command == DesktopCommand.miniPrevious) {
      unawaited(onTurnPage(-1));
      return KeyEventResult.handled;
    }
    final action = switch (command) {
      DesktopCommand.readerDirectory => onDirectory,
      DesktopCommand.readerAppearance => onAppearance,
      DesktopCommand.readerMini => onMini,
      _ => null,
    };
    if (action != null) {
      action();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}
