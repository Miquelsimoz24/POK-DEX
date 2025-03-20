import 'package:flutter/material.dart';
import 'dart:math' as math;

class PokemonLoadingAnimation extends StatefulWidget {
  final double size;
  final Color color;

  const PokemonLoadingAnimation({
    Key? key,
    this.size = 50.0,
    this.color = Colors.red,
  }) : super(key: key);

  @override
  _PokemonLoadingAnimationState createState() =>
      _PokemonLoadingAnimationState();
}

class _PokemonLoadingAnimationState extends State<PokemonLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: PokeBallPainter(color: widget.color),
          ),
        );
      },
    );
  }
}

class PokeBallPainter extends CustomPainter {
  final Color color;

  PokeBallPainter({this.color = Colors.red});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    final blackPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black;

    final whitePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    // Draw top half (red)
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2,
      ),
      math.pi,
      math.pi,
      true,
      paint,
    );

    // Draw bottom half (white)
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2,
      ),
      0,
      math.pi,
      true,
      whitePaint,
    );

    // Draw middle black line
    canvas.drawRect(
      Rect.fromLTWH(0, size.height / 2 - 2, size.width, 4),
      blackPaint,
    );

    // Draw center circle (black outline)
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 6,
      blackPaint,
    );

    // Draw center circle (white fill)
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 8,
      whitePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
