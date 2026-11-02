import 'package:flutter/material.dart';

import 'home_design.dart';
import 'home_shelf.dart';

/// Loading placeholders share the feed's cover and text geometry.
class HomeSkeleton extends StatefulWidget {
  final int? columns;
  final int titleMaxLines;
  final bool showHeader;

  const HomeSkeleton({
    super.key,
    this.columns,
    this.titleMaxLines = 2,
    this.showHeader = true,
  });

  @override
  State<HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<HomeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (HomeMotion.reduced(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = !HomeMotion.reduced(context);
    final body = Padding(
      padding: EdgeInsets.only(top: widget.showHeader ? 8 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeader) ...[
            const _ContinueSkeleton(),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                homeGutter,
                homeSectionGap,
                homeGutter,
                homeHeaderGap,
              ),
              child: _Bar(width: 96, height: 18, radius: 4),
            ),
          ],
          _GridSkeleton(
            columns: widget.columns,
            titleMaxLines: widget.titleMaxLines,
          ),
        ],
      ),
    );
    if (!animate) return body;
    return FadeTransition(
      // 0.6 -> 1.0：官方 SkeletonLayout 的呼吸透明度。
      opacity: Tween<double>(
        begin: 0.6,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeInOut)).animate(_pulse),
      child: body,
    );
  }
}

/// 「继续阅读」那一行字：左侧动作 + 一条书名。
class _ContinueSkeleton extends StatelessWidget {
  const _ContinueSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(homeGutter, 10, homeGutter, 10),
      child: Row(
        children: [
          _Bar(width: 52, height: 11, radius: 4),
          SizedBox(width: 8),
          Expanded(child: _Bar(height: 12, radius: 4)),
        ],
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  final int? columns;
  final int titleMaxLines;

  const _GridSkeleton({this.columns, required this.titleMaxLines});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: homeGutter),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count =
              columns ?? homeShelfColumns(context, constraints.maxWidth);
          return Column(
            children: [
              for (var row = 0; row < 2; row++) ...[
                if (row > 0) const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var column = 0; column < count; column++) ...[
                      if (column > 0) const SizedBox(width: homeGridGap),
                      Expanded(
                        child: _CardSkeleton(titleMaxLines: titleMaxLines),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  final int titleMaxLines;

  const _CardSkeleton({required this.titleMaxLines});

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AspectRatio(aspectRatio: 5 / 7, child: _Bar(radius: 8)),
        const SizedBox(height: 8),
        SizedBox(
          height: scaler.scale(15) * 1.35 * titleMaxLines,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bar(height: scaler.scale(15), radius: 4),
              if (titleMaxLines > 1) ...[
                SizedBox(height: scaler.scale(15) * .35),
                FractionallySizedBox(
                  widthFactor: .55,
                  child: _Bar(height: scaler.scale(15), radius: 4),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        FractionallySizedBox(
          widthFactor: 0.4,
          alignment: Alignment.centerLeft,
          child: _Bar(height: scaler.scale(11) * 1.3, radius: 4),
        ),
        const SizedBox(height: 2),
      ],
    );
  }
}

/// One placeholder bar. Colour comes from the palette so the skeleton sits on
/// the canvas and on OLED the same way the real cards do.
class _Bar extends StatelessWidget {
  const _Bar({this.height, this.width, this.radius = 3});

  final double? height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
