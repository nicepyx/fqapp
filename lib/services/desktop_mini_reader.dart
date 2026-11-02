import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
import 'desktop_shortcuts.dart';
import 'desktop_window_target.dart';
import 'mini_reader_ink.dart';

class DesktopMiniReaderController extends ChangeNotifier {
  static final instance = DesktopMiniReaderController();
  static const _channel = MethodChannel('fqapp/mini_reader');

  bool active = false;
  Object? videoOwner;
  bool get videoActive => active && videoOwner != null;
  bool get readerActive => active && videoOwner == null;
  bool hidden = false;
  double videoOpacity = 1;
  bool changing = false;
  bool hotkeyAvailable = true;
  bool hovered = true;
  bool hoverHide = false;
  bool skipTaskbar = false;
  bool pinned = true;
  bool lightText = true;
  bool menuOpen = false;
  SingleActivator get previousPageKey =>
      DesktopShortcuts.instance.keys(DesktopCommand.miniPrevious).first;
  SingleActivator get nextPageKey =>
      DesktopShortcuts.instance.keys(DesktopCommand.miniNext).first;
  MiniReaderInk ink = const MiniReaderInk();
  DesktopWindowTarget? boundWindow;
  double backgroundOpacity = 0;

  SharedPreferences? _preferences;
  late Rect _normalBounds;
  late Size _normalMinimumSize;
  late bool _wasMaximized;
  late bool _wasPinned;
  late bool _wasSkipTaskbar;

  Future<void> enter({
    Object? videoOwner,
    double videoAspectRatio = 16 / 9,
  }) async {
    if (active || changing) return;
    changing = true;
    notifyListeners();
    try {
      this.videoOwner = videoOwner;
      hidden = false;
      await _loadSettings();
      final display = await screenRetriever.getPrimaryDisplay();
      final available = display.visibleSize ?? display.size;
      _normalMinimumSize = Size(
        math.min(800, available.width),
        math.min(440, available.height),
      );
      _wasMaximized = await windowManager.isMaximized();
      _wasPinned = await windowManager.isAlwaysOnTop();
      _wasSkipTaskbar = await windowManager.isSkipTaskbar();
      hovered = true;
      menuOpen = false;
      _channel.setMethodCallHandler(_onNativeEvent);
      hotkeyAvailable = (await _channel.invokeMethod<bool>(
        'enter',
        _bossKeyArguments,
      ))!;
      DesktopShortcuts.instance.onBossKeyChanged = _updateBossKey;
      DesktopShortcuts.instance.onRecordingChanged = (recording) async {
        if (recording) {
          await _channel.invokeMethod<bool>('setBossKey', null);
        } else {
          await _updateBossKey();
        }
      };
      if (_wasMaximized) await windowManager.unmaximize();
      _normalBounds = await windowManager.getBounds();
      // Switch layouts before the native resize gives the normal rail a tiny viewport.
      active = true;
      notifyListeners();
      await windowManager.setMinimumSize(
        videoOwner == null ? const Size(320, 280) : const Size(320, 200),
      );
      await windowManager.setAsFrameless();
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setHasShadow(false);
      await windowManager.setAlwaysOnTop(pinned);
      await windowManager.setSkipTaskbar(skipTaskbar);
      final width = videoAspectRatio < 1 ? 360.0 : 560.0;
      await windowManager.setSize(
        videoOwner == null
            ? Size(460, math.min(620, _normalBounds.height))
            : Size(
                width,
                math.min(width / videoAspectRatio, available.height - 80),
              ),
      );
      await _channel.invokeMethod<void>('setHoverHide', hoverHide);
    } finally {
      changing = false;
      notifyListeners();
    }
  }

  Future<void> leave() async {
    if (!active || changing) return;
    changing = true;
    notifyListeners();
    try {
      await _channel.invokeMethod<void>('leave');
      DesktopShortcuts.instance.onBossKeyChanged = null;
      DesktopShortcuts.instance.onRecordingChanged = null;
      boundWindow = null;
      await windowManager.unmaximize();
      await windowManager.setSkipTaskbar(_wasSkipTaskbar);
      await windowManager.setAlwaysOnTop(_wasPinned);
      await windowManager.setBackgroundColor(Colors.white);
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setHasShadow(true);
      await windowManager.setMinimumSize(_normalMinimumSize);
      await windowManager.setBounds(_normalBounds);
      if (_wasMaximized) await windowManager.maximize();
      active = false;
      hidden = false;
      videoOwner = null;
      menuOpen = false;
    } finally {
      changing = false;
      notifyListeners();
    }
  }

  Future<void> setHoverHide(bool value) async {
    await _channel.invokeMethod<void>('setHoverHide', value);
    hoverHide = value;
    await _preferences!.setBool(_windowKey('hover_hide'), value);
    notifyListeners();
  }

