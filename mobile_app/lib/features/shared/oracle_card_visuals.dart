import 'dart:math' as math;

import 'package:flutter/material.dart';

const Color kOracleGold = Color(0xFFD9AC57);
const Color kOracleGoldBright = Color(0xFFEFCF8B);
const Color kOracleDeepIndigo = Color(0xFF221C3A);
const Color kOracleMidnight = Color(0xFF141021);

/// カード裏面（絵柄アセット導入までの正式プレースホルダ）。
/// 金の二重枠＋中央の勾玉環＋星をCustomPaintで描画する。
class OracleCardBack extends StatelessWidget {
  const OracleCardBack({
    super.key,
    this.width = 86,
    this.glow = false,
  });

  final double width;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.55;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.10),
        boxShadow: [
          if (glow)
            BoxShadow(
              color: kOracleGold.withValues(alpha: 0.55),
              blurRadius: 18,
              spreadRadius: 2,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: CustomPaint(painter: _CardBackPainter()),
    );
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.10),
    );

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2A2350), kOracleDeepIndigo, Color(0xFF191430)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, fill);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.022
      ..color = kOracleGold;
    canvas.drawRRect(rrect.deflate(size.width * 0.045), border);
    border.strokeWidth = size.width * 0.010;
    canvas.drawRRect(rrect.deflate(size.width * 0.085), border);

    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = size.width * 0.26;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.016
      ..color = kOracleGoldBright.withValues(alpha: 0.9);
    canvas.drawCircle(center, ringRadius, ring);

    // 勾玉風の弧（三つ巴の簡易表現）
    final comma = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.035
      ..color = kOracleGold;
    for (var i = 0; i < 3; i++) {
      final start = i * 2 * math.pi / 3;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius * 0.62),
        start,
        math.pi * 0.9,
        false,
        comma,
      );
    }

    // 四隅と上下の小星
    final star = Paint()..color = kOracleGoldBright.withValues(alpha: 0.85);
    void drawStar(Offset at, double r) {
      final path = Path();
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final radius = i.isEven ? r : r * 0.4;
        final point = at + Offset(math.cos(angle), math.sin(angle)) * radius;
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, star);
    }

    drawStar(Offset(center.dx, size.height * 0.16), size.width * 0.045);
    drawStar(Offset(center.dx, size.height * 0.84), size.width * 0.045);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// カード表面（結果表示用）。金枠パネルにカード名を明朝系で描く。
class OracleCardFace extends StatelessWidget {
  const OracleCardFace({
    super.key,
    required this.cardName,
    this.width = 190,
  });

  final String cardName;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.55;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.08),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E2752), Color(0xFF1C1735)],
        ),
        border: Border.all(color: kOracleGold, width: 2.4),
        boxShadow: [
          BoxShadow(
            color: kOracleGold.withValues(alpha: 0.35),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(width * 0.055),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(width * 0.05),
                  border: Border.all(
                    color: kOracleGoldBright.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                cardName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: width * 0.115,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF3EBD8),
                ),
              ),
            ),
          ),
          Positioned(
            top: width * 0.10,
            left: 0,
            right: 0,
            child: Icon(
              Icons.auto_awesome,
              size: width * 0.13,
              color: kOracleGoldBright.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

/// 星空背景（スプラッシュ・結果画面などの神秘演出）。
/// [twinkle] に0..1の位相を渡すと瞬く。
class StarfieldPainter extends CustomPainter {
  StarfieldPainter({required this.twinkle, this.starCount = 70});

  final double twinkle;
  final int starCount;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint();
    for (var i = 0; i < starCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final base = 0.25 + rng.nextDouble() * 0.5;
      final phase = rng.nextDouble() * 2 * math.pi;
      final alpha =
          (base + 0.35 * math.sin(twinkle * 2 * math.pi + phase)).clamp(0.05, 1.0);
      paint.color = Colors.white.withValues(alpha: alpha * 0.8);
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 1.4 + 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) =>
      oldDelegate.twinkle != twinkle;
}
