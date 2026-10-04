import 'dart:convert';

/// Represents a single telemetry reading from an ESP32 device (one animal).
class SensorReading {
  final String deviceId;
  final String animalName;
  final double bodyTemp;
  final double ambientTemp;
  final double humidity;
  final double thi;
  final String thiLevel;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double movementIntensity;
  final double estrusScore;       // 0.0-1.0, high = possible estrus
  final String healthStatus;      // 'healthy', 'fever', 'lethargy', 'sick_suspected'
  final double batteryPercent;    // 0-100%
  final double batteryVoltage;    // 3.0 - 4.2V
  final double? latitude;
  final double? longitude;
  final double speed;
  final int satellites;
  final int? wifiRssi;
  final int? uptimeSeconds;
  final DateTime timestamp;

  SensorReading({
    required this.deviceId,
    this.animalName = '',
    required this.bodyTemp,
    required this.ambientTemp,
    required this.humidity,
    required this.thi,
    required this.thiLevel,
    this.accelX = 0,
    this.accelY = 0,
    this.accelZ = 0,
    this.movementIntensity = 0,
    this.estrusScore = 0,
    this.healthStatus = 'healthy',
    this.batteryPercent = 88.0,
    this.batteryVoltage = 4.05,
    this.latitude,
    this.longitude,
    this.speed = 0.0,
    this.satellites = 0,
    this.wifiRssi,
    this.uptimeSeconds,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convenience getters for UI presentation
  double get temperature => bodyTemp;
  int get batteryLevel => batteryPercent.round();

  /// Calculate THI from ambient temperature and humidity.
  static double calculateThi(double ambientTemp, double humidity) {
    final thi =
        (1.8 * ambientTemp + 32) -
        (0.55 - 0.0055 * humidity) * (1.8 * ambientTemp - 26);
    return double.parse(thi.toStringAsFixed(2));
  }

  /// Determine THI level from value.
  static String thiLevelFromValue(double thi) {
    if (thi >= 89) return 'emergency';
    if (thi >= 79) return 'danger';
    if (thi >= 72) return 'alert';
    return 'normal';
  }

  /// Parse from MQTT JSON payload.
  factory SensorReading.fromMqttJson(String jsonStr) {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final ambientTemp = (data['ambient_temp'] as num).toDouble();
    final humidity = (data['humidity'] as num).toDouble();
    final thi = calculateThi(ambientTemp, humidity);

    return SensorReading(
      deviceId: data['device_id'] as String? ?? 'unknown',
      animalName: data['animal_name'] as String? ?? '',
      bodyTemp: (data['body_temp'] as num).toDouble(),
      ambientTemp: ambientTemp,
      humidity: humidity,
      thi: thi,
      thiLevel: thiLevelFromValue(thi),
      accelX: (data['accel_x'] as num?)?.toDouble() ?? 0,
      accelY: (data['accel_y'] as num?)?.toDouble() ?? 0,
      accelZ: (data['accel_z'] as num?)?.toDouble() ?? 0,
      movementIntensity: (data['movement_intensity'] as num?)?.toDouble() ?? 0,
      estrusScore: (data['estrus_score'] as num?)?.toDouble() ?? 0,
      healthStatus: data['health_status'] as String? ?? 'healthy',
      batteryPercent: (data['battery_pct'] as num?)?.toDouble() ?? 88.0,
      batteryVoltage: (data['battery_v'] as num?)?.toDouble() ?? 4.05,
    );
  }

  /// Parse from REST API JSON.
  factory SensorReading.fromApiJson(Map<String, dynamic> data) {
    return SensorReading(
      deviceId: data['device_id'] as String? ?? 'unknown',
      animalName: data['animal_name'] as String? ?? '',
      bodyTemp: (data['body_temp'] as num?)?.toDouble() ?? 0,
      ambientTemp: (data['ambient_temp'] as num?)?.toDouble() ?? 0,
      humidity: (data['humidity'] as num?)?.toDouble() ?? 0,
      thi: (data['thi'] as num?)?.toDouble() ?? 0,
      thiLevel: data['thi_level'] as String? ?? 'unknown',
      accelX: (data['accel_x'] as num?)?.toDouble() ?? 0,
      accelY: (data['accel_y'] as num?)?.toDouble() ?? 0,
      accelZ: (data['accel_z'] as num?)?.toDouble() ?? 0,
      movementIntensity: (data['movement_intensity'] as num?)?.toDouble() ?? 0,
      estrusScore: (data['estrus_score'] as num?)?.toDouble() ?? 0,
      healthStatus: data['health_status'] as String? ?? 'healthy',
      batteryPercent: (data['battery_pct'] as num?)?.toDouble() ?? 88.0,
      batteryVoltage: (data['battery_v'] as num?)?.toDouble() ?? 4.05,
      timestamp: data['timestamp'] != null
          ? DateTime.tryParse(data['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Parse from Firestore document data.
  factory SensorReading.fromFirestore(Map<String, dynamic> data, [String? docId]) {
    final ambientTemp = (data['ambient_temp'] as num?)?.toDouble() ?? 30.0;
    final humidity = (data['humidity'] as num?)?.toDouble() ?? 40.0;
    final computedThi = (data['thi'] as num?)?.toDouble() ?? calculateThi(ambientTemp, humidity);
    final thiLevel = data['thi_level'] as String? ?? thiLevelFromValue(computedThi);

    return SensorReading(
      deviceId: (data['device_id'] as String?) ?? docId ?? 'unknown',
      animalName: (data['animal_name'] as String?) ?? '',
      bodyTemp: (data['body_temp'] as num?)?.toDouble() ?? 38.5,
      ambientTemp: ambientTemp,
      humidity: humidity,
      thi: computedThi,
      thiLevel: thiLevel,
      accelX: (data['accel_x'] as num?)?.toDouble() ?? 0,
      accelY: (data['accel_y'] as num?)?.toDouble() ?? 0,
      accelZ: (data['accel_z'] as num?)?.toDouble() ?? 9.8,
      movementIntensity: (data['activity_intensity'] as num?)?.toDouble() ??
          (data['movement_intensity'] as num?)?.toDouble() ?? 0,
      estrusScore: (data['estrus_score'] as num?)?.toDouble() ?? 0,
      healthStatus: (data['health_status'] as String?) ?? 'healthy',
      batteryPercent: (data['battery_pct'] as num?)?.toDouble() ?? 88.0,
      batteryVoltage: (data['battery_voltage'] as num?)?.toDouble() ??
          (data['battery_v'] as num?)?.toDouble() ?? 4.05,
      latitude: (data['latitude'] as num?)?.toDouble() ??
          (data['lat'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble() ??
          (data['lng'] as num?)?.toDouble(),
      speed: (data['speed'] as num?)?.toDouble() ?? 0.0,
      satellites: (data['satellites'] as num?)?.toInt() ??
          (data['sats'] as num?)?.toInt() ?? 0,
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] is int
              ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
              : DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  /// Parse from ESP32 Collar JSON structure (stored in Firebase RTDB /telemetria/actual)
  factory SensorReading.fromCollarJson(Map<String, dynamic> data) {
    final devId = data['dispositivo']?.toString() ?? 'Collar-SmartRanch';

    // DHT data
    final dht = data['dht'] is Map ? (data['dht'] as Map) : null;
    final ambTemp = (dht?['temp'] as num?)?.toDouble() ??
        ((data['ir'] is Map ? (data['ir'] as Map)['amb'] : null) as num?)?.toDouble() ??
        28.0;
    final hum = (dht?['hum'] as num?)?.toDouble() ?? 50.0;
    final ith = (dht?['ith'] as num?)?.toDouble() ?? calculateThi(ambTemp, hum);

    // IR data (GY-906 MLX90614)
    final ir = data['ir'] is Map ? (data['ir'] as Map) : null;
    final body = (ir?['obj'] as num?)?.toDouble() ?? 38.5;
    final hasFever = ir?['fiebre'] == true || body >= 39.5;

    // Accel data (HW-860 ADXL345)
    final acc = data['acc'] is Map ? (data['acc'] as Map) : null;
    final ax = (acc?['x'] as num?)?.toDouble() ?? 0.0;
    final ay = (acc?['y'] as num?)?.toDouble() ?? 0.0;
    final az = (acc?['z'] as num?)?.toDouble() ?? 1.0;
    final mag = (acc?['mag'] as num?)?.toDouble() ?? 1.0;
    final accEstado = acc?['estado']?.toString() ?? 'En Reposo / Rumia';

    // GPS data (NEO-6M)
    final gps = data['gps'] is Map ? (data['gps'] as Map) : null;
    final gpsOk = gps?['ok'] == true;
    final lat = (gps?['lat'] as num?)?.toDouble();
    final lng = (gps?['lng'] as num?)?.toDouble();
    final spd = (gps?['speed'] as num?)?.toDouble() ?? 0.0;
    final sats = (gps?['sats'] as num?)?.toInt() ?? 0;

    String health = 'healthy';
    if (hasFever) {
      health = 'fever';
    } else if (accEstado.toLowerCase().contains('baja') ||
        accEstado.toLowerCase().contains('letargia') ||
        accEstado.toLowerCase().contains('inmóvil')) {
      health = 'lethargy';
    }

    return SensorReading(
      deviceId: devId,
      animalName: devId == 'Collar-SmartRanch' ? 'Vaca Collar 01' : devId,
      bodyTemp: body,
      ambientTemp: ambTemp,
      humidity: hum,
      thi: ith,
      thiLevel: thiLevelFromValue(ith),
      accelX: ax,
      accelY: ay,
      accelZ: az,
      movementIntensity: mag,
      estrusScore: mag > 1.8 ? 0.85 : 0.1,
      healthStatus: health,
      batteryPercent: 92.0,
      batteryVoltage: 4.10,
      latitude: (gpsOk && lat != null && lat != 0.0) ? lat : null,
      longitude: (gpsOk && lng != null && lng != 0.0) ? lng : null,
      speed: spd,
      satellites: sats,
      wifiRssi: (data['wifi_rssi'] as num?)?.toInt(),
      uptimeSeconds: (data['uptime_s'] as num?)?.toInt(),
      timestamp: DateTime.now(),
    );
  }

  SensorReading copyWith({
    String? deviceId,
    String? animalName,
    double? bodyTemp,
    double? ambientTemp,
    double? humidity,
    double? thi,
    String? thiLevel,
    double? accelX,
    double? accelY,
    double? accelZ,
    double? movementIntensity,
    double? estrusScore,
    String? healthStatus,
    double? batteryPercent,
    double? batteryVoltage,
    double? latitude,
    double? longitude,
    double? speed,
    int? satellites,
    int? wifiRssi,
    int? uptimeSeconds,
    DateTime? timestamp,
  }) {
    return SensorReading(
      deviceId: deviceId ?? this.deviceId,
      animalName: animalName ?? this.animalName,
      bodyTemp: bodyTemp ?? this.bodyTemp,
      ambientTemp: ambientTemp ?? this.ambientTemp,
      humidity: humidity ?? this.humidity,
      thi: thi ?? this.thi,
      thiLevel: thiLevel ?? this.thiLevel,
      accelX: accelX ?? this.accelX,
      accelY: accelY ?? this.accelY,
      accelZ: accelZ ?? this.accelZ,
      movementIntensity: movementIntensity ?? this.movementIntensity,
      estrusScore: estrusScore ?? this.estrusScore,
      healthStatus: healthStatus ?? this.healthStatus,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      satellites: satellites ?? this.satellites,
      wifiRssi: wifiRssi ?? this.wifiRssi,
      uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

