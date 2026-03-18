import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Paints a hand-drawn style curly/wavy underline.
class CurlyUnderlinePainter extends CustomPainter {
  CurlyUnderlinePainter({this.color});

  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color ?? AppColors.primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final h = size.height;
    final w = size.width;
    path.moveTo(0, h * 0.6);
    path.quadraticBezierTo(w * 0.15, h * 0.2, w * 0.3, h * 0.7);
    path.quadraticBezierTo(w * 0.45, h * 0.1, w * 0.55, h * 0.65);
    path.quadraticBezierTo(w * 0.7, h * 0.05, w * 0.85, h * 0.6);
    path.quadraticBezierTo(w * 0.95, h * 0.3, w, h * 0.55);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Headline text with a hand-drawn style curly underline.
Widget curlyUnderlineHeadline(String text, TextStyle style) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(text, style: style),
      SizedBox(
        height: 10,
        child: LayoutBuilder(
          builder: (context, constraints) => CustomPaint(
            size: Size(constraints.maxWidth, 10),
            painter: CurlyUnderlinePainter(color: style.color),
          ),
        ),
      ),
    ],
  );
}
