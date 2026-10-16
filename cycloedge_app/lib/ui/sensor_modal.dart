import 'package:flutter/material.dart';
import '../services/ble_service.dart';

class SensorModal extends StatelessWidget {
  final BleService bleService;

  const SensorModal({super.key, required this.bleService});

  static Future<void> show(BuildContext context, BleService bleService) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SensorModal(bleService: bleService),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: bleService,
      builder: (context, _) {
        final connected = bleService.connectedSensors.values.toList();
        final scanResults = bleService.scanResults;

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BLUETOOTH SENSORS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'COROS Watch, HR straps, Cadence, Power',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: bleService.isScanning
                            ? () => bleService.stopScan()
                            : () => bleService.startScan(),
                        icon: Icon(
                          bleService.isScanning ? Icons.stop_circle_outlined : Icons.refresh,
                          color: const Color(0xFF00E5FF),
                        ),
                        tooltip: bleService.isScanning ? 'Stop Scan' : 'Scan',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (bleService.isScanning)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(
                        backgroundColor: Color(0xFF1E1E1E),
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                      ),
                    ),

                  // Connected sensors section
                  if (connected.isNotEmpty) ...[
                    const Text(
                      'CONNECTED SENSORS',
                      style: TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...connected.map((s) => _buildSensorTile(
                          name: s.name,
                          subtitle: _sensorTypeLabel(s.type),
                          isConnected: true,
                          onAction: () => bleService.disconnectDevice(s.device),
                        )),
                    const SizedBox(height: 16),
                  ],

                  // Discovered devices section
                  const Text(
                    'AVAILABLE SENSORS',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (scanResults.isEmpty && !bleService.isScanning)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No sensors found.\nMake sure "Broadcast HR" is enabled on your COROS watch.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...scanResults.map((result) {
                      final name = result.device.platformName.isNotEmpty
                          ? result.device.platformName
                          : result.device.remoteId.str;
                      final isAlreadyConnected =
                          bleService.connectedSensors.containsKey(result.device.remoteId.str);

                      return _buildSensorTile(
                        name: name,
                        subtitle: 'RSSI: ${result.rssi} dBm',
                        isConnected: isAlreadyConnected,
                        onAction: isAlreadyConnected
                            ? () => bleService.disconnectDevice(result.device)
                            : () => bleService.connectDevice(result.device),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String _sensorTypeLabel(SensorType type) {
    switch (type) {
      case SensorType.heartRate:
        return 'Heart Rate Monitor (COROS/Strap)';
      case SensorType.cadence:
        return 'Cycling Cadence Sensor';
      case SensorType.power:
        return 'Cycling Power Meter';
      case SensorType.speed:
        return 'Speed Sensor';
      default:
        return 'BLE Sensor';
    }
  }

  Widget _buildSensorTile({
    required String name,
    required String subtitle,
    required bool isConnected,
    required VoidCallback onAction,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isConnected ? const Color(0xFF00E676).withOpacity(0.4) : Colors.white12,
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.bluetooth_audio,
          color: isConnected ? const Color(0xFF00E676) : Colors.white54,
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isConnected ? const Color(0xFF2C2C2C) : const Color(0xFF00E5FF),
            foregroundColor: isConnected ? Colors.redAccent : Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: onAction,
          child: Text(
            isConnected ? 'Disconnect' : 'Connect',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

