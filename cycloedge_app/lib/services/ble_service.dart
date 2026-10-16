import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum SensorType { heartRate, cadence, power, speed, unknown }

class BleSensorDevice {
  final BluetoothDevice device;
  final String name;
  final SensorType type;
  bool isConnected;

  BleSensorDevice({
    required this.device,
    required this.name,
    required this.type,
    this.isConnected = false,
  });
}

class BleService extends ChangeNotifier {
  // Standard GATT UUIDs (16-bit short representations)
  static final Guid hrServiceUuid = Guid('180D');
  static final Guid hrCharUuid = Guid('2A37');

  static final Guid cscServiceUuid = Guid('1816');
  static final Guid cscCharUuid = Guid('2A5B');

  static final Guid powerServiceUuid = Guid('1818');
  static final Guid powerCharUuid = Guid('2A63');

  final List<ScanResult> _scanResults = [];
  final Map<String, BleSensorDevice> _connectedSensors = {};
  final Map<String, StreamSubscription> _charSubscriptions = {};

  bool _isScanning = false;
  int _latestHeartRate = 0;
  int _latestCadence = 0;
  int _latestPower = 0;
  double _latestBleSpeed = 0.0;

  // Previous CSC readings for cadence & wheel speed calculation
  int? _lastCrankRev;
  int? _lastCrankTime;
  int? _lastWheelRev;
  int? _lastWheelTime;

  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);
  Map<String, BleSensorDevice> get connectedSensors => Map.unmodifiable(_connectedSensors);
  bool get isScanning => _isScanning;
  int get heartRate => _latestHeartRate;
  int get cadence => _latestCadence;
  int get power => _latestPower;
  double get bleSpeed => _latestBleSpeed;

  BleService() {
    FlutterBluePlus.isScanning.listen((scanning) {
      _isScanning = scanning;
      notifyListeners();
    });

    FlutterBluePlus.scanResults.listen((results) {
      _scanResults.clear();
      _scanResults.addAll(results);
      notifyListeners();
    });
  }

  /// Start BLE scanning with optional timeout
  Future<void> startScan({Duration timeout = const Duration(seconds: 12)}) async {
    _scanResults.clear();
    notifyListeners();

    try {
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        return;
      }
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );
    } catch (e) {
      debugPrint('Error starting BLE scan: $e');
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('Error stopping BLE scan: $e');
    }
  }

  /// Connect to a detected Bluetooth sensor (e.g. COROS Watch, HR strap, CSC sensor)
  Future<bool> connectDevice(BluetoothDevice device) async {
    try {
      await device.connect(
        license: License.nonprofit,
        autoConnect: false,
        timeout: const Duration(seconds: 15),
      );
      final services = await device.discoverServices();

      SensorType sensorType = SensorType.unknown;
      final devName = device.platformName.isNotEmpty ? device.platformName : device.remoteId.str;

      for (final service in services) {
        // 1. Heart Rate (COROS Watch Broadcast HR, Polar, Garmin, etc.)
        if (service.uuid == hrServiceUuid) {
          sensorType = SensorType.heartRate;
          for (final char in service.characteristics) {
            if (char.uuid == hrCharUuid) {
              await char.setNotifyValue(true);
              _charSubscriptions[device.remoteId.str] = char.lastValueStream.listen((data) {
                _parseHeartRate(data);
              });
            }
          }
        }

        // 2. Cycling Speed & Cadence
        if (service.uuid == cscServiceUuid) {
          if (sensorType == SensorType.unknown) sensorType = SensorType.cadence;
          for (final char in service.characteristics) {
            if (char.uuid == cscCharUuid) {
              await char.setNotifyValue(true);
              _charSubscriptions[device.remoteId.str] = char.lastValueStream.listen((data) {
                _parseCscData(data);
              });
            }
          }
        }

        // 3. Cycling Power
        if (service.uuid == powerServiceUuid) {
          sensorType = SensorType.power;
          for (final char in service.characteristics) {
            if (char.uuid == powerCharUuid) {
              await char.setNotifyValue(true);
              _charSubscriptions[device.remoteId.str] = char.lastValueStream.listen((data) {
                _parsePowerData(data);
              });
            }
          }
        }
      }

      _connectedSensors[device.remoteId.str] = BleSensorDevice(
        device: device,
        name: devName,
        type: sensorType,
        isConnected: true,
      );

      // Listen for unexpected disconnections
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          disconnectDevice(device);
        }
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error connecting to BLE device: $e');
      return false;
    }
  }

  /// Disconnect a sensor
  Future<void> disconnectDevice(BluetoothDevice device) async {
    final devId = device.remoteId.str;
    _charSubscriptions[devId]?.cancel();
    _charSubscriptions.remove(devId);
    _connectedSensors.remove(devId);

    try {
      await device.disconnect();
    } catch (e) {
      debugPrint('Error disconnecting device: $e');
    }

    // Reset sensor readouts if no more sensors of that type
    if (!_connectedSensors.values.any((s) => s.type == SensorType.heartRate)) {
      _latestHeartRate = 0;
    }
    if (!_connectedSensors.values.any((s) => s.type == SensorType.cadence)) {
      _latestCadence = 0;
    }
    if (!_connectedSensors.values.any((s) => s.type == SensorType.power)) {
      _latestPower = 0;
    }

    notifyListeners();
  }

  /// Parse Bluetooth GATT Heart Rate Measurement (0x2A37)
  /// Coros Broadcast HR sends standard GATT HR format:
  /// Byte 0: Flags (Bit 0 determines UINT8 vs UINT16 BPM)
  void _parseHeartRate(List<int> data) {
    if (data.isEmpty) return;
    final flags = data[0];
    final is16Bit = (flags & 0x01) != 0;

    int hr = 0;
    if (is16Bit && data.length >= 3) {
      hr = data[1] | (data[2] << 8);
    } else if (data.length >= 2) {
      hr = data[1];
    }

    if (hr > 0 && hr < 260) {
      _latestHeartRate = hr;
      notifyListeners();
    }
  }

  /// Parse Cycling Speed & Cadence (0x2A5B)
  void _parseCscData(List<int> data) {
    if (data.length < 5) return;
    final flags = data[0];
    final hasWheelRev = (flags & 0x01) != 0;
    final hasCrankRev = (flags & 0x02) != 0;

    int offset = 1;
    if (hasWheelRev && data.length >= 7) {
      // Wheel revolutions present (4 bytes wheel rev + 2 bytes wheel event time)
      final wheelRev = data[1] | (data[2] << 8) | (data[3] << 16) | (data[4] << 24);
      final wheelTime = data[5] | (data[6] << 8);

      if (_lastWheelRev != null && _lastWheelTime != null) {
        final diffRev = wheelRev - _lastWheelRev!;
        var diffTime = wheelTime - _lastWheelTime!;
        if (diffTime < 0) diffTime += 65536;

        if (diffTime > 0 && diffRev >= 0) {
          final timeSeconds = diffTime / 1024.0;
          if (timeSeconds > 0 && timeSeconds < 3.0) {
            // Standard 700x25c tire circumference = 2.105m
            final speedMs = (diffRev * 2.105) / timeSeconds;
            _latestBleSpeed = speedMs * 3.6;
          }
        }
      }
      _lastWheelRev = wheelRev;
      _lastWheelTime = wheelTime;
      offset += 6;
    }

    if (hasCrankRev && data.length >= (offset + 4)) {
      final crankRev = data[offset] | (data[offset + 1] << 8);
      final crankTime = data[offset + 2] | (data[offset + 3] << 8); // 1/1024 s

      if (_lastCrankRev != null && _lastCrankTime != null) {
        var diffRev = crankRev - _lastCrankRev!;
        var diffTime = crankTime - _lastCrankTime!;

        if (diffRev < 0) diffRev += 65536; // 16-bit rollover
        if (diffTime < 0) diffTime += 65536;

        if (diffTime > 0 && diffRev >= 0) {
          final timeSeconds = diffTime / 1024.0;
          if (timeSeconds > 0 && timeSeconds < 3.0) {
            final rpm = ((diffRev / timeSeconds) * 60).round();
            if (rpm >= 0 && rpm <= 220) {
              _latestCadence = rpm;
            }
          } else {
            _latestCadence = 0;
          }
        }
      }
      _lastCrankRev = crankRev;
      _lastCrankTime = crankTime;
      notifyListeners();
    }
  }

  /// Parse Cycling Power Measurement (0x2A63)
  void _parsePowerData(List<int> data) {
    if (data.length < 4) return;
    // Instantaneous Power is sint16 at byte 2 and 3
    final rawPower = data[2] | (data[3] << 8);
    final watts = rawPower > 32767 ? rawPower - 65536 : rawPower;
    if (watts >= 0 && watts <= 3000) {
      _latestPower = watts;
      notifyListeners();
    }
  }
}

