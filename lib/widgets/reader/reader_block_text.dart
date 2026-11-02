import 'package:flutter/material.dart';

import 'reader_chapter_layout.dart';
import 'reader_ink_text.dart';

class ReaderBlockText extends StatelessWidget {
  final ReaderContentBlock block;
  final ReaderLayoutSpec spec;

  const ReaderBlockText({super.key, required this.block, required this.spec});

  @override
  Widget build(BuildContext context) {
    final key = block.isTitle
        ? const ValueKey('reader-chapter-title')
        : ValueKey('reader-paragraph-${block.index - 1}');
    final ink = ReaderInkScope.of(context);
    if (ink != null) {
      return ReaderInkText(
        key: key,
        span: block.span,
        ink: ink,
        textScaler: spec.textScaler,
        textAlign: block.align,
        semanticsLabel: block.text,
      );
    }
    return block.isTitle
        ? Text(
            block.text,
            key: key,
            style: block.span.style,
            textAlign: block.align,
            textScaler: spec.textScaler,
            textDirection: TextDirection.ltr,
            locale: const Locale('zh', 'CN'),
          )
        : Text.rich(
            block.span,
            key: key,
            style: block.span.style,
            textAlign: block.align,
            textScaler: spec.textScaler,
            textDirection: TextDirection.ltr,
            locale: const Locale('zh', 'CN'),
            semanticsLabel: block.text,
          );
  }
}
