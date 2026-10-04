/// Represents a water level reading from a trough sensor.
class TroughReading {
  final String troughId;
  final String troughName;
  final double levelPercent;
  final double distanceCm;
  final double tankDepthCm;
  final DateTime timestamp;
  final double? capacityLiters;
  final double? waterTemperature;
  final int? batteryPercent;
  final String? sensorType;
  final String? tankType;

  TroughReading({
    required this.troughId,
    this.troughName = '',
    required this.levelPercent,
    this.distanceCm = 0,
    this.tankDepthCm = 100,
    DateTime? timestamp,
    this.capacityLiters,
    this.waterTemperature,
    this.batteryPercent,
    this.sensorType,
    this.tankType,
  }) : timestamp = timestamp ?? DateTime.now();

  factory TroughReading.fromJson(Map<String, dynamic> data) {
    return TroughReading(
      troughId: data['trough_id'] as String? ?? 'unknown',
      troughName: data['trough_name'] as String? ?? '',
      levelPercent: (data['level_percent'] as num?)?.toDouble() ?? 0,
      distanceCm: (data['distance_cm'] as num?)?.toDouble() ?? 0,
      tankDepthCm: (data['tank_depth_cm'] as num?)?.toDouble() ?? 100,
      capacityLiters: (data['capacity_liters'] as num?)?.toDouble(),
      waterTemperature: (data['water_temp'] as num?)?.toDouble(),
      batteryPercent: (data['battery_pct'] as num?)?.toInt(),
      sensorType: data['sensor_type'] as String?,
      tankType: data['tank_type'] as String?,
      timestamp: data['timestamp'] != null
          ? DateTime.tryParse(data['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  factory TroughReading.fromFirestore(Map<String, dynamic> data, [String? docId]) {
    return TroughReading(
      troughId: (data['id'] as String?) ?? (data['trough_id'] as String?) ?? docId ?? 'bebedero',
      troughName: (data['name'] as String?) ?? (data['trough_name'] as String?) ?? 'Bebedero',
      levelPercent: (data['level_percent'] as num?)?.toDouble() ?? 0.0,
      distanceCm: (data['distance_cm'] as num?)?.toDouble() ?? 0.0,
      tankDepthCm: (data['tank_depth_cm'] as num?)?.toDouble() ?? 100.0,
      capacityLiters: (data['capacity_liters'] as num?)?.toDouble(),
      waterTemperature: (data['water_temp'] as num?)?.toDouble(),
      batteryPercent: (data['battery_pct'] as num?)?.toInt(),
      sensorType: data['sensor_type'] as String?,
      tankType: data['tank_type'] as String?,
      timestamp: data['updated_at'] != null
          ? (data['updated_at'] is int
              ? DateTime.fromMillisecondsSinceEpoch(data['updated_at'] as int)
              : DateTime.tryParse(data['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  /// Effective tank capacity in liters
  double get effectiveCapacityLiters {
    if (capacityLiters != null && capacityLiters! > 0) return capacityLiters!;
    if (troughId.contains('01')) return 8000.0;
    if (troughId.contains('02')) return 5000.0;
    if (troughId.contains('03')) return 6500.0;
    return 5000.0;
  }

  /// Current estimated stored volume in liters
  double get currentVolumeLiters =>
      (effectiveCapacityLiters * (levelPercent / 100.0)).clamp(0.0, effectiveCapacityLiters);

  /// Water temperature in Celsius
  double get effectiveWaterTemp {
    if (waterTemperature != null) return waterTemperature!;
    if (troughId.contains('01')) return 21.4;
    if (troughId.contains('02')) return 22.2;
    return 20.8;
  }

  /// Ultrasonic sensor battery
  int get effectiveBatteryPercent {
    if (batteryPercent != null) return batteryPercent!;
    if (troughId.contains('01')) return 94;
    if (troughId.contains('02')) return 88;
    return 91;
  }

  /// Ultrasonic sensor model
  String get effectiveSensorType => sensorType ?? 'JSN-SR04T (IP67)';

  /// Structure type
  String get effectiveTankType {
    if (tankType != null && tankType!.isNotEmpty) return tankType!;
    if (troughId.contains('01')) return 'Tanque Nodriza UV';
    if (troughId.contains('02')) return 'Pileta Concreto Corral';
    return 'Tanque Australiano';
  }

  /// Human-readable status.
  String get statusLabel {
    if (levelPercent <= 10) return 'Crítico';
    if (levelPercent <= 20) return 'Bajo';
    if (levelPercent <= 50) return 'Medio';
    return 'Óptimo';
  }

  bool get isLow => levelPercent <= 20;

  TroughReading copyWith({
    String? troughId,
    String? troughName,
    double? levelPercent,
    double? distanceCm,
    double? tankDepthCm,
    DateTime? timestamp,
    double? capacityLiters,
    double? waterTemperature,
    int? batteryPercent,
    String? sensorType,
    String? tankType,
  }) {
    return TroughReading(
      troughId: troughId ?? this.troughId,
      troughName: troughName ?? this.troughName,
      levelPercent: levelPercent ?? this.levelPercent,
      distanceCm: distanceCm ?? this.distanceCm,
      tankDepthCm: tankDepthCm ?? this.tankDepthCm,
      timestamp: timestamp ?? this.timestamp,
      capacityLiters: capacityLiters ?? this.capacityLiters,
      waterTemperature: waterTemperature ?? this.waterTemperature,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      sensorType: sensorType ?? this.sensorType,
      tankType: tankType ?? this.tankType,
    );
  }
}
