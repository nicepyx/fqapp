import 'package:flutter/material.dart';

import '../../services/mini_reader_ink.dart';

class ReaderInkScope extends InheritedWidget {
  const ReaderInkScope({super.key, required this.ink, required super.child});
  final MiniReaderInk ink;

  static MiniReaderInk? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReaderInkScope>()?.ink;

  @override
  bool updateShouldNotify(ReaderInkScope oldWidget) => oldWidget.ink != ink;
}

class ReaderInkText extends StatelessWidget {
  const ReaderInkText({
    super.key,
    required this.span,
    required this.ink,
    required this.textScaler,
    this.textAlign = TextAlign.start,
    this.semanticsLabel,
  });
  final TextSpan span;
  final MiniReaderInk ink;
  final TextScaler textScaler;
  final TextAlign textAlign;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final fill = _text(_paintSpan(span, false), semanticsLabel);
    if (!ink.outlineEnabled) return fill;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(child: _text(_paintSpan(span, true), null)),
          ),
        ),
        fill,
      ],
    );
  }

  Widget _text(TextSpan value, String? label) => Text.rich(
    value,
    style: value.style,
    textAlign: textAlign,
    textScaler: textScaler,
    textDirection: TextDirection.ltr,
    locale: const Locale('zh', 'CN'),
    semanticsLabel: label,
  );

  TextSpan _paintSpan(TextSpan value, bool outline) => TextSpan(
    text: value.text,
    style: (value.style ?? const TextStyle()).copyWith(
      color: outline ? null : ink.color,
      foreground: outline
          ? (Paint()
              ..color = ink.outlineColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = ink.outlineWidth * 2
              ..strokeJoin = StrokeJoin.round)
          : null,
      shadows: !outline && ink.shadowEnabled
          ? [
              Shadow(
                color: ink.shadowColor.withValues(alpha: ink.shadowOpacity),
                blurRadius: ink.shadowBlur,
                offset: Offset(ink.shadowOffset, ink.shadowOffset),
              ),
            ]
          : const [],
    ),
    children: value.children
        ?.map((child) => child is TextSpan ? _paintSpan(child, outline) : child)
        .toList(),
  );
}
