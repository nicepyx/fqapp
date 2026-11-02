import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class MiniReaderColorPicker extends StatelessWidget {
  const MiniReaderColorPicker({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final Color value;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 13)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final color in const [
            Color(0xffd2d2d2),
            Color(0xff292724),
            Colors.white,
            Color(0xffe05263),
            Color(0xff52b788),
            Color(0xff78b7ef),
            Color(0xfff4d35e),
          ])
            Tooltip(
              message:
                  '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
              child: InkResponse(
                key: ValueKey('$label-${color.toARGB32()}'),
                onTap: () => onChanged(color),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey),
                  ),
                  child: value == color
                      ? Icon(
                          LucideIcons.check,
                          size: 16,
                          color: color.computeLuminance() > .5
                              ? Colors.black
                              : Colors.white,
                        )
                      : null,
                ),
              ),
            ),
          IconButton(
            tooltip: '自定义$label',
            icon: const Icon(LucideIcons.palette, size: 18),
            onPressed: () async {
              final selected = await showDialog<Color>(
                context: context,
                builder: (_) => _ColorDialog(label: label, initial: value),
              );
              if (selected != null) onChanged(selected);
            },
          ),
        ],
      ),
    ],
  );
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.label, required this.initial});
  final String label;
  final Color initial;
  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late HSVColor _color = HSVColor.fromColor(widget.initial);
  late final _hex = TextEditingController(text: _code(widget.initial));
  String? _error;
  String _code(Color value) =>
      value.toARGB32().toRadixString(16).substring(2).toUpperCase();

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _adjust(HSVColor value) {
    setState(() {
      _color = value;
      _error = null;
      _hex.text = _code(value.toColor());
    });
  }

  void _confirm() {
    if (_error == null) Navigator.pop(context, _color.toColor());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.label),
    content: SizedBox(
      width: 320,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: _color.toColor(),
                border: Border.all(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hex,
              autofocus: true,
              maxLength: 6,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
              ],
              onSubmitted: (_) => _confirm(),
              decoration: InputDecoration(
                labelText: 'HEX',
                prefixText: '#',
                errorText: _error,
              ),
              onChanged: (value) {
                final rgb = value.length == 6
                    ? int.tryParse(value, radix: 16)
                    : null;
                setState(() {
                  _error = rgb == null ? '请输入 6 位十六进制颜色' : null;
                  if (rgb != null) {
                    _color = HSVColor.fromColor(Color(0xff000000 | rgb));
                  }
                });
              },
            ),
            _slider('色相', _color.hue, 360, (v) => _adjust(_color.withHue(v))),
            _slider(
              '饱和度',
              _color.saturation,
              1,
              (v) => _adjust(_color.withSaturation(v)),
            ),
            _slider('明度', _color.value, 1, (v) => _adjust(_color.withValue(v))),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: _error == null ? _confirm : null,
        child: const Text('确定'),
      ),
    ],
  );

  Widget _slider(
    String label,
    double value,
    double max,
    ValueChanged<double> changed,
  ) => Row(
    children: [
      SizedBox(
        width: 48,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
      Expanded(
        child: Slider(
          key: ValueKey('color-$label'),
          value: value,
          max: max,
          onChanged: changed,
        ),
      ),
    ],
  );
}
