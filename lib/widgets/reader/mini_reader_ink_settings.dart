import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/desktop_mini_reader.dart';
import 'mini_reader_color_picker.dart';
import 'reader_ink_text.dart';

class MiniReaderInkSettings extends StatelessWidget {
  const MiniReaderInkSettings({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: DesktopMiniReaderController.instance,
    builder: (context, _) {
      final controller = DesktopMiniReaderController.instance;
      final ink = controller.ink;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _preview(context),
          MiniReaderColorPicker(
            label: '文字颜色',
            value: ink.color,
            onChanged: (color) =>
                unawaited(controller.setInk(ink.copyWith(color: color))),
          ),
          SwitchListTile.adaptive(
            key: const ValueKey('mini-outline-enabled'),
            contentPadding: EdgeInsets.zero,
            title: const Text('文字描边', style: TextStyle(fontSize: 14)),
            value: ink.outlineEnabled,
            onChanged: (v) =>
                unawaited(controller.setInk(ink.copyWith(outlineEnabled: v))),
          ),
          if (ink.outlineEnabled) ...[
            MiniReaderColorPicker(
              label: '描边颜色',
              value: ink.outlineColor,
              onChanged: (color) => unawaited(
                controller.setInk(ink.copyWith(outlineColor: color)),
              ),
            ),
            _slider(
              '描边粗细',
              ink.outlineWidth,
              .2,
              2,
              (v) =>
                  unawaited(controller.setInk(ink.copyWith(outlineWidth: v))),
            ),
          ],
          _shadowSettings(),
        ],
      );
    },
  );

  Widget _preview(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('文字预览', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        for (final (name, color) in const [
          ('light', Color(0xfffafafa)),
          ('dark', Color(0xff232323)),
        ])
          ColoredBox(
            key: ValueKey('mini-ink-preview-$name'),
            color: color,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ReaderInkText(
                span: const TextSpan(
                  text: '清风翻书，故事未完。',
                  style: TextStyle(fontSize: 16, height: 1.6),
                ),
                ink: DesktopMiniReaderController.instance.ink,
                textScaler: MediaQuery.textScalerOf(context),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _shadowSettings() {
    final controller = DesktopMiniReaderController.instance;
    final ink = controller.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          key: const ValueKey('mini-shadow-enabled'),
          contentPadding: EdgeInsets.zero,
          title: const Text('文字阴影', style: TextStyle(fontSize: 14)),
          value: ink.shadowEnabled,
          onChanged: (v) =>
              unawaited(controller.setInk(ink.copyWith(shadowEnabled: v))),
        ),
        if (ink.shadowEnabled) ...[
          MiniReaderColorPicker(
            label: '阴影颜色',
            value: ink.shadowColor,
            onChanged: (color) =>
                unawaited(controller.setInk(ink.copyWith(shadowColor: color))),
          ),
          _slider(
            '阴影强度',
            ink.shadowOpacity,
            0,
            1,
            (v) => unawaited(controller.setInk(ink.copyWith(shadowOpacity: v))),
            percentage: true,
          ),
          _slider(
            '阴影模糊',
            ink.shadowBlur,
            0,
            8,
            (v) => unawaited(controller.setInk(ink.copyWith(shadowBlur: v))),
          ),
          _slider(
            '阴影偏移',
            ink.shadowOffset,
            0,
            6,
            (v) => unawaited(controller.setInk(ink.copyWith(shadowOffset: v))),
          ),
        ],
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> changed, {
    bool percentage = false,
  }) => Row(
    children: [
      SizedBox(
        width: 64,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
      Expanded(
        child: Slider(
          key: ValueKey(label),
          value: value,
          min: min,
          max: max,
          label: percentage
              ? '${(value * 100).round()}%'
              : value.toStringAsFixed(1),
          onChanged: changed,
        ),
      ),
      SizedBox(
        width: 40,
        child: Text(
          percentage ? '${(value * 100).round()}%' : value.toStringAsFixed(1),
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ],
  );
}
