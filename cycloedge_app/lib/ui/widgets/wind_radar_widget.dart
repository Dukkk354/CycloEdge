import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/weather_service.dart';

class WindRadarWidget extends StatelessWidget {
  final WeatherService weatherService;
  final bool isCompact;

  const WindRadarWidget({
    super.key,
    required this.weatherService,
    this.isCompact = false,
  });

  Color _getWindColor(RelativeWindType type) {
    switch (type) {
      case RelativeWindType.calm:
        return const Color(0xFF00E5FF);
      case RelativeWindType.headwind:
        return const Color(0xFFFF1744); // Red: resisting
      case RelativeWindType.tailwind:
        return const Color(0xFF00E676); // Green: assisting
      case RelativeWindType.crosswindRight:
      case RelativeWindType.crosswindLeft:
        return const Color(0xFFFFB300); // Amber: crosswind caution
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: weatherService,
      builder: (context, _) {
        final wind = weatherService.currentWind;

        if (wind == null) {
          if (weatherService.isLoading) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF161618),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF00E5FF)),
                  ),
                  SizedBox(width: 6),
                  Text('Cek Angin...', style: TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }

        final windColor = _getWindColor(wind.windType);
        final visualAngleRad = wind.arrowVisualAngleDeg * (math.pi / 180.0);
        final speedKmh = wind.windSpeedKmh.round();
        final tempC = wind.temperatureC.round();

        return GestureDetector(
          onTap: () => _showWindDetailDialog(context, wind),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF141416).withOpacity(0.92),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: windColor.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rotating Arrow indicating relative wind flow
                Transform.rotate(
                  angle: visualAngleRad,
                  child: Icon(
                    Icons.navigation,
                    color: windColor,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 5),

                // Speed and Type label
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$speedKmh km/h',
                          style: TextStyle(
                            color: windColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$tempC°C',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      wind.label,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWindDetailDialog(BuildContext context, WindData wind) {
    final windColor = _getWindColor(wind.windType);
    final minutesAgo = DateTime.now().difference(wind.timestamp).inMinutes;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141418),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: windColor.withOpacity(0.6)),
        ),
        title: Row(
          children: [
            Icon(Icons.air, color: windColor, size: 22),
            const SizedBox(width: 8),
            const Text(
              'LIVE WIND RADAR',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Center Compass Visual
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Cardinal markers
                    const Positioned(top: 6, child: Text('N', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold))),
                    const Positioned(bottom: 6, child: Text('S', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold))),
                    const Positioned(left: 6, child: Text('W', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold))),
                    const Positioned(right: 6, child: Text('E', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold))),

                    // Center bike silhouette
                    const Icon(Icons.directions_bike, color: Colors.white70, size: 24),

                    // Rotating wind direction arrow
                    Transform.rotate(
                      angle: wind.arrowVisualAngleDeg * (math.pi / 180.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.arrow_upward, color: windColor, size: 20),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Metrics table
            _buildDialogRow('Kondisi Angin', wind.label, windColor),
            _buildDialogRow('Kecepatan Angin', '${wind.windSpeedKmh.toStringAsFixed(1)} km/h', Colors.white),
            _buildDialogRow('Hembusan Maks (Gusts)', '${wind.windGustsKmh.toStringAsFixed(1)} km/h', const Color(0xFFFFB300)),
            _buildDialogRow('Arah Tiupan Meteorologi', '${wind.windDirectionDeg.round()}°', Colors.white70),
            _buildDialogRow('Suhu Udara', '${wind.temperatureC.toStringAsFixed(1)}°C', const Color(0xFF00E5FF)),
            _buildDialogRow('Cuaca', wind.weatherDescription, Colors.white),

            const SizedBox(height: 12),
            const Divider(color: Colors.white10),
            const SizedBox(height: 6),

            Text(
              'Diperbarui ${minutesAgo == 0 ? "baru saja" : "$minutesAgo menit lalu"}. Otomatis diperbarui setiap 10 menit.',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: () {
              Navigator.pop(ctx);
              weatherService.refreshCurrentLocation();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
