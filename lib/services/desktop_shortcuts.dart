import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DesktopShortcutGroup {
  general('通用'),
  reader('小说阅读'),
  mini('小窗'),
  audio('听书'),
  drama('短剧推荐'),
  video('视频播放');

  const DesktopShortcutGroup(this.label);
  final String label;
}

enum DesktopCommand {
  search(DesktopShortcutGroup.general, '搜索作品', [
    SingleActivator(LogicalKeyboardKey.keyK, control: true),
  ]),
  settings(DesktopShortcutGroup.general, '设置', [
    SingleActivator(LogicalKeyboardKey.comma, control: true),
  ]),
  back(DesktopShortcutGroup.general, '返回', [
    SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true),
  ]),
  readerPrevious(DesktopShortcutGroup.reader, '上一页', [
    SingleActivator(LogicalKeyboardKey.arrowLeft),
    SingleActivator(LogicalKeyboardKey.pageUp),
  ]),
  readerNext(DesktopShortcutGroup.reader, '下一页', [
    SingleActivator(LogicalKeyboardKey.arrowRight),
    SingleActivator(LogicalKeyboardKey.pageDown),
  ]),
  readerDirectory(DesktopShortcutGroup.reader, '目录', [
    SingleActivator(LogicalKeyboardKey.keyD, control: true),
  ]),
  readerAppearance(DesktopShortcutGroup.reader, '阅读排版', [
    SingleActivator(LogicalKeyboardKey.keyT, control: true),
  ]),
  readerMini(DesktopShortcutGroup.reader, '进入小窗', [
    SingleActivator(LogicalKeyboardKey.keyM, control: true),
  ]),
  miniPrevious(DesktopShortcutGroup.mini, '上一页', [
    SingleActivator(LogicalKeyboardKey.arrowLeft),
    SingleActivator(LogicalKeyboardKey.pageUp),
  ]),
  miniNext(DesktopShortcutGroup.mini, '下一页', [
    SingleActivator(LogicalKeyboardKey.arrowRight),
    SingleActivator(LogicalKeyboardKey.pageDown),
  ]),
  miniExit(DesktopShortcutGroup.mini, '恢复正常窗口', [
    SingleActivator(LogicalKeyboardKey.keyM, control: true),
  ]),
  miniSettings(DesktopShortcutGroup.mini, '小窗设置', [
    SingleActivator(LogicalKeyboardKey.comma, control: true),
  ]),
  miniBoss(DesktopShortcutGroup.mini, '隐藏／恢复小窗', [
    SingleActivator(LogicalKeyboardKey.keyQ, control: true, alt: true),
  ]),
  audioPlay(DesktopShortcutGroup.audio, '播放／暂停', [
    SingleActivator(LogicalKeyboardKey.space),
  ]),
  audioBack(DesktopShortcutGroup.audio, '后退 15 秒', [
    SingleActivator(LogicalKeyboardKey.arrowLeft),
  ]),
  audioForward(DesktopShortcutGroup.audio, '前进 15 秒', [
    SingleActivator(LogicalKeyboardKey.arrowRight),
  ]),
  audioPrevious(DesktopShortcutGroup.audio, '上一章', [
    SingleActivator(LogicalKeyboardKey.pageUp),
  ]),
  audioNext(DesktopShortcutGroup.audio, '下一章', [
    SingleActivator(LogicalKeyboardKey.pageDown),
  ]),
  dramaPrevious(DesktopShortcutGroup.drama, '上一部', [
    SingleActivator(LogicalKeyboardKey.pageUp),
  ]),
  dramaNext(DesktopShortcutGroup.drama, '下一部', [
    SingleActivator(LogicalKeyboardKey.pageDown),
  ]),
  videoPlay(DesktopShortcutGroup.video, '播放／暂停', [
    SingleActivator(LogicalKeyboardKey.space),
  ]),
  videoBack(DesktopShortcutGroup.video, '后退 10 秒', [
    SingleActivator(LogicalKeyboardKey.arrowLeft),
  ]),
  videoForward(DesktopShortcutGroup.video, '前进 10 秒', [
    SingleActivator(LogicalKeyboardKey.arrowRight),
  ]),
  videoVolumeUp(DesktopShortcutGroup.video, '音量增加', [
    SingleActivator(LogicalKeyboardKey.arrowUp),
  ]),
  videoVolumeDown(DesktopShortcutGroup.video, '音量减少', [
    SingleActivator(LogicalKeyboardKey.arrowDown),
  ]),
  videoFullscreen(DesktopShortcutGroup.video, '切换全屏', [
    SingleActivator(LogicalKeyboardKey.keyF),
  ]),
  videoMini(DesktopShortcutGroup.video, '进入视频小窗', [
    SingleActivator(LogicalKeyboardKey.keyM, control: true),
  ]),
  videoBoost(DesktopShortcutGroup.video, '按住临时倍速', [
    SingleActivator(LogicalKeyboardKey.keyL),
  ]),
  videoBookmark(DesktopShortcutGroup.video, '添加片段书签', [
    SingleActivator(LogicalKeyboardKey.keyB, control: true),
  ]),
  videoTools(DesktopShortcutGroup.video, '播放工具', [
    SingleActivator(LogicalKeyboardKey.keyP, control: true, shift: true),
  ]),
  videoExitFullscreen(DesktopShortcutGroup.video, '退出全屏', [
    SingleActivator(LogicalKeyboardKey.escape),
  ]);

  const DesktopCommand(this.group, this.label, this.defaults);
  final DesktopShortcutGroup group;
  final String label;
  final List<SingleActivator> defaults;
  bool get global => this == miniBoss;
}

