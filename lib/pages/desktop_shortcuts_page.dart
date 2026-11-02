import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../services/desktop_shortcuts.dart';
import '../services/desktop_mini_reader.dart';
import '../widgets/desktop_shortcut_editor.dart';
import 'settings_category_page.dart';

final desktopShortcutCategory = SettingsCategory(
  icon: LucideIcons.keyboard,
  title: '快捷键',
  subtitle: '阅读、小窗、听书与视频',
  pageBuilder: (_) => const DesktopShortcutsPage(),
  items: const [],
);

class DesktopShortcutsPage extends StatefulWidget {
  const DesktopShortcutsPage({super.key, this.initialGroup});
  final DesktopShortcutGroup? initialGroup;

  @override
  State<DesktopShortcutsPage> createState() => _DesktopShortcutsPageState();
}

class _DesktopShortcutsPageState extends State<DesktopShortcutsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(DesktopShortcuts.instance.load());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('快捷键')),
    body: ListenableBuilder(
      listenable: Listenable.merge([
        DesktopShortcuts.instance,
        DesktopMiniReaderController.instance,
      ]),
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final group in DesktopShortcutGroup.values)
            ExpansionTile(
              key: PageStorageKey(group),
              initiallyExpanded:
                  group ==
                  (widget.initialGroup ?? DesktopShortcutGroup.general),
              title: Text(group.label),
              childrenPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              children: [
                for (final command in DesktopCommand.values.where(
                  (c) => c.group == group,
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(command.label)),
                            Text(
                              command.global ? '全局 · 小窗开启时' : '当前窗口',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        DesktopShortcutEditor(command: command),
                        if (command.global &&
                            DesktopMiniReaderController.instance.active &&
                            !DesktopMiniReaderController
                                .instance
                                .hotkeyAvailable &&
                            DesktopShortcuts.instance.keys(command).isNotEmpty)
                          Text(
                            '按键被其他应用占用，鼠标恢复仍可用',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}
