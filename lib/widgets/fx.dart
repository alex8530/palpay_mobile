import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Living background for every screen: drifting purple fog, rising embers,
/// a slow heartbeat glow and a dark vignette.
class HauntedBackground extends StatefulWidget {
  const HauntedBackground({super.key, required this.child});

  final Widget child;

  @override
  State<HauntedBackground> createState() => _HauntedBackgroundState();
}

class _HauntedBackgroundState extends State<HauntedBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
  final _embers = List.generate(46, (i) => _Ember(math.Random(i * 7919)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(painter: _HauntPainter(_c.value, _embers)),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Ember {
  _Ember(math.Random r)
      : x = r.nextDouble(),
        phase = r.nextDouble(),
        speed = 0.4 + r.nextDouble() * 1.2,
        size = 0.6 + r.nextDouble() * 2.2,
        sway = 6 + r.nextDouble() * 22,
        flicker = r.nextDouble() * math.pi * 2;

  final double x, phase, speed, size, sway, flicker;
}

class _HauntPainter extends CustomPainter {
  _HauntPainter(this.t, this.embers);

  final double t; // 0..1 over 30s
  final List<_Ember> embers;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = AppColors.bg);

    const tau = math.pi * 2;
    // Heartbeat: two quick pulses every few seconds.
    final beatT = (t * 6) % 1.0;
    final beat = math.exp(-math.pow((beatT - 0.10) * 18, 2)) + 0.7 * math.exp(-math.pow((beatT - 0.22) * 18, 2));

    // Drifting fog blobs.
    final blobs = [
      (0.15 + 0.10 * math.sin(t * tau), 0.20 + 0.08 * math.cos(t * tau * 2), 0.75, AppColors.purpleDeep, 0.55),
      (0.85 + 0.08 * math.cos(t * tau), 0.55 + 0.10 * math.sin(t * tau), 0.70, const Color(0xFF5B21B6), 0.35),
      (0.40 + 0.15 * math.sin(t * tau * 2 + 1), 0.95 + 0.05 * math.cos(t * tau), 0.90, const Color(0xFF2E0854), 0.60),
      (0.70 + 0.12 * math.sin(t * tau * 3), 0.05 + 0.06 * math.sin(t * tau * 2), 0.45, const Color(0xFF6D28D9), 0.22),
    ];
    for (final (bx, by, br, color, alpha) in blobs) {
      final center = Offset(bx * size.width, by * size.height);
      final radius = br * size.shortestSide * (1 + 0.06 * beat);
      final a = (alpha * (0.85 + 0.25 * beat)).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: a), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // Rising embers.
    for (final e in embers) {
      final p = (e.phase + t * e.speed * 3) % 1.0;
      final y = size.height * (1.05 - p * 1.15);
      final x = e.x * size.width + math.sin(p * tau * 2 + e.flicker) * e.sway;
      final fl = 0.5 + 0.5 * math.sin(t * tau * 40 * e.speed + e.flicker);
      final fade = math.sin(p * math.pi); // fade in/out along the path
      final a = (0.15 + 0.6 * fl) * fade;
      final paint = Paint()
        ..color = AppColors.purpleGlow.withValues(alpha: a.clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, e.size * 1.5);
      canvas.drawCircle(Offset(x, y), e.size, paint);
    }

    // Vignette.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
          stops: const [0.55, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_HauntPainter old) => old.t != t;
}

/// Fades and slides its child up after `index * step`, for staggered lists.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.step = 80});

  final Widget child;
  final int index;
  final int step; // ms between items

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  static const _run = 650; // ms of actual motion

  // The stagger delay is the leading part of one animation (not a timer), so
  // nothing is left pending when the widget goes away.
  late final int _delay = widget.index * widget.step;
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(milliseconds: _delay + _run))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = _delay / (_delay + _run);
    final curve = CurvedAnimation(parent: _c, curve: Interval(start, 1, curve: Curves.easeOutBack));
    final fade = CurvedAnimation(parent: _c, curve: Interval(start, 1, curve: Curves.easeOut));
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Opacity(
        opacity: fade.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 40 * (1 - curve.value)),
          child: Transform.scale(scale: 0.96 + 0.04 * curve.value, child: child),
        ),
      ),
      child: widget.child,
    );
  }
}

