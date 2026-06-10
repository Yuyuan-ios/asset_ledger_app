part of 'phone_login_gate.dart';

class _LoginBackgroundGeometryPainter extends CustomPainter {
  const _LoginBackgroundGeometryPainter(this.scale, this.originX);

  final double scale;
  final double originX;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _loginGeometryColor.withValues(alpha: 0.35)
      ..strokeWidth = scale
      ..style = PaintingStyle.stroke;

    void line(List<Offset> points) {
      final path = Path()
        ..moveTo(originX + points.first.dx * scale, points.first.dy * scale);
      for (final point in points.skip(1)) {
        path.lineTo(originX + point.dx * scale, point.dy * scale);
      }
      canvas.drawPath(path, paint);
    }

    void horizontalLine(double y, double left, double right, double alpha) {
      final start = Offset(originX + left * scale, y * scale);
      final end = Offset(originX + right * scale, y * scale);
      final linePaint = Paint()
        ..shader =
            LinearGradient(
              colors: [
                _loginGeometryColor.withValues(alpha: 0),
                _loginGeometryColor.withValues(alpha: alpha),
                _loginGeometryColor.withValues(alpha: alpha * 0.55),
                _loginGeometryColor.withValues(alpha: 0),
              ],
              stops: const [0, 0.2, 0.72, 1],
            ).createShader(
              Rect.fromLTRB(start.dx, start.dy, end.dx, end.dy + scale),
            )
        ..strokeWidth = math.max(0.85, scale * 1.25)
        ..style = PaintingStyle.stroke;
      canvas.drawLine(start, end, linePaint);
    }

    horizontalLine(585, 620, 790, 0.42);
    horizontalLine(672, 620, 790, 0.39);
    horizontalLine(758, 620, 790, 0.36);
    horizontalLine(990, 176, 808, 0.37);
    horizontalLine(1086, 196, 828, 0.35);
    horizontalLine(1182, 168, 816, 0.32);
    horizontalLine(1278, 224, 828, 0.29);
    horizontalLine(1374, 300, 824, 0.25);

    line([const Offset(610, 560), const Offset(760, 456)]);
    line([const Offset(610, 645), const Offset(760, 542)]);
    line([const Offset(596, 744), const Offset(760, 634)]);
    line([
      const Offset(630, 565),
      const Offset(630, 927),
      const Offset(760, 1015),
    ]);
    line([
      const Offset(187, 934),
      const Offset(403, 788),
      const Offset(738, 1014),
      const Offset(522, 1160),
      const Offset(187, 934),
    ]);
    line([
      const Offset(244, 1017),
      const Offset(540, 817),
      const Offset(823, 1008),
    ]);
    line([
      const Offset(181, 1221),
      const Offset(475, 1022),
      const Offset(731, 1195),
      const Offset(300, 1486),
    ]);
    line([
      const Offset(302, 1323),
      const Offset(598, 1123),
      const Offset(826, 1277),
    ]);
    line([
      const Offset(408, 950),
      const Offset(726, 736),
      const Offset(948, 886),
    ]);
  }

  @override
  bool shouldRepaint(covariant _LoginBackgroundGeometryPainter oldDelegate) {
    return oldDelegate.scale != scale || oldDelegate.originX != originX;
  }
}

class _LoginClockMoneyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 111;
    final sy = size.height / 110;
    canvas.save();
    canvas.scale(sx, sy);

    final paint = Paint()
      ..color = _loginIconColor.withValues(alpha: 0.9)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final center = const Offset(56, 55);
    final rect = Rect.fromCircle(center: center, radius: 50);
    canvas.drawArc(rect, -math.pi * 1.22, math.pi * 1.86, false, paint);
    canvas.drawLine(const Offset(56, 17), const Offset(56, 55), paint);
    canvas.drawLine(const Offset(56, 55), const Offset(78, 70), paint);
    canvas.drawLine(const Offset(20, 55), const Offset(28, 55), paint);
    canvas.drawLine(const Offset(87, 55), const Offset(95, 55), paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: r'$',
        style: TextStyle(
          fontFamily: 'PingFang SC',
          fontSize: 42,
          height: 1,
          color: _loginIconColor.withValues(alpha: 0.9),
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, const Offset(38, 68));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChinaFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rect = Offset.zero & size;
    paint.color = const Color(0xFFDE2910);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.height * 0.04)),
      paint,
    );

    paint.color = const Color(0xFFFFDE00);
    _drawStar(
      canvas,
      paint,
      Offset(size.width * 0.24, size.height * 0.32),
      size.height * 0.13,
      -math.pi / 2,
    );
    _drawStar(
      canvas,
      paint,
      Offset(size.width * 0.42, size.height * 0.18),
      size.height * 0.045,
      -math.pi / 2,
    );
    _drawStar(
      canvas,
      paint,
      Offset(size.width * 0.48, size.height * 0.32),
      size.height * 0.045,
      -math.pi / 2,
    );
    _drawStar(
      canvas,
      paint,
      Offset(size.width * 0.48, size.height * 0.48),
      size.height * 0.045,
      -math.pi / 2,
    );
    _drawStar(
      canvas,
      paint,
      Offset(size.width * 0.42, size.height * 0.62),
      size.height * 0.045,
      -math.pi / 2,
    );
  }

  void _drawStar(
    Canvas canvas,
    Paint paint,
    Offset center,
    double radius,
    double rotation,
  ) {
    final path = Path();
    for (var i = 0; i < 10; i += 1) {
      final currentRadius = i.isEven ? radius : radius * 0.42;
      final angle = rotation + i * math.pi / 5;
      final point = Offset(
        center.dx + math.cos(angle) * currentRadius,
        center.dy + math.sin(angle) * currentRadius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AgreementCheckPainter extends CustomPainter {
  const _AgreementCheckPainter({required this.accepted});

  final bool accepted;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final radius = math.min(size.width, size.height) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    if (accepted) {
      paint.color = const Color(0xFFC85D20);
      canvas.drawCircle(center, radius, paint);
      final checkPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3 * (size.width / 38)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(size.width * 0.28, size.height * 0.52)
        ..lineTo(size.width * 0.44, size.height * 0.68)
        ..lineTo(size.width * 0.74, size.height * 0.34);
      canvas.drawPath(path, checkPaint);
    } else {
      paint.color = Colors.white.withValues(alpha: 0.45);
      canvas.drawCircle(center, radius, paint);
      final borderPaint = Paint()
        ..color = const Color(0xFFC85D20).withValues(alpha: 0.55)
        ..strokeWidth = 2 * (size.width / 38)
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(
        center,
        radius - borderPaint.strokeWidth / 2,
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AgreementCheckPainter oldDelegate) {
    return oldDelegate.accepted != accepted;
  }
}
