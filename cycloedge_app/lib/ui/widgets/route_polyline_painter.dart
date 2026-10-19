import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

class RoutePolylineWidget extends StatelessWidget {
  final List<LatLng> coordinates;
  final Color lineColor;
  final double lineWidth;
  final bool showStartEndDots;

  const RoutePolylineWidget({
    super.key,
    required this.coordinates,
    this.lineColor = const Color(0xFFFC4C02), // Strava signature orange
    this.lineWidth = 3.5,
    this.showStartEndDots = true,
  });

  @override
  Widget build(BuildContext context) {
    if (coordinates.length < 2) {
      return Center(
        child: Icon(
          Icons.route,
          size: 48,
          color: lineColor.withOpacity(0.3),
        ),
      );
    }

    return CustomPaint(
      size: Size.infinite,
      painter: _PolylinePainter(
        coordinates: coordinates,
        lineColor: lineColor,
        lineWidth: lineWidth,
        showStartEndDots: showStartEndDots,
      ),
    );
  }
}

class _PolylinePainter extends CustomPainter {
  final List<LatLng> coordinates;
  final Color lineColor;
  final double lineWidth;
  final bool showStartEndDots;

  _PolylinePainter({
    required this.coordinates,
    required this.lineColor,
    required this.lineWidth,
    required this.showStartEndDots,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (coordinates.length < 2) return;

    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLon = coordinates.first.longitude;
    double maxLon = coordinates.first.longitude;

    for (final pt in coordinates) {
      if (pt.latitude < minLat) minLat = pt.latitude;
      if (pt.latitude > maxLat) maxLat = pt.latitude;
      if (pt.longitude < minLon) minLon = pt.longitude;
      if (pt.longitude > maxLon) maxLon = pt.longitude;
    }

    final double latSpan = maxLat - minLat;
    final double lonSpan = maxLon - minLon;

    // Prevent zero division
    final safeLatSpan = latSpan == 0 ? 0.0001 : latSpan;
    final safeLonSpan = lonSpan == 0 ? 0.0001 : lonSpan;

    const double padding = 24.0;
    final double drawW = size.width - (padding * 2);
    final double drawH = size.height - (padding * 2);

    if (drawW <= 0 || drawH <= 0) return;

    // Aspect ratio preservation
    final double scaleX = drawW / safeLonSpan;
    final double scaleY = drawH / safeLatSpan;
    final double scale = math.min(scaleX, scaleY);

    final double offsetX = padding + (drawW - (safeLonSpan * scale)) / 2;
    final double offsetY = padding + (drawH - (safeLatSpan * scale)) / 2;

    Offset latLngToOffset(LatLng pt) {
      final x = offsetX + (pt.longitude - minLon) * scale;
      // Invert Y because latitude increases northward (up), but canvas Y increases downward
      final y = offsetY + (maxLat - pt.latitude) * scale;
      return Offset(x, y);
    }

    final path = Path();
    final firstPoint = latLngToOffset(coordinates.first);
    path.moveTo(firstPoint.dx, firstPoint.dy);

    for (int i = 1; i < coordinates.length; i++) {
      final pt = latLngToOffset(coordinates[i]);
      path.lineTo(pt.dx, pt.dy);
    }

    // Shadow / Glow behind route
    final shadowPaint = Paint()
      ..color = lineColor.withOpacity(0.3)
      ..strokeWidth = lineWidth + 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, shadowPaint);

    // Main Polyline
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    // Start & End Dots
    if (showStartEndDots && coordinates.isNotEmpty) {
      final startPaint = Paint()..color = const Color(0xFF00E676); // Green dot start
      canvas.drawCircle(firstPoint, 5.0, startPaint);
      canvas.drawCircle(firstPoint, 5.0, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);

      final lastPoint = latLngToOffset(coordinates.last);
      final endPaint = Paint()..color = const Color(0xFFFF1744); // Red/Orange dot end
      canvas.drawCircle(lastPoint, 5.0, endPaint);
      canvas.drawCircle(lastPoint, 5.0, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant _PolylinePainter oldDelegate) {
    return oldDelegate.coordinates != coordinates ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.lineWidth != lineWidth;
  }
}
