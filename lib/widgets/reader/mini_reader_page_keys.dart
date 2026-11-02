import 'package:flutter/material.dart';

import '../../services/desktop_shortcuts.dart';
import '../desktop_shortcut_editor.dart';

class MiniReaderPageKeys extends StatelessWidget {
  const MiniReaderPageKeys({super.key});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final direction in [-1, 1]) ...[
        if (direction > 0) const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                direction < 0 ? '上一页' : '下一页',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 6),
              KeyedSubtree(
                key: ValueKey('mini-page-key-$direction'),
                child: DesktopShortcutEditor(
                  command: direction < 0
                      ? DesktopCommand.miniPrevious
                      : DesktopCommand.miniNext,
                  primaryOnly: true,
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
