import 'dart:math' as math;
import 'package:flutter/material.dart';

class ElevationPoint {
  final double distanceKm;
  final double elevationM;

  const ElevationPoint({
    required this.distanceKm,
    required this.elevationM,
  });
}

class ElevationProfileWidget extends StatelessWidget {
  final List<ElevationPoint> points;
  final double currentDistanceKm;
  final double currentElevationM;
  final double height;
  final bool showClimbHud;

  const ElevationProfileWidget({
    super.key,
    required this.points,
    required this.currentDistanceKm,
    required this.currentElevationM,
    this.height = 130,
    this.showClimbHud = true,
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF101014),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: const Text(
          'Profil Elevasi: Memuat atau Membutuhkan Rute GPX',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
    }

    // Calculate slope / gradient at current distance
    double currentGradientPct = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      if (currentDistanceKm >= points[i].distanceKm &&
          currentDistanceKm <= points[i + 1].distanceKm) {
        final dDistM = (points[i + 1].distanceKm - points[i].distanceKm) * 1000.0;
        final dEleM = points[i + 1].elevationM - points[i].elevationM;
        if (dDistM > 10) {
          currentGradientPct = (dEleM / dDistM) * 100.0;
        }
        break;
      }
    }

    final maxEle = points.map((p) => p.elevationM).reduce(math.max);
    final minEle = points.map((p) => p.elevationM).reduce(math.min);

    return Container(
      height: height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222228)),
      ),
      child: Column(
        children: [
          if (showClimbHud) ...[
            // ClimbPro HUD Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terrain, color: Color(0xFF00E5FF), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'CLIMB PROFILE',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Live Gradient Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getGradientColor(currentGradientPct).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _getGradientColor(currentGradientPct)),
                      ),
                      child: Text(
                        '${currentGradientPct >= 0 ? "+" : ""}${currentGradientPct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: _getGradientColor(currentGradientPct),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ALT ${currentElevationM.round()}m • MAX ${maxEle.round()}m',
                      style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          // Profile Canvas
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                size: Size.infinite,
                painter: _ElevationChartPainter(
                  points: points,
                  currentDistanceKm: currentDistanceKm,
                  minEle: minEle,
                  maxEle: maxEle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getGradientColor(double grad) {
    if (grad < 3.0) return const Color(0xFF00E676); // Easy / Green
    if (grad < 6.0) return const Color(0xFFFFF01F); // Moderate / Yellow
    if (grad < 9.0) return const Color(0xFFFF9100); // Steep / Orange
    return const Color(0xFFFF1744); // Very steep / Red
  }
}

class _ElevationChartPainter extends CustomPainter {
  final List<ElevationPoint> points;
  final double currentDistanceKm;
  final double minEle;
  final double maxEle;

  _ElevationChartPainter({
    required this.points,
    required this.currentDistanceKm,
    required this.minEle,
    required this.maxEle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final totalDist = points.last.distanceKm - points.first.distanceKm;
    if (totalDist <= 0) return;

    final eleSpan = math.max(15.0, maxEle - minEle);
    final padBottom = size.height * 0.15;
    final padTop = size.height * 0.1;
    final chartHeight = size.height - padBottom - padTop;

    double distToX(double d) {
      final ratio = (d - points.first.distanceKm) / totalDist;
      return ratio.clamp(0.0, 1.0) * size.width;
    }

    double eleToY(double e) {
      final ratio = (e - minEle) / eleSpan;
      return size.height - padBottom - (ratio.clamp(0.0, 1.0) * chartHeight);
    }

    // Grid baseline
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, size.height - padBottom),
      Offset(size.width, size.height - padBottom),
      gridPaint,
    );

    // Build Curve Path
    final path = Path();
    final firstX = distToX(points.first.distanceKm);
    final firstY = eleToY(points.first.elevationM);
    path.moveTo(firstX, firstY);

    for (int i = 1; i < points.length; i++) {
      final x = distToX(points[i].distanceKm);
      final y = eleToY(points[i].elevationM);
      path.lineTo(x, y);
    }

    // Fill Gradient Path under curve
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height - padBottom);
    fillPath.lineTo(0, size.height - padBottom);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00E5FF).withOpacity(0.35),
          const Color(0xFF00E676).withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Stroke Line
    final strokePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Rider Current Position Marker (Pulsing Dot)
    final riderX = distToX(currentDistanceKm);
    // Interpolate rider Y
    double riderY = firstY;
    for (int i = 0; i < points.length - 1; i++) {
      if (currentDistanceKm >= points[i].distanceKm &&
          currentDistanceKm <= points[i + 1].distanceKm) {
        final ratio = (currentDistanceKm - points[i].distanceKm) /
            math.max(0.0001, points[i + 1].distanceKm - points[i].distanceKm);
        final interpEle = points[i].elevationM +
            (points[i + 1].elevationM - points[i].elevationM) * ratio;
        riderY = eleToY(interpEle);
        break;
      }
    }

    // Rider position indicator line
    final riderLinePaint = Paint()
      ..color = const Color(0xFFFFF01F).withOpacity(0.5)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(riderX, 0),
      Offset(riderX, size.height - padBottom),
      riderLinePaint,
    );

    // Rider Pulsing Circle
    final glowPaint = Paint()..color = const Color(0xFFFFF01F).withOpacity(0.4);
    canvas.drawCircle(Offset(riderX, riderY), 7.0, glowPaint);

    final dotPaint = Paint()..color = const Color(0xFFFFF01F);
    canvas.drawCircle(Offset(riderX, riderY), 4.5, dotPaint);
    canvas.drawCircle(
      Offset(riderX, riderY),
      4.5,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ElevationChartPainter oldDelegate) {
    return oldDelegate.currentDistanceKm != currentDistanceKm ||
        oldDelegate.points != points;
  }
}
