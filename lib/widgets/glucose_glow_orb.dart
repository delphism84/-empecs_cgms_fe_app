import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class GlucoseGlowOrb extends StatefulWidget {
  const GlucoseGlowOrb({
    super.key,
    required this.value,
    this.size = 60,
    this.cycleSeconds = 10,
    this.minTime,
    this.maxTime,
  });

  final String value; // e.g., '110'
  final double size;
  final int cycleSeconds; // full color cycle duration
  final String? minTime; // e.g., '02:10'
  final String? maxTime; // e.g., '08:40'

  @override
  State<GlucoseGlowOrb> createState() => _GlucoseGlowOrbState();
}

class _GlucoseGlowOrbState extends State<GlucoseGlowOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // color cycle (solid color only)
    final double tCycle = (DateTime.now().millisecondsSinceEpoch % (widget.cycleSeconds * 1000)) / (widget.cycleSeconds * 1000);
    final Color ringColor = Color.lerp(
      Color.lerp(Colors.cyan, const Color.fromARGB(255, 188, 225, 255), _segment(tCycle, 0.0, 0.1)),
      Color.lerp(Colors.blue, const Color.fromARGB(255, 204, 240, 245), _segment(tCycle, 0.1, 0.2)),
      _segment(tCycle, 0.1, 0.2),
    ) ?? Theme.of(context).colorScheme.primary;

    // 크기 20% 축소 적용
    final double bounded = (widget.size * 0.8).clamp(0.0, 160.0);
    return SizedBox(
      width: bounded,
      height: bounded,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          // png 배경 + 외곽선 글로우(약 10px) 애니메이션
          final double glowSigma1 = 10.0; // ~10px 외곽 글로우
          final double glowSigma2 = 6.0;  // 보조 레이어로 결 유지
          final double glowStrength = (0.45 + 0.35 * _pulse.value).clamp(0.0, 1.0);

          return Stack(children: [
            // glow layer 1 (강한 바깥쪽 글로우)
            Positioned.fill(
              child: Opacity(
                opacity: glowStrength,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: glowSigma1, sigmaY: glowSigma1),
                  child: ColorFiltered(
                    colorFilter: ui.ColorFilter.mode(ringColor, BlendMode.srcATop),
                    child: Transform.scale(
                      scale: 1.04, // 살짝 확장해 외곽 비중을 높임
                      child: Image.asset(
                        'assets/images/eq.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // glow layer 2 (얕은 보조 글로우로 가장자리 보정)
            Positioned.fill(
              child: Opacity(
                opacity: glowStrength * 0.6,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: glowSigma2, sigmaY: glowSigma2),
                  child: ColorFiltered(
                    colorFilter: ui.ColorFilter.mode(ringColor.withOpacity(0.9), BlendMode.srcATop),
                    child: Transform.scale(
                      scale: 1.02,
                      child: Image.asset(
                        'assets/images/eq.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // base image (원본)
            Positioned.fill(
              child: Image.asset(
                'assets/images/eq.png',
                fit: BoxFit.contain,
              ),
            ),
          ]);
        },
      ),
    );
  }
}

double _segment(double t, double a, double b) {
  if (t <= a) return 0;
  if (t >= b) return 1;
  return (t - a) / (b - a);
}