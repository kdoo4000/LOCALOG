import 'dart:math' as math;
import 'package:flutter/material.dart';

class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({
    super.key,
    required this.loading,
    required this.child,
    this.semanticsLabel = '불러오는 중',
  });
  final bool loading;
  final Widget child;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ExcludeSemantics(excluding: loading, child: child),
      if (loading)
        Positioned.fill(
          child: AbsorbPointer(
            child: ColoredBox(
              color: Theme.of(
                context,
              ).scaffoldBackgroundColor.withValues(alpha: .94),
              child: Center(
                child: AppLoadingDots(semanticsLabel: semanticsLabel),
              ),
            ),
          ),
        ),
    ],
  );
}

class AppLoadingDots extends StatefulWidget {
  const AppLoadingDots({super.key, this.semanticsLabel = '불러오는 중'});
  final String semanticsLabel;

  @override
  State<AppLoadingDots> createState() => _AppLoadingDotsState();
}

class _AppLoadingDotsState extends State<AppLoadingDots>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _animation.value = 0;
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticsLabel,
    liveRegion: true,
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          width: 48,
          height: 24,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Transform.translate(
                    offset: Offset(
                      0,
                      MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : -5.0 *
                                math.max(
                                  0.0,
                                  math.sin(
                                    (_animation.value - i * .16) * 2 * math.pi,
                                  ),
                                ),
                    ),
                    child: SizedBox.square(
                      dimension: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
