import 'package:flutter/material.dart';

class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant AppCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null && _pressed) _pressed = false;
  }

  void _setPressed(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedScale(
      scale: !reduceMotion && _pressed ? .985 : 1,
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: _setPressed,
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}