  Future<void> setSkipTaskbar(bool value) async {
    await windowManager.setSkipTaskbar(value);
    skipTaskbar = value;
    await _preferences!.setBool(_windowKey('skip_taskbar'), value);
    notifyListeners();
  }

  Future<void> setPinned(bool value) async {
    if (boundWindow != null) await bindWindow(null);
    await windowManager.setAlwaysOnTop(value);
    pinned = value;
    await _preferences!.setBool(_windowKey('pinned'), value);
    notifyListeners();
  }

  Future<void> setLightText(bool value) async {
    lightText = value;
    await setInk(
      ink.copyWith(
        color: value ? const Color(0xffd2d2d2) : const Color(0xff292724),
      ),
    );
    notifyListeners();
    await _preferences!.setBool('mini_reader_light_text', value);
  }

  Future<void> setBackgroundOpacity(double value) async {
    backgroundOpacity = value;
    notifyListeners();
    await _preferences!.setDouble('mini_reader_background_opacity', value);
  }

  Future<void> setPageKey(int direction, SingleActivator value) =>
      DesktopShortcuts.instance.setPrimary(
        direction < 0 ? DesktopCommand.miniPrevious : DesktopCommand.miniNext,
        value,
      );

  Future<void> setInk(MiniReaderInk value) async {
    ink = value;
    notifyListeners();
    await _preferences!.setString(
      'mini_reader_ink',
      jsonEncode(value.toJson()),
    );
  }

  Map<String, int>? get _bossKeyArguments {
    final keys = DesktopShortcuts.instance.keys(DesktopCommand.miniBoss);
    return keys.isEmpty ? null : DesktopShortcuts.windowsHotkey(keys.first);
  }

  String get bossKeyLabel {
    final keys = DesktopShortcuts.instance.keys(DesktopCommand.miniBoss);
    return keys.isEmpty ? '未设置' : DesktopShortcuts.label(keys.first);
  }

  Future<void> _updateBossKey() async {
    hotkeyAvailable = (await _channel.invokeMethod<bool>(
      'setBossKey',
      _bossKeyArguments,
    ))!;
    notifyListeners();
  }

  Future<List<DesktopWindowTarget>> windowTargets() async {
    final values = (await _channel.invokeListMethod<dynamic>('windowTargets'))!;
    return values
        .map((v) => DesktopWindowTarget.fromMap(v as Map<dynamic, dynamic>))
        .toList();
  }

  Future<void> bindWindow(DesktopWindowTarget? target) async {
    await _channel.invokeMethod<void>('bindWindow', target?.handle);
    boundWindow = target;
    if (target == null) await windowManager.setAlwaysOnTop(pinned);
    notifyListeners();
  }

  Future<void> setMenuOpen(bool value) {
    menuOpen = value;
    return _channel.invokeMethod<void>('setMenuOpen', value);
  }

  Future<void> toggleHidden() => _channel.invokeMethod<void>('toggleHidden');

  Future<void> setVideoOpacity(double value) async {
    videoOpacity = value;
    notifyListeners();
    await _preferences!.setDouble('mini_video_opacity', value);
  }

  Future<void> _onNativeEvent(MethodCall call) async {
    if (call.method == 'hover') {
      hovered = call.arguments as bool;
      notifyListeners();
    } else if (call.method == 'hidden') {
      hidden = call.arguments as bool;
      notifyListeners();
    } else if (call.method == 'targetClosed') {
      boundWindow = null;
      await windowManager.setAlwaysOnTop(pinned);
      notifyListeners();
    }
  }

  String _windowKey(String key) =>
      '${videoOwner == null ? 'mini_reader' : 'mini_video'}_$key';

  Future<void> _loadSettings() async {
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    hoverHide = prefs.getBool(_windowKey('hover_hide')) ?? false;
    skipTaskbar = prefs.getBool(_windowKey('skip_taskbar')) ?? false;
    pinned = prefs.getBool(_windowKey('pinned')) ?? true;
    videoOpacity = (prefs.getDouble('mini_video_opacity') ?? 1).clamp(.2, 1);
    lightText = prefs.getBool('mini_reader_light_text') ?? true;
    await DesktopShortcuts.instance.load();
    final savedInk = prefs.getString('mini_reader_ink');
    ink = savedInk == null
        ? MiniReaderInk(
            color: lightText
                ? const Color(0xffd2d2d2)
                : const Color(0xff292724),
          )
        : MiniReaderInk.fromJson(jsonDecode(savedInk) as Map<String, dynamic>);
    backgroundOpacity = (prefs.getDouble('mini_reader_background_opacity') ?? 0)
        .clamp(0, 1);
  }
}
