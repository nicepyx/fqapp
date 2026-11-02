import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../services/desktop_mini_reader.dart';
import '../../services/desktop_window_target.dart';

class MiniReaderBindingSettings extends StatelessWidget {
  const MiniReaderBindingSettings({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: DesktopMiniReaderController.instance,
    builder: (context, _) {
      final controller = DesktopMiniReaderController.instance;
      final target = controller.boundWindow;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(LucideIcons.app_window, size: 18),
        title: const Text('绑定应用窗口', style: TextStyle(fontSize: 14)),
        subtitle: Text(
          target?.title ?? '未绑定',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: target == null
            ? const Icon(LucideIcons.chevron_right, size: 18)
            : IconButton(
                tooltip: '解除绑定',
                icon: const Icon(LucideIcons.unlink, size: 18),
                onPressed: () => controller.bindWindow(null),
              ),
        onTap: () async {
          final selected = await showDialog<DesktopWindowTarget>(
            context: context,
            builder: (_) => const _WindowPicker(),
          );
          if (selected == null) return;
          try {
            await controller.bindWindow(selected);
          } catch (error) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('目标窗口不可用，请刷新后重新选择')));
          }
        },
      );
    },
  );
}

class _WindowPicker extends StatefulWidget {
  const _WindowPicker();
  @override
  State<_WindowPicker> createState() => _WindowPickerState();
}

class _WindowPickerState extends State<_WindowPicker> {
  late Future<List<DesktopWindowTarget>> _targets = DesktopMiniReaderController
      .instance
      .windowTargets();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        const Expanded(child: Text('选择应用窗口')),
        IconButton(
          tooltip: '刷新窗口列表',
          icon: const Icon(LucideIcons.refresh_cw, size: 18),
          onPressed: () => setState(() {
            _targets = DesktopMiniReaderController.instance.windowTargets();
          }),
        ),
      ],
    ),
    content: SizedBox(
      width: 460,
      height: 340,
      child: FutureBuilder<List<DesktopWindowTarget>>(
        future: _targets,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('无法获取窗口列表，请重试'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final targets = snapshot.data!;
          if (targets.isEmpty) return const Center(child: Text('没有可绑定的应用窗口'));
          return ListView.builder(
            itemCount: targets.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(
                targets[index].title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(targets[index].application),
              onTap: () => Navigator.pop(context, targets[index]),
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
    ],
  );
}
