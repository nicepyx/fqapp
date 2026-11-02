import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import 'video_player_chrome.dart';

class DesktopMiniVideoCatalog extends StatefulWidget {
  const DesktopMiniVideoCatalog({
    super.key,
    required this.configuration,
    required this.onClose,
    required this.onSelect,
  });

  final VideoPlayerChrome configuration;
  final VoidCallback onClose;
  final ValueChanged<int> onSelect;

  @override
  State<DesktopMiniVideoCatalog> createState() =>
      _DesktopMiniVideoCatalogState();
}

class _DesktopMiniVideoCatalogState extends State<DesktopMiniVideoCatalog> {
  late final _scroll = ScrollController(
    initialScrollOffset: math.max(0, c.currentIndex * 44.0 - 88),
  );
  VideoPlayerChrome get c => widget.configuration;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xfff6f7f8),
    borderRadius: BorderRadius.circular(6),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '选集 · ${c.currentIndex + 1} / ${c.episodes.length}',
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ),
              IconButton(
                tooltip: '关闭选集',
                icon: const Icon(
                  LucideIcons.x,
                  size: 18,
                  color: Colors.black87,
                ),
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
        Expanded(
          child: c.episodes.isEmpty
              ? const Center(
                  child: Text('暂无剧集', style: TextStyle(color: Colors.black54)),
                )
              : ListView.builder(
                  controller: _scroll,
                  itemExtent: 44,
                  itemCount: c.episodes.length,
                  itemBuilder: (context, index) => ListTile(
                    dense: true,
                    selected: index == c.currentIndex,
                    textColor: Colors.black87,
                    selectedColor: const Color(0xffc73e30),
                    selectedTileColor: const Color(0xfffce8e6),
                    title: Text(
                      c.episodes[index].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: index == c.currentIndex
                        ? const Icon(
                            LucideIcons.play,
                            size: 16,
                            color: Color(0xffc73e30),
                          )
                        : null,
                    onTap: () => widget.onSelect(index),
                  ),
                ),
        ),
      ],
    ),
  );
}
