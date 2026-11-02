import 'package:flutter/material.dart';

import '../services/desktop_shortcuts.dart';
import '../services/desktop_mini_reader.dart';

class DesktopShortcutScope extends StatelessWidget {
  const DesktopShortcutScope({
    super.key,
    required this.group,
    required this.actions,
    required this.child,
  });
  final DesktopShortcutGroup group;
  final Map<DesktopCommand, VoidCallback> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: (_, event) {
      if (group == DesktopShortcutGroup.general &&
          DesktopMiniReaderController.instance.active) {
        return KeyEventResult.ignored;
      }
      if (WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.inactive ||
          ModalRoute.of(context)?.isCurrent == false ||
          FocusManager.instance.primaryFocus?.context
                  ?.findAncestorWidgetOfExactType<EditableText>() !=
              null) {
        return KeyEventResult.ignored;
      }
      final command = DesktopShortcuts.instance.match(group, event);
      final action = actions[command];
      if (action == null) return KeyEventResult.ignored;
      action();
      return KeyEventResult.handled;
    },
    child: child,
  );
}
