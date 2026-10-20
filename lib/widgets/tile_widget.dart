import 'package:flutter/material.dart';

import '../theme.dart';

/// One number tile. Pops in when it is spawned and pops when its value changes.
class TileWidget extends StatefulWidget {
  const TileWidget({
    super.key,
    required this.value,
    required this.isNew,
    required this.size,
  });

  final int value;
  final bool isNew;
  final double size;

  @override
  State<TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<TileWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  Animation<double> _scale = const AlwaysStoppedAnimation<double>(1);

  @override
  void initState() {
    super.initState();
    if (widget.isNew) _playSpawn();
  }

  @override
  void didUpdateWidget(TileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _playPop();
  }

  // The first part of the animation is the slide, so the effects start later.
  void _playSpawn() {
    _scale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 1, curve: Curves.easeOutBack),
      ),
    );
    _controller.forward(from: 0);
  }

  void _playPop() {
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.18, end: 1)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.45, 1)),
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = tileStyleFor(widget.value);
    return ScaleTransition(
      scale: _scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${widget.value}',
                style: TextStyle(
                  fontSize: widget.size * 0.42,
                  fontWeight: FontWeight.w800,
                  color: style.foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
