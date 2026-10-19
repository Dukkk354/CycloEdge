import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/activity_record.dart';
import '../../models/user_profile.dart';
import '../widgets/route_polyline_painter.dart';

class ActivityShareScreen extends StatefulWidget {
  final ActivityRecord activity;
  final UserProfile profile;

  const ActivityShareScreen({
    super.key,
    required this.activity,
    required this.profile,
  });

  @override
  State<ActivityShareScreen> createState() => _ActivityShareScreenState();
}

class _ActivityShareScreenState extends State<ActivityShareScreen> {
  final GlobalKey _cardKey = GlobalKey();
  int _selectedTemplate = 0;
  bool _isExporting = false;
  late TextEditingController _titleController;

  final List<String> _templateNames = [
    'Strava Classic',
    'AMOLED Cyberpunk',
    'Minimalist Modern',
    'Story 9:16',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.activity.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _shareImage() async {
    setState(() => _isExporting = true);
    try {
      // Small delay to ensure render tree is fully painted
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Gagal menemukan render objek kartu share');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Gagal mengonversi gambar');

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/cycloedge_share_$now.png');
      await file.writeAsBytes(pngBytes);

      final shareText =
          '${_titleController.text} • ${widget.activity.distanceKm.toStringAsFixed(2)} km bersama CycloEdge!';

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: shareText,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membagikan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Bagikan Aktivitas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: Color(0xFF00E5FF)),
            tooltip: 'Ganti Judul',
            onPressed: _showEditTitleDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Template Selector Chips
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _templateNames.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelected = _selectedTemplate == index;
                  return ChoiceChip(
                    label: Text(
                      _templateNames[index],
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF00E5FF),
                    backgroundColor: const Color(0xFF1E1E1E),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTemplate = index);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Card Preview Area
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: _buildSelectedTemplate(),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Share Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFC4C02), // Strava orange
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _isExporting ? null : _shareImage,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.share, size: 20),
                  label: Text(
                    _isExporting ? 'Memproses Kartu...' : 'Bagikan ke WhatsApp / IG / Medsos',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTitleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Ganti Judul Aktivitas', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _titleController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Contoh: Gowes Pagi Dago Pakar',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E5FF))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTemplate() {
    switch (_selectedTemplate) {
      case 0:
        return _buildStravaClassicTemplate();
      case 1:
        return _buildAmoledCyberpunkTemplate();
      case 2:
        return _buildMinimalistTemplate();
      case 3:
        return _buildStoryTemplate();
      default:
        return _buildStravaClassicTemplate();
    }
  }

  // ==========================================
  // TEMPLATE 1: STRAVA CLASSIC (Orange & Dark)
  // ==========================================
  Widget _buildStravaClassicTemplate() {
    final dateStr = DateFormat('EEEE, d MMMM yyyy • HH:mm').format(widget.activity.startTime);
    final isRunOrWalk = widget.activity.activityType != 'cycling';

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: User & Brand
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFFC4C02),
                  child: Text(
                    widget.profile.name.isNotEmpty ? widget.profile.name[0].toUpperCase() : 'C',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.profile.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFC4C02).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'CYCLOEDGE',
                    style: TextStyle(
                      color: Color(0xFFFC4C02),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Activity Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              _titleController.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Route Polyline Canvas
          Container(
            height: 200,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: RoutePolylineWidget(
                coordinates: widget.activity.breadcrumbs,
                lineColor: const Color(0xFFFC4C02),
                lineWidth: 4.0,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 4-Stat Metric Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    label: 'JARAK',
                    value: widget.activity.distanceKm.toStringAsFixed(2),
                    unit: 'km',
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    label: 'WAKTU',
                    value: widget.activity.formattedDuration,
                    unit: '',
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    label: isRunOrWalk ? 'PACE RATA2' : 'KECEPATAN',
                    value: isRunOrWalk
                        ? widget.activity.formattedPace
                        : widget.activity.avgSpeedKmh.toStringAsFixed(1),
                    unit: isRunOrWalk ? '/km' : 'km/h',
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    label: 'ELEVASI',
                    value: '${widget.activity.elevationGainM.round()}',
                    unit: 'm',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Extra footer: Calories & Heart Rate
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF161618),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Color(0xFFFFB300), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.activity.calories} kcal',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (widget.activity.avgHr > 0)
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: Color(0xFFFF1744), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Avg ${widget.activity.avgHr} bpm (Max ${widget.activity.maxHr})',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TEMPLATE 2: AMOLED CYBERPUNK (Neon Cyan & Green)
  // ==========================================
  Widget _buildAmoledCyberpunkTemplate() {
    final dateStr = DateFormat('dd MMM yyyy • HH:mm').format(widget.activity.startTime);

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cyberpunk Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E676),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'CYCLOEDGE // TELEMETRY',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              _titleController.text.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),

          // Route Polyline with Neon Cyan Glow
          Container(
            height: 210,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF222222)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: RoutePolylineWidget(
                coordinates: widget.activity.breadcrumbs,
                lineColor: const Color(0xFF00E5FF),
                lineWidth: 3.5,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Neon Stats Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildCyberStat(
                    label: 'TOTAL DISTANCE',
                    value: widget.activity.distanceKm.toStringAsFixed(2),
                    unit: 'KM',
                    valueColor: const Color(0xFF00E5FF),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCyberStat(
                    label: 'MOVING TIME',
                    value: widget.activity.formattedDuration,
                    unit: '',
                    valueColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildCyberStat(
                    label: 'AVG SPEED',
                    value: widget.activity.avgSpeedKmh.toStringAsFixed(1),
                    unit: 'KM/H',
                    valueColor: const Color(0xFF00E676),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCyberStat(
                    label: 'TOTAL ASCENT',
                    value: '${widget.activity.elevationGainM.round()}',
                    unit: 'M',
                    valueColor: const Color(0xFFFFB300),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Cyberpunk Tag Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0F0F0F),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BURN: ${widget.activity.calories} KCAL',
                  style: const TextStyle(
                    color: Color(0xFFFFB300),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'MAX SPEED: ${widget.activity.maxSpeedKmh.toStringAsFixed(1)} KM/H',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TEMPLATE 3: MINIMALIST MODERN (Clean White & Slate)
  // ==========================================
  Widget _buildMinimalistTemplate() {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.profile.name.toUpperCase(),
                style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold),
              ),
              const Text(
                'CYCLOEDGE',
                style: TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 2.0, fontWeight: FontWeight.w900),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            _titleController.text,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          // Giant Distance Display
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                widget.activity.distanceKm.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2.0,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'KILOMETERS',
                style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Route Outline
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C21),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: RoutePolylineWidget(
                coordinates: widget.activity.breadcrumbs,
                lineColor: Colors.white,
                lineWidth: 3.0,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 3 Bottom Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMinimalStat('TIME', widget.activity.formattedDuration),
              _buildMinimalStat('AVG SPEED', '${widget.activity.avgSpeedKmh.toStringAsFixed(1)} km/h'),
              _buildMinimalStat('CALORIES', '${widget.activity.calories} kcal'),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TEMPLATE 4: STORY 9:16 (Instagram & WhatsApp Story)
  // ==========================================
  Widget _buildStoryTemplate() {
    return Container(
      width: 320,
      height: 568, // 9:16 approx
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A24), Color(0xFF0A0A0E)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Header
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFC4C02).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'CYCLOEDGE WORKOUT',
                  style: TextStyle(
                    color: Color(0xFFFC4C02),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _titleController.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                DateFormat('EEEE, d MMM yyyy').format(widget.activity.startTime),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),

          // Center: Large Route Outline
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: RoutePolylineWidget(
                  coordinates: widget.activity.breadcrumbs,
                  lineColor: const Color(0xFF00E5FF),
                  lineWidth: 4.0,
                ),
              ),
            ),
          ),

          // Bottom: Big Stat Floating Tiles
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStoryStatTile(
                      'DISTANCE',
                      widget.activity.distanceKm.toStringAsFixed(2),
                      'km',
                      const Color(0xFF00E5FF),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStoryStatTile(
                      'DURATION',
                      widget.activity.formattedDuration,
                      '',
                      Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildStoryStatTile(
                      'AVG PACE',
                      widget.activity.formattedPace,
                      '/km',
                      const Color(0xFF00E676),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStoryStatTile(
                      'CALORIES',
                      '${widget.activity.calories}',
                      'kcal',
                      const Color(0xFFFFB300),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  Widget _buildMetricItem({
    required String label,
    required String value,
    required String unit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCyberStat({
    required String label,
    required String value,
    required String unit,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStoryStatTile(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w900),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