class DesktopShortcuts extends ChangeNotifier {
  static final instance = DesktopShortcuts();
  final _bindings = <DesktopCommand, List<SingleActivator>>{};
  Object? _recordingOwner;
  bool get recording => _recordingOwner != null;
  void beginRecording(Object owner) {
    final wasRecording = recording;
    _recordingOwner = owner;
    if (!wasRecording) unawaited(onRecordingChanged?.call(true));
  }

  void endRecording(Object owner) {
    if (_recordingOwner != owner) return;
    _recordingOwner = null;
    unawaited(onRecordingChanged?.call(false));
  }

  Future<void> Function()? onBossKeyChanged;
  Future<void> Function(bool)? onRecordingChanged;

  List<SingleActivator> keys(DesktopCommand command) =>
      _bindings[command] ?? command.defaults;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('desktop_shortcuts');
    final data = saved == null
        ? <String, dynamic>{}
        : jsonDecode(saved) as Map<String, dynamic>;
    _bindings.clear();
    for (final command in DesktopCommand.values) {
      final values = data[command.name] as List<dynamic>?;
      if (values != null) {
        _bindings[command] = values
            .map((v) => decode(v as Map<String, dynamic>))
            .toList();
      }
    }
    for (final entry in {
      DesktopCommand.miniPrevious: 'mini_reader_previous_key',
      DesktopCommand.miniNext: 'mini_reader_next_key',
    }.entries) {
      final legacy = prefs.getString(entry.value);
      if (!_bindings.containsKey(entry.key) && legacy != null) {
        _bindings[entry.key] = [
          decode(jsonDecode(legacy) as Map<String, dynamic>),
          entry.key.defaults.last,
        ];
      }
    }
    notifyListeners();
  }

  DesktopCommand? match(DesktopShortcutGroup group, KeyEvent event) {
    if (recording || event is! KeyDownEvent) return null;
    for (final command in DesktopCommand.values.where(
      (c) => c.group == group && !c.global,
    )) {
      if (keys(
        command,
      ).any((k) => k.accepts(event, HardwareKeyboard.instance))) {
        return command;
      }
    }
    return null;
  }

  DesktopCommand? conflict(DesktopCommand command, SingleActivator key) {
    for (final other in DesktopCommand.values) {
      if (other == command || !_overlap(command, other)) continue;
      if (keys(other).any((k) => sameKey(k, key))) return other;
    }
    return null;
  }

  bool _overlap(DesktopCommand a, DesktopCommand b) =>
      a.global ||
      b.global ||
      a.group == b.group ||
      (a.group == DesktopShortcutGroup.general &&
          b.group != DesktopShortcutGroup.mini) ||
      (b.group == DesktopShortcutGroup.general &&
          a.group != DesktopShortcutGroup.mini) ||
      ({
        a.group,
        b.group,
      }.containsAll([DesktopShortcutGroup.video, DesktopShortcutGroup.drama]));

  Future<void> setKeys(
    DesktopCommand command,
    List<SingleActivator> values,
  ) async {
    _bindings[command] = values;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'desktop_shortcuts',
      jsonEncode({
        for (final entry in _bindings.entries)
          entry.key.name: entry.value.map(encode).toList(),
      }),
    );
    if (command.global) await onBossKeyChanged?.call();
    notifyListeners();
  }

  Future<void> setPrimary(DesktopCommand command, SingleActivator value) =>
      setKeys(command, [
        value,
        ...keys(command).skip(1).where((k) => !sameKey(k, value)),
      ]);

  static bool sameKey(SingleActivator a, SingleActivator b) =>
      a.trigger == b.trigger &&
      a.control == b.control &&
      a.alt == b.alt &&
      a.shift == b.shift &&
      a.meta == b.meta;

  static Map<String, Object> encode(SingleActivator key) => {
    'keyId': key.trigger.keyId,
    'control': key.control,
    'alt': key.alt,
    'shift': key.shift,
    'meta': key.meta,
  };

  static SingleActivator decode(Map<String, dynamic> data) => SingleActivator(
    LogicalKeyboardKey(data['keyId'] as int),
    control: data['control'] as bool,
    alt: data['alt'] as bool,
    shift: data['shift'] as bool,
    meta: data['meta'] as bool,
  );

  static String label(SingleActivator key) => [
    if (key.control) 'Ctrl',
    if (key.alt) 'Alt',
    if (key.shift) 'Shift',
    if (key.meta) 'Win',
    switch (key.trigger) {
      LogicalKeyboardKey.arrowLeft => '←',
      LogicalKeyboardKey.arrowRight => '→',
      LogicalKeyboardKey.arrowUp => '↑',
      LogicalKeyboardKey.arrowDown => '↓',
      LogicalKeyboardKey.space => 'Space',
      _ => key.trigger.keyLabel,
    },
  ].join('+');

  static Map<String, int>? windowsHotkey(SingleActivator key) {
    final id = key.trigger.keyId;
    final vk = switch (key.trigger) {
      LogicalKeyboardKey.arrowLeft => 0x25,
      LogicalKeyboardKey.arrowUp => 0x26,
      LogicalKeyboardKey.arrowRight => 0x27,
      LogicalKeyboardKey.arrowDown => 0x28,
      LogicalKeyboardKey.pageUp => 0x21,
      LogicalKeyboardKey.pageDown => 0x22,
      LogicalKeyboardKey.home => 0x24,
      LogicalKeyboardKey.end => 0x23,
      LogicalKeyboardKey.insert => 0x2d,
      LogicalKeyboardKey.delete => 0x2e,
      LogicalKeyboardKey.escape => 0x1b,
      LogicalKeyboardKey.enter => 0x0d,
      LogicalKeyboardKey.tab => 0x09,
      LogicalKeyboardKey.backspace => 0x08,
      LogicalKeyboardKey.space => 0x20,
      LogicalKeyboardKey.comma => 0xbc,
      LogicalKeyboardKey.period => 0xbe,
      LogicalKeyboardKey.slash => 0xbf,
      LogicalKeyboardKey.semicolon => 0xba,
      LogicalKeyboardKey.quoteSingle => 0xde,
      LogicalKeyboardKey.minus => 0xbd,
      LogicalKeyboardKey.equal => 0xbb,
      LogicalKeyboardKey.bracketLeft => 0xdb,
      LogicalKeyboardKey.bracketRight => 0xdd,
      LogicalKeyboardKey.backslash => 0xdc,
      LogicalKeyboardKey.backquote => 0xc0,
      _ =>
        id >= 0x61 && id <= 0x7a
            ? id - 0x20
            : id >= 0x30 && id <= 0x39
            ? id
            : id >= LogicalKeyboardKey.f1.keyId &&
                  id <= LogicalKeyboardKey.f24.keyId
            ? 0x70 + id - LogicalKeyboardKey.f1.keyId
            : null,
    };
    return vk == null
        ? null
        : {
            'key': vk,
            'modifiers':
                (key.alt ? 1 : 0) |
                (key.control ? 2 : 0) |
                (key.shift ? 4 : 0) |
                (key.meta ? 8 : 0),
          };
  }
}
