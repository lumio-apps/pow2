import 'package:flutter/material.dart';

import '../app_controller.dart';

/// One number tile. It grows in when it is spawned, and pops with a ring
/// when two tiles merge into it.
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
    duration: const Duration(milliseconds: 380),
  );

  Animation<double> _scale = const AlwaysStoppedAnimation<double>(1);
  Animation<double> _ring = const AlwaysStoppedAnimation<double>(0);

  /// True when the phone is set to "remove animations".
  bool get _reduceMotion => WidgetsBinding
      .instance.platformDispatcher.accessibilityFeatures.disableAnimations;

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
    if (_reduceMotion) return;
    _ring = const AlwaysStoppedAnimation<double>(0);
    _scale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1, curve: Curves.easeOutBack),
      ),
    );
    _controller.forward(from: 0);
  }

  void _playPop() {
    if (_reduceMotion) return;
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1)),
    );
    _ring = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1, curve: Curves.easeOut),
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
    final palette = context.palette;
    final style = palette.tileStyle(widget.value);
    final base = style.background;
    final top = Color.lerp(base, Colors.white, palette.isDark ? 0.1 : 0.16)!;
    final radius = BorderRadius.circular(widget.size * 0.2);
    final glow = widget.value >= 1024;

    final tile = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, base],
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
          if (glow)
            BoxShadow(
              color: base.withValues(alpha: 0.55),
              blurRadius: 24,
              spreadRadius: 1,
            ),
        ],
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
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final ring = _ring.value;
        return Transform.scale(
          scale: _scale.value,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: child!),
              if (ring > 0 && ring < 1)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Transform.scale(
                      scale: 1 + 0.35 * ring,
                      child: Opacity(
                        opacity: 1 - ring,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            border: Border.all(
                              color: palette.accent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: tile,
    );
  }
}