/// Wraps each child in a staggered [FadeSlideIn].
List<Widget> staggered(List<Widget> children, {int step = 80}) => [
      for (var i = 0; i < children.length; i++) FadeSlideIn(index: i, step: step, child: children[i]),
    ];

/// Breathing purple glow around its child.
class GlowPulse extends StatefulWidget {
  const GlowPulse({
    super.key,
    required this.child,
    this.color = AppColors.purple,
    this.radius = 999,
    this.intensity = 1,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double intensity;

  @override
  State<GlowPulse> createState() => _GlowPulseState();
}

class _GlowPulseState extends State<GlowPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final v = Curves.easeInOut.transform(_c.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: (0.25 + 0.45 * v) * widget.intensity),
                blurRadius: 14 + 22 * v,
                spreadRadius: 1 + 3 * v,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Text that occasionally flickers and glitches like a dying neon sign.
class FlickerText extends StatefulWidget {
  const FlickerText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<FlickerText> createState() => _FlickerTextState();
}

class _FlickerTextState extends State<FlickerText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = (widget.style ?? DefaultTextStyle.of(context).style);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final v = _c.value;
        // Glitch window near the end of each cycle.
        final glitch = v > 0.86 && v < 0.93;
        final off = (v > 0.88 && v < 0.89) || (v > 0.905 && v < 0.915);
        final dx = glitch ? math.sin(v * 900) * 3 : 0.0;
        return Opacity(
          opacity: off ? 0.15 : 1,
          child: Stack(
            children: [
              if (glitch)
                Transform.translate(
                  offset: Offset(dx + 2, 0),
                  child: Text(widget.text, style: style.copyWith(color: AppColors.blood.withValues(alpha: 0.6))),
                ),
              if (glitch)
                Transform.translate(
                  offset: Offset(-dx - 2, 0),
                  child: Text(widget.text, style: style.copyWith(color: AppColors.purpleGlow.withValues(alpha: 0.7))),
                ),
              Text(
                widget.text,
                style: style.copyWith(
                  shadows: [Shadow(color: AppColors.purpleGlow.withValues(alpha: 0.8), blurRadius: 14)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Animates a number from 0 up to [value].
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, required this.format, this.style});

  final num value;
  final String Function(num) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutExpo,
      builder: (_, v, __) => Text(format(v), textDirection: TextDirection.ltr, style: style),
    );
  }
}

/// Shrinks slightly while pressed.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child});

  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A spinning, pulsing purple eye used as the loading indicator.
class EyeLoader extends StatefulWidget {
  const EyeLoader({super.key, this.size = 56});

  final double size;

  @override
  State<EyeLoader> createState() => _EyeLoaderState();
}

class _EyeLoaderState extends State<EyeLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(painter: _EyePainter(_c.value)),
      ),
    );
  }
}

class _EyePainter extends CustomPainter {
  _EyePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final ring = Rect.fromCircle(center: c, radius: r * 0.85);
    canvas.drawArc(
      ring,
      t * math.pi * 2,
      math.pi * 1.3,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: const [Colors.transparent, AppColors.purpleGlow],
          transform: GradientRotation(t * math.pi * 2),
        ).createShader(ring),
    );
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 4);
    canvas.drawCircle(
      c,
      r * (0.22 + 0.08 * pulse),
      Paint()
        ..color = AppColors.blood.withValues(alpha: 0.6 + 0.4 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(c, r * 0.1, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_EyePainter old) => old.t != t;
}

/// Centered [EyeLoader] with padding, for card/screen placeholders.
class LoaderBox extends StatelessWidget {
  const LoaderBox({super.key});

  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.all(28), child: Center(child: EyeLoader()));
}
