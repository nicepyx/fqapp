import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../services/desktop_shortcuts.dart';

class DesktopShortcutEditor extends StatefulWidget {
  const DesktopShortcutEditor({
    super.key,
    required this.command,
    this.primaryOnly = false,
  });
  final DesktopCommand command;
  final bool primaryOnly;

  @override
  State<DesktopShortcutEditor> createState() => _DesktopShortcutEditorState();
}

class _DesktopShortcutEditorState extends State<DesktopShortcutEditor> {
  final _focus = FocusNode();
  final _store = DesktopShortcuts.instance;
  int? _recording;
  String? _error;

  @override
  void dispose() {
    if (_recording != null) _store.endRecording(this);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _store,
    builder: (context, _) => Focus(
      focusNode: _focus,
      onFocusChange: (focused) {
        if (!focused && _recording != null) _finish();
      },
      onKeyEvent: _recordKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (
                var i = 0;
                i <
                    (widget.primaryOnly
                        ? 1
                        : _store.keys(widget.command).length);
                i++
              )
                _keyInput(i),
              if (!widget.primaryOnly) ...[
                IconButton(
                  tooltip: '添加按键',
                  icon: const Icon(LucideIcons.plus, size: 18),
                  onPressed:
                      widget.command.global &&
                          _store.keys(widget.command).isNotEmpty
                      ? null
                      : () => _start(_store.keys(widget.command).length),
                ),
                IconButton(
                  tooltip: '恢复默认',
                  icon: const Icon(LucideIcons.rotate_ccw, size: 18),
                  onPressed: () => _restore(),
                ),
              ],
            ],
          ),
          if (_recording != null &&
              _recording == _store.keys(widget.command).length)
            const Text('按下新按键', style: TextStyle(fontSize: 12)),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
        ],
      ),
    ),
  );

  Widget _keyInput(int index) {
    final keys = _store.keys(widget.command);
    final text = _recording == index
        ? '按下新按键'
        : index < keys.length
        ? DesktopShortcuts.label(keys[index])
        : '未设置';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Tooltip(
        message: text,
        child: InkWell(
          key: ValueKey('shortcut-${widget.command.name}-$index'),
          onTap: () => _start(index),
          child: InputDecorator(
            isFocused: _recording == index,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 24,
              ),
              suffixIcon: widget.primaryOnly
                  ? const Icon(LucideIcons.keyboard, size: 16)
                  : IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: '移除按键',
                      icon: const Icon(LucideIcons.x, size: 14),
                      onPressed: () => unawaited(
                        _store.setKeys(
                          widget.command,
                          [...keys]..removeAt(index),
                        ),
                      ),
                    ),
            ),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  void _start(int index) {
    setState(() {
      _recording = index;
      _error = null;
    });
    _store.beginRecording(this);
    _focus.requestFocus();
  }

  void _finish() {
    _store.endRecording(this);
    setState(() {
      _recording = null;
      _error = null;
    });
  }

  void _restore() {
    for (final key in widget.command.defaults) {
      final conflict = _store.conflict(widget.command, key);
      if (conflict != null) {
        setState(
          () => _error = '默认键已用于${conflict.group.label}：${conflict.label}',
        );
        return;
      }
    }
    setState(() => _error = null);
    unawaited(_store.setKeys(widget.command, widget.command.defaults));
  }

  KeyEventResult _recordKey(FocusNode _, KeyEvent event) {
    if (_recording == null) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape &&
        widget.command != DesktopCommand.videoExitFullscreen) {
      _finish();
      return KeyEventResult.handled;
    }
    if (LogicalKeyboardKey.collapseSynonyms({key}).any(
      (k) => const [
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.alt,
        LogicalKeyboardKey.shift,
        LogicalKeyboardKey.meta,
      ].contains(k),
    )) {
      return KeyEventResult.handled;
    }
    final keyboard = HardwareKeyboard.instance;
    final value = SingleActivator(
      key,
      control: keyboard.isControlPressed,
      alt: keyboard.isAltPressed,
      shift: keyboard.isShiftPressed,
      meta: keyboard.isMetaPressed,
    );
    final conflict = _store.conflict(widget.command, value);
    if (conflict != null) {
      setState(() => _error = '已用于${conflict.group.label}：${conflict.label}');
      return KeyEventResult.handled;
    }
    if (widget.command.global &&
        DesktopShortcuts.windowsHotkey(value) == null) {
      setState(() => _error = '此按键无法注册为全局快捷键');
      return KeyEventResult.handled;
    }
    final values = [..._store.keys(widget.command)];
    if (_recording! < values.length) {
      values[_recording!] = value;
    } else {
      values.add(value);
    }
    unawaited(_store.setKeys(widget.command, values));
    _finish();
    return KeyEventResult.handled;
  }
}
