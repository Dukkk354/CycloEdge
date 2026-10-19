import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/ble_service.dart';
import '../../services/profile_service.dart';
import '../sensor_modal.dart';

class ProfileScreen extends StatefulWidget {
  final ProfileService profileService;
  final BleService bleService;

  const ProfileScreen({
    super.key,
    required this.profileService,
    required this.bleService,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _restingHrController;
  late TextEditingController _customMaxHrController;

  late String _gender;
  late String _defaultActivity;
  late String _speedUnit;
  late bool _useCustomMaxHr;

  @override
  void initState() {
    super.initState();
    _loadProfileValues();
  }

  void _loadProfileValues() {
    final p = widget.profileService.profile;
    _nameController = TextEditingController(text: p.name);
    _ageController = TextEditingController(text: p.age.toString());
    _weightController = TextEditingController(text: p.weightKg.toStringAsFixed(1));
    _heightController = TextEditingController(text: p.heightCm.toStringAsFixed(0));
    _restingHrController = TextEditingController(text: p.restingHr.toString());
    _customMaxHrController = TextEditingController(
      text: p.customMaxHr != null ? p.customMaxHr.toString() : '',
    );
    _gender = p.gender;
    _defaultActivity = p.defaultActivity;
    _speedUnit = p.speedUnit;
    _useCustomMaxHr = p.customMaxHr != null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _restingHrController.dispose();
    _customMaxHrController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final age = int.tryParse(_ageController.text) ?? 28;
    final weight = double.tryParse(_weightController.text) ?? 70.0;
    final height = double.tryParse(_heightController.text) ?? 175.0;
    final resting = int.tryParse(_restingHrController.text) ?? 60;
    final customMax = _useCustomMaxHr
        ? (int.tryParse(_customMaxHrController.text) ?? 190)
        : null;

    final updated = widget.profileService.profile.copyWith(
      name: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : 'Atlet CycloEdge',
      age: age,
      gender: _gender,
      weightKg: weight,
      heightCm: height,
      restingHr: resting,
      customMaxHr: customMax,
      defaultActivity: _defaultActivity,
      speedUnit: _speedUnit,
    );

    widget.profileService.updateProfile(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profil & Zona Detak Jantung Disimpan!'),
        backgroundColor: Color(0xFF00E676),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.profileService,
      builder: (context, _) {
        final profile = widget.profileService.profile;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            title: const Text(
              'Profil & Pengaturan',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            actions: [
              TextButton.icon(
                onPressed: _saveProfile,
                icon: const Icon(Icons.check, color: Color(0xFF00E5FF), size: 18),
                label: const Text(
                  'Simpan',
                  style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Athlete Banner Header
              _buildAthleteHeader(profile),

              const SizedBox(height: 20),

              // Section 1: Data Diri Atlet
              _buildSectionTitle('DATA DIRI & FISIK', Icons.person),
              const SizedBox(height: 10),
              _buildProfileFormCard(),

              const SizedBox(height: 24),

              // Section 2: Zona Detak Jantung
              _buildSectionTitle('ZONA DETAK JANTUNG (HR ZONES)', Icons.favorite),
              const SizedBox(height: 4),
              Text(
                'Dihitung otomatis dari Max HR: ${profile.maxHr} BPM (${_useCustomMaxHr ? "Manual Override" : "Formula Tanaka: 208 - 0.7xUsia"})',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 12),
              _buildHrZonesCard(profile),

              const SizedBox(height: 24),

              // Section 3: Info Kalori & Formula
              _buildSectionTitle('KALKULASI KALORI', Icons.local_fire_department),
              const SizedBox(height: 10),
              _buildCalorieFormulaCard(profile),

              const SizedBox(height: 24),

              // Section 4: Pengaturan Preferensi
              _buildSectionTitle('PREFERENSI APLIKASI', Icons.tune),
              const SizedBox(height: 10),
              _buildAppSettingsCard(),

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00E5FF), size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildAthleteHeader(UserProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF00E5FF),
            child: Text(
              profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'A',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${profile.age} Thn • ${profile.weightKg.toStringAsFixed(1)} kg • ${profile.gender == "male" ? "Pria" : "Wanita"}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF00E676)),
            ),
            child: Column(
              children: [
                const Text('MAX HR', style: TextStyle(color: Color(0xFF00E676), fontSize: 9, fontWeight: FontWeight.bold)),
                Text(
                  '${profile.maxHr}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Column(
        children: [
          _buildTextField(
            controller: _nameController,
            label: 'Nama Atlet',
            icon: Icons.badge,
            hint: 'Masukkan nama Anda',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _ageController,
                  label: 'Usia (Tahun)',
                  icon: Icons.cake,
                  keyboardType: TextInputType.number,
                  hint: '28',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Jenis Kelamin', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      dropdownColor: const Color(0xFF222222),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Pria')),
                        DropdownMenuItem(value: 'female', child: Text('Wanita')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _gender = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _weightController,
                  label: 'Berat Badan (kg)',
                  icon: Icons.monitor_weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  hint: '70.0',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _heightController,
                  label: 'Tinggi Badan (cm)',
                  icon: Icons.height,
                  keyboardType: TextInputType.number,
                  hint: '175',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _restingHrController,
                  label: 'Resting HR (BPM)',
                  icon: Icons.nightlight_round,
                  keyboardType: TextInputType.number,
                  hint: '60',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Custom Max HR', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        Switch(
                          value: _useCustomMaxHr,
                          activeColor: const Color(0xFF00E5FF),
                          onChanged: (val) => setState(() => _useCustomMaxHr = val),
                        ),
                      ],
                    ),
                    if (_useCustomMaxHr)
                      _buildTextField(
                        controller: _customMaxHrController,
                        label: 'Manual Max HR',
                        icon: Icons.speed,
                        keyboardType: TextInputType.number,
                        hint: '190',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHrZonesCard(UserProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Column(
        children: [
          _buildZoneRow(
            zone: 'Z1',
            name: 'Active Recovery',
            range: '< ${profile.z1Max} BPM',
            color: const Color(0xFF64B5F6),
            pct: '< 60%',
          ),
          const Divider(color: Colors.white10, height: 16),
          _buildZoneRow(
            zone: 'Z2',
            name: 'Aerobic / Endurance',
            range: '${profile.z2Min} - ${profile.z2Max} BPM',
            color: const Color(0xFF00E5FF),
            pct: '60 - 70%',
            highlight: 'Fat Burn Optimal',
          ),
          const Divider(color: Colors.white10, height: 16),
          _buildZoneRow(
            zone: 'Z3',
            name: 'Tempo / Aerobic Power',
            range: '${profile.z3Min} - ${profile.z3Max} BPM',
            color: const Color(0xFF00E676),
            pct: '70 - 80%',
          ),
          const Divider(color: Colors.white10, height: 16),
          _buildZoneRow(
            zone: 'Z4',
            name: 'Lactate Threshold',
            range: '${profile.z4Min} - ${profile.z4Max} BPM',
            color: const Color(0xFFFFB300),
            pct: '80 - 90%',
          ),
          const Divider(color: Colors.white10, height: 16),
          _buildZoneRow(
            zone: 'Z5',
            name: 'VO2 Max / Anaerobic',
            range: '> ${profile.z5Min} BPM',
            color: const Color(0xFFFF1744),
            pct: '> 90%',
          ),
        ],
      ),
    );
  }

  Widget _buildZoneRow({
    required String zone,
    required String name,
    required String range,
    required Color color,
    required String pct,
    String? highlight,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color),
          ),
          child: Text(
            zone,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  if (highlight != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        highlight,
                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              Text(pct, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ),
        Text(
          range,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildCalorieFormulaCard(UserProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate, color: Color(0xFFFFB300), size: 18),
              SizedBox(width: 8),
              Text(
                'Formula Keytel & METs',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Kalori dihitung presisi secara real-time berdasarkan berat badan (${profile.weightKg} kg), usia (${profile.age} thn), jenis kelamin (${profile.gender == "male" ? "Pria" : "Wanita"}), dan detak jantung dari sensor COROS Anda.',
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Column(
        children: [
          // Default Activity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Aktivitas Utama', style: TextStyle(color: Colors.white, fontSize: 13)),
              DropdownButton<String>(
                value: _defaultActivity,
                dropdownColor: const Color(0xFF222222),
                style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 13),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'cycling', child: Text('🚴 Sepeda / Gowes')),
                  DropdownMenuItem(value: 'running', child: Text('🏃 Lari / Run')),
                  DropdownMenuItem(value: 'walking', child: Text('🚶 Jalan Kaki / Walk')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _defaultActivity = val);
                },
              ),
            ],
          ),
          const Divider(color: Colors.white10),

          // Speed Unit
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Format Kecepatan', style: TextStyle(color: Colors.white, fontSize: 13)),
              DropdownButton<String>(
                value: _speedUnit,
                dropdownColor: const Color(0xFF222222),
                style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 13),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'km/h', child: Text('km/h (Speed)')),
                  DropdownMenuItem(value: 'pace', child: Text('Pace (min/km)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _speedUnit = val);
                },
              ),
            ],
          ),
          const Divider(color: Colors.white10),

          // Sensor BLE Pairing shortcut
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bluetooth, color: Color(0xFF00E676)),
            title: const Text('Sensor BLE & Watch COROS', style: TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: Text(
              '${widget.bleService.connectedSensors.length} sensor terhubung',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => SensorModal.show(context, widget.bleService),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            prefixIcon: Icon(icon, color: const Color(0xFF00E5FF), size: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
