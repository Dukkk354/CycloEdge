import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/activity_record.dart';
import '../../models/user_profile.dart';
import '../../services/activity_service.dart';
import '../../services/ble_service.dart';
import '../../services/location_service.dart';
import '../../services/profile_service.dart';
import '../../services/strava_service.dart';
import '../share/activity_share_screen.dart';
import '../widgets/route_polyline_painter.dart';

class HomeScreen extends StatelessWidget {
  final ActivityService activityService;
  final ProfileService profileService;
  final LocationService locationService;
  final BleService bleService;
  final StravaService? stravaService;
  final VoidCallback onStartRecord;

  const HomeScreen({
    super.key,
    required this.activityService,
    required this.profileService,
    required this.locationService,
    required this.bleService,
    this.stravaService,
    required this.onStartRecord,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([activityService, profileService, bleService]),
      builder: (context, _) {
        final profile = profileService.profile;
        final activities = activityService.activities;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.directions_bike, color: Color(0xFF00E5FF), size: 20),
                ),
                const SizedBox(width: 8),
                const Text(
                  'CYCLOEDGE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            actions: [
              // BLE Status Pill
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bleService.connectedSensors.isNotEmpty
                      ? const Color(0xFF00E676).withOpacity(0.15)
                      : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: bleService.connectedSensors.isNotEmpty
                        ? const Color(0xFF00E676)
                        : Colors.white24,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bluetooth,
                      size: 13,
                      color: bleService.connectedSensors.isNotEmpty
                          ? const Color(0xFF00E676)
                          : Colors.white38,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      bleService.connectedSensors.isNotEmpty
                          ? '${bleService.connectedSensors.length} SENSOR'
                          : 'COROS BLE',
                      style: TextStyle(
                        color: bleService.connectedSensors.isNotEmpty
                            ? const Color(0xFF00E676)
                            : Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // User Greeting Banner
              _buildGreetingCard(profile),

              const SizedBox(height: 14),

              // Weekly Distance Goal Progress
              _buildWeeklyGoalCard(profile, activityService),

              const SizedBox(height: 14),

              // Aggregated Stats (Total Distance, Hours, Calories, Sessions)
              _buildStatsOverview(activityService),

              const SizedBox(height: 14),

              // Personal Records (PR) Trophy Shelf
              _buildPersonalRecordsShelf(activityService),

              const SizedBox(height: 18),

              // Quick Workout Starter
              _buildQuickStartCard(context, profile),

              const SizedBox(height: 24),

              // Recent Activities Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AKTIVITAS TERBARU',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '${activities.length} Sesi',
                    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              if (activities.isEmpty)
                _buildEmptyState()
              else
                ...activities.map((act) => _buildActivityCard(context, act, profile)),

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGreetingCard(profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A24), Color(0xFF101016)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF00E5FF),
            child: Text(
              profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'A',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, ${profile.name}!',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Siap gowes atau jalan santai hari ini? Pantau detak jantung & rute Anda.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview(ActivityService service) {
    final hours = service.totalDuration.inHours;
    final mins = service.totalDuration.inMinutes % 60;
    final timeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryMetric(
              label: 'TOTAL JARAK',
              value: service.totalDistanceKm.toStringAsFixed(1),
              unit: 'km',
              color: const Color(0xFF00E5FF),
            ),
          ),
          Container(width: 1, height: 36, color: Colors.white10),
          Expanded(
            child: _buildSummaryMetric(
              label: 'WAKTU',
              value: timeStr,
              unit: '',
              color: Colors.white,
            ),
          ),
          Container(width: 1, height: 36, color: Colors.white10),
          Expanded(
            child: _buildSummaryMetric(
              label: 'KALORI',
              value: '${service.totalCalories}',
              unit: 'kcal',
              color: const Color(0xFFFFB300),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyGoalCard(UserProfile profile, ActivityService service) {
    final goalKm = profile.weeklyGoalKm > 0 ? profile.weeklyGoalKm : 100.0;
    final currentKm = service.currentWeekDistanceKm;
    final progress = (currentKm / goalKm).clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final remainingKm = (goalKm - currentKm).clamp(0.0, 9999.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF141820), Color(0xFF0F1117)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.track_changes, color: Color(0xFF00E5FF), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'TARGET MINGGU INI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$percent%',
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currentKm.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ ${goalKm.toStringAsFixed(0)} km',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                remainingKm <= 0 ? 'Target Tercapai! 🎉' : 'Sisa ${remainingKm.toStringAsFixed(1)} km',
                style: TextStyle(
                  color: remainingKm <= 0 ? const Color(0xFF00E676) : Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                remainingKm <= 0 ? const Color(0xFF00E676) : const Color(0xFF00E5FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalRecordsShelf(ActivityService service) {
    final paceMin = service.fastestPaceMinPerKm;
    final paceStr = paceMin > 0 && paceMin < 900
        ? '${paceMin.floor()}:${((paceMin - paceMin.floor()) * 60).round().toString().padLeft(2, '0')}/km'
        : '--:--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events, color: Color(0xFFFFB300), size: 18),
              SizedBox(width: 8),
              Text(
                'REKOR PRIBADI (PRs)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPRTile(
                  icon: Icons.straighten,
                  iconColor: const Color(0xFF00E5FF),
                  title: 'Jarak Terjauh',
                  value: '${service.longestRideKm.toStringAsFixed(1)} km',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPRTile(
                  icon: Icons.speed,
                  iconColor: const Color(0xFFFF5252),
                  title: 'Top Speed',
                  value: '${service.maxSpeedEverKmh.toStringAsFixed(1)} km/h',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildPRTile(
                  icon: Icons.terrain,
                  iconColor: const Color(0xFF00E676),
                  title: 'Tanjakan Max',
                  value: '${service.maxElevationEverM.round()} m',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPRTile(
                  icon: Icons.timer,
                  iconColor: const Color(0xFFFFB300),
                  title: 'Pace Tercepat',
                  value: paceStr,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPRTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStartCard(BuildContext context, profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PILIH AKTIVITAS & MULAI',
            style: TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActivityOption(
                icon: Icons.directions_bike,
                label: 'Sepeda',
                isSelected: locationService.telemetry.activityType == 'cycling',
                onTap: () => locationService.setActivityType('cycling'),
              ),
              const SizedBox(width: 8),
              _buildActivityOption(
                icon: Icons.directions_run,
                label: 'Lari',
                isSelected: locationService.telemetry.activityType == 'running',
                onTap: () => locationService.setActivityType('running'),
              ),
              const SizedBox(width: 8),
              _buildActivityOption(
                icon: Icons.directions_walk,
                label: 'Jalan Kaki',
                isSelected: locationService.telemetry.activityType == 'walking',
                onTap: () => locationService.setActivityType('walking'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 4,
              ),
              onPressed: onStartRecord,
              icon: const Icon(Icons.play_arrow, size: 24),
              label: const Text(
                'BUKA COCKPIT & REKAM',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.15) : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF00E5FF) : Colors.white12,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF00E5FF) : Colors.white54, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, ActivityRecord act, profile) {
    final dateStr = DateFormat('dd MMM yyyy • HH:mm').format(act.startTime);
    final isRunOrWalk = act.activityType != 'cycling';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card (Type icon, Title, Share Button)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    act.activityType == 'walking'
                        ? Icons.directions_walk
                        : act.activityType == 'running'
                            ? Icons.directions_run
                            : Icons.directions_bike,
                    color: const Color(0xFF00E5FF),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        act.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ),
                // Strava Share Button
                IconButton(
                  icon: const Icon(Icons.share, color: Color(0xFFFC4C02), size: 20),
                  tooltip: 'Bagikan Aktivitas (Strava Template)',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActivityShareScreen(
                          activity: act,
                          profile: profile,
                          stravaService: stravaService,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Route Polyline thumbnail if points exist
          if (act.breadcrumbs.length > 1)
            Container(
              height: 120,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: RoutePolylineWidget(
                  coordinates: act.breadcrumbs,
                  lineColor: const Color(0xFFFC4C02),
                  lineWidth: 3.0,
                ),
              ),
            ),

          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCardMetric('JARAK', '${act.distanceKm.toStringAsFixed(2)} km'),
                _buildCardMetric('WAKTU', act.formattedDuration),
                _buildCardMetric(
                  isRunOrWalk ? 'PACE' : 'AVG SPD',
                  isRunOrWalk ? act.formattedPace : '${act.avgSpeedKmh.toStringAsFixed(1)} km/h',
                ),
                _buildCardMetric('KALORI', '${act.calories} kcal'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.directions_bike_outlined, size: 48, color: Colors.white24),
          SizedBox(height: 12),
          Text(
            'Belum ada aktivitas yang direkam',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Tekan "Mulai Rekam" untuk memulai sesi olahraga pertama Anda!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

