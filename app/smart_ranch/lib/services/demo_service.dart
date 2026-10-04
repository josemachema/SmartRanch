import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/sensor_reading.dart';
import '../models/reproduction_alert.dart';
import '../models/health_alert.dart';
import '../models/trough_reading.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

/// Demo and Real-time Ranch Sync service that handles simulated ESP32 devices
/// as well as real-time Cloud Firestore live telemetry streams.
class DemoService extends ChangeNotifier {
  final List<_SimulatedAnimal> _animals = [
    _SimulatedAnimal('Collar-SmartRanch', 'Vaca Collar IoT', false),
    _SimulatedAnimal('vaca_001', 'Lupita', false),
    _SimulatedAnimal('vaca_002', 'Estrella', false),
    _SimulatedAnimal('vaca_003', 'Canela', true), // starts stressed
    _SimulatedAnimal('vaca_004', 'Luna', false),
    _SimulatedAnimal('vaca_005', 'Valentina', false),
  ];

  final Map<String, SensorReading> _latestReadings = {};
  final Map<String, List<SensorReading>> _readingHistory = {};
  static const int _maxHistory = 120;

  // --- Estrus Simulation ---
  final Map<String, ReproductionAlert> _activeEstrusAlerts = {};
  final Map<String, int> _estrusTickCounter = {};

  // --- Health Simulation ---
  final Map<String, HealthAlert> _activeHealthAlerts = {};
  final Map<String, String> _healthStates = {}; // device_id -> status

  // --- Trough Simulation ---
  final Map<String, TroughReading> _troughReadings = {};
  static const _troughNames = {
    'bebedero_01': 'Potrero Norte',
    'bebedero_02': 'Corral Principal',
    'bebedero_03': 'Potrero Sur',
  };

  // --- Collar Connection & Disconnection Watchdog ---
  bool _isCollarSimulatedDisconnected = false;
  final Map<String, DateTime> _collarLastSeen = {};
  final Map<String, SensorReading> _lastKnownPositions = {};
  DateTime? _lastCollarHeartbeat;

  Timer? _timer;
  Timer? _rtdbTimer;
  bool _isRunning = false;
  final _random = Random();
  int _tickCount = 0;

  StreamSubscription? _telemetrySub;
  StreamSubscription? _troughsSub;
  StreamSubscription? _alertsSub;

  static final _collarReadingController = StreamController<SensorReading>.broadcast();
  static Stream<SensorReading> get collarReadingStream => _collarReadingController.stream;

  Map<String, SensorReading> get latestReadings =>
      Map.unmodifiable(_latestReadings);
  Map<String, List<SensorReading>> get readingHistory =>
      Map.unmodifiable(_readingHistory);
  bool get isRunning => _isRunning;

  /// Active estrus alerts by device_id.
  Map<String, ReproductionAlert> get activeEstrusAlerts =>
      Map.unmodifiable(_activeEstrusAlerts);

  /// Active health alerts by device_id.
  Map<String, HealthAlert> get activeHealthAlerts =>
      Map.unmodifiable(_activeHealthAlerts);

  /// Current trough readings.
  Map<String, TroughReading> get troughReadings =>
      Map.unmodifiable(_troughReadings);

  /// Collar connection state
  bool get isCollarSimulatedDisconnected => _isCollarSimulatedDisconnected;
  DateTime? get lastCollarHeartbeat => _lastCollarHeartbeat;

  /// Check whether a collar is currently connected and actively transmitting.
  bool isCollarOnline(String deviceId) {
    if (_isCollarSimulatedDisconnected &&
        (deviceId == 'Collar-SmartRanch' || deviceId.toLowerCase().contains('collar'))) {
      return false;
    }
    final lastSeen = _collarLastSeen[deviceId] ?? _latestReadings[deviceId]?.timestamp;
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen).inMinutes < 10;
  }

  /// Time elapsed since last packet received from collar.
  Duration? timeSinceLastCollarPacket(String deviceId) {
    if (_isCollarSimulatedDisconnected &&
        (deviceId == 'Collar-SmartRanch' || deviceId.toLowerCase().contains('collar'))) {
      return const Duration(minutes: 24);
    }
    final lastSeen = _collarLastSeen[deviceId] ?? _latestReadings[deviceId]?.timestamp;
    if (lastSeen == null) return null;
    return DateTime.now().difference(lastSeen);
  }

  /// Retrieve the frozen Last Known Position (LKP) of a collar.
  SensorReading? getLastKnownPosition(String deviceId) {
    return _lastKnownPositions[deviceId] ?? _latestReadings[deviceId];
  }

  /// Toggle simulation of collar disconnection for testing contingencies and protocols.
  void simulateCollarDisconnect(bool disconnected) {
    _isCollarSimulatedDisconnected = disconnected;
    if (disconnected) {
      // Freeze LKP with a timestamp 24 min ago to simulate an out-of-range device
      for (final devId in _latestReadings.keys) {
        if (devId == 'Collar-SmartRanch' || devId.toLowerCase().contains('collar')) {
          final current = _latestReadings[devId]!;
          _lastKnownPositions[devId] = current;
          final fakePastTime = DateTime.now().subtract(const Duration(minutes: 24));
          _collarLastSeen[devId] = fakePastTime;
          _latestReadings[devId] = current.copyWith(timestamp: fakePastTime);
        }
      }
    } else {
      _lastCollarHeartbeat = DateTime.now();
      for (final devId in _latestReadings.keys) {
        if (devId == 'Collar-SmartRanch' || devId.toLowerCase().contains('collar')) {
          _collarLastSeen[devId] = DateTime.now();
          final current = _latestReadings[devId]!;
          _latestReadings[devId] = current.copyWith(timestamp: DateTime.now());
        }
      }
    }
    notifyListeners();
  }

  /// Notify external UI components that ranch metadata or telemetry has changed.
  void notifyStateChanged() {
    notifyListeners();
  }

  /// Start generating simulated data or listening to real Firestore & Realtime DB streams.
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    _initFirestoreListeners();
    _initRealtimeDatabaseListener();

    if (AuthService.isDemoMode) {
      _generateReadings(); // initial
      _generateTroughReadings(); // initial trough
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        _generateReadings();
        // Troughs update less frequently
        if (_tickCount % 12 == 0) _generateTroughReadings();
      });
    }
    notifyListeners();
  }

  void _initRealtimeDatabaseListener() {
    _fetchRtdbTelemetry();
    _rtdbTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _fetchRtdbTelemetry();
    });
  }

  Future<void> _fetchRtdbTelemetry() async {
    try {
      final uri = Uri.parse('${AppConfig.firebaseRtdbUrl}${AppConfig.firebaseTelemetryPath}');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        final data = json.decode(res.body);
        if (data is Map<String, dynamic> && data.containsKey('dispositivo')) {
          final reading = SensorReading.fromCollarJson(data);
          _applyLiveCollarReading(reading);
        }
      }
    } catch (_) {
      // Silent error ignore on temporary network drops
    }
  }

  void _applyLiveCollarReading(SensorReading reading) {
    if (_isCollarSimulatedDisconnected &&
        (reading.deviceId == 'Collar-SmartRanch' || reading.deviceId.toLowerCase().contains('collar'))) {
      // Retain frozen LKP while user tests disconnected state
      return;
    }

    _lastCollarHeartbeat = DateTime.now();
    _collarLastSeen[reading.deviceId] = DateTime.now();

    SensorReading effectiveReading = reading;
    final existing = _latestReadings[reading.deviceId];
    if (existing != null) {
      // If incoming reading temporarily lacks GPS fix (e.g. searching or indoors),
      // preserve the last known GPS position and satellite metrics.
      if (effectiveReading.latitude == null && existing.latitude != null) {
        effectiveReading = effectiveReading.copyWith(
          latitude: existing.latitude,
          longitude: existing.longitude,
          speed: existing.speed,
          satellites: existing.satellites,
        );
      }
    }

    _lastKnownPositions[effectiveReading.deviceId] = effectiveReading;
    _latestReadings[effectiveReading.deviceId] = effectiveReading;

    final history = _readingHistory.putIfAbsent(effectiveReading.deviceId, () => []);
    history.add(effectiveReading);
    if (history.length > _maxHistory) history.removeAt(0);

    // Health alert check
    if (effectiveReading.healthStatus != 'healthy') {
      _activeHealthAlerts[effectiveReading.deviceId] = HealthAlert(
        deviceId: effectiveReading.deviceId,
        animalName: effectiveReading.animalName.isNotEmpty ? effectiveReading.animalName : effectiveReading.deviceId,
        type: effectiveReading.healthStatus,
        bodyTemp: effectiveReading.bodyTemp,
        movementIntensity: effectiveReading.movementIntensity,
        detectedAt: effectiveReading.timestamp,
      );
    } else {
      _activeHealthAlerts.remove(effectiveReading.deviceId);
    }

    _collarReadingController.add(effectiveReading);
    notifyListeners();
  }

  void _initFirestoreListeners() {
    try {
      final firestore = FirebaseFirestore.instance;

      // Telemetry (ESP32 Collars)
      _telemetrySub = firestore.collection('telemetry').snapshots().listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          for (final doc in snapshot.docs) {
            final reading = SensorReading.fromFirestore(doc.data(), doc.id);
            _latestReadings[reading.deviceId] = reading;

            final history = _readingHistory.putIfAbsent(reading.deviceId, () => []);
            history.add(reading);
            if (history.length > _maxHistory) history.removeAt(0);

            // Check health status from live collar
            if (reading.healthStatus != 'healthy') {
              _activeHealthAlerts[reading.deviceId] = HealthAlert(
                deviceId: reading.deviceId,
                animalName: reading.animalName.isNotEmpty ? reading.animalName : reading.deviceId,
                type: reading.healthStatus,
                bodyTemp: reading.bodyTemp,
                movementIntensity: reading.movementIntensity,
                detectedAt: reading.timestamp,
              );
            } else {
              _activeHealthAlerts.remove(reading.deviceId);
            }
          }
          notifyListeners();
        }
      }, onError: (e) => debugPrint('Firestore telemetry error: $e'));

      // Troughs (Water levels)
      _troughsSub = firestore.collection('troughs').snapshots().listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          for (final doc in snapshot.docs) {
            final trough = TroughReading.fromFirestore(doc.data(), doc.id);
            _troughReadings[trough.troughId] = trough;
          }
          notifyListeners();
        }
      }, onError: (e) => debugPrint('Firestore troughs error: $e'));

    } catch (e) {
      debugPrint('Firestore initialization listener error: $e');
    }
  }

  void stop() {
    _timer?.cancel();
    _rtdbTimer?.cancel();
    _telemetrySub?.cancel();
    _troughsSub?.cancel();
    _alertsSub?.cancel();
    _isRunning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  void _generateReadings() {
    _tickCount++;

    for (final animal in _animals) {
      // Toggle stress randomly
      if (_random.nextDouble() < 0.03) {
        animal.stressed = !animal.stressed;
      }

      // --- Estrus Simulation ---
      // Every ~24 ticks (~2 min), one random cow enters estrus for 12 ticks (~1 min)
      if (_tickCount % 24 == 0 && _random.nextDouble() < 0.4) {
        final candidate =
            _animals[_random.nextInt(_animals.length)];
        if (!candidate.inEstrus) {
          candidate.inEstrus = true;
          _estrusTickCounter[candidate.id] = 0;
        }
      }

      // Track estrus duration
      if (animal.inEstrus) {
        _estrusTickCounter[animal.id] =
            (_estrusTickCounter[animal.id] ?? 0) + 1;
        if ((_estrusTickCounter[animal.id] ?? 0) > 12) {
          animal.inEstrus = false;
          _estrusTickCounter.remove(animal.id);
          _activeEstrusAlerts.remove(animal.id);
        }
      }

      // --- Health Simulation ---
      // Every ~36 ticks (~3 min), one random cow gets sick for 10 ticks
      if (_tickCount % 36 == 0 && _random.nextDouble() < 0.3) {
        final candidate =
            _animals[_random.nextInt(_animals.length)];
        if (_healthStates[candidate.id] == null ||
            _healthStates[candidate.id] == 'healthy') {
          final types = ['fever', 'lethargy', 'sick_suspected'];
          candidate.healthState = types[_random.nextInt(types.length)];
          candidate.healthTicks = 0;
          _healthStates[candidate.id] = candidate.healthState;
        }
      }

      // Track health duration
      if (animal.healthState != 'healthy') {
        animal.healthTicks++;
        if (animal.healthTicks > 10) {
          animal.healthState = 'healthy';
          animal.healthTicks = 0;
          _healthStates[animal.id] = 'healthy';
          _activeHealthAlerts.remove(animal.id);
        }
      }

      // Generate sensor values
      final isEstrus = animal.inEstrus;
      final isSick =
          animal.healthState == 'fever' ||
          animal.healthState == 'sick_suspected';
      final isLethargic =
          animal.healthState == 'lethargy' ||
          animal.healthState == 'sick_suspected';

      final bodyTemp = isSick
          ? 40.5 + _random.nextDouble() * 1.5
          : animal.stressed
              ? 39.5 + _random.nextDouble() * 2.0
              : 37.5 + _random.nextDouble() * 2.0;
      final ambientTemp = animal.stressed
          ? 38.0 + _random.nextDouble() * 10.0
          : 25.0 + _random.nextDouble() * 10.0;
      final humidity = animal.stressed
          ? 40.0 + _random.nextDouble() * 35.0
          : 15.0 + _random.nextDouble() * 30.0;

      final thi = SensorReading.calculateThi(ambientTemp, humidity);

      // Movement: high for estrus, low for lethargy, normal otherwise
      final movementIntensity = isEstrus
          ? 3.0 + _random.nextDouble() * 3.0 // High activity = celo
          : isLethargic
              ? 0.05 + _random.nextDouble() * 0.15 // Very low = sick
              : animal.stressed
                  ? 1.5 + _random.nextDouble() * 3.0
                  : 0.1 + _random.nextDouble() * 1.0;

      // Estrus score
      final estrusScore = isEstrus
          ? 0.8 + _random.nextDouble() * 0.2
          : _random.nextDouble() * 0.2;

      // Health status
      final healthStatus = animal.healthState;

      final batteryMap = {
        'Collar-SmartRanch': (92.0, 4.10),
        'vaca_001': (94.0, 4.15),
        'vaca_002': (88.0, 4.05),
        'vaca_003': (76.0, 3.92),
        'vaca_004': (91.0, 4.12),
        'vaca_005': (62.0, 3.78),
      };
      final batData = batteryMap[animal.id] ?? (85.0, 4.0);

      final gpsOffsets = {
        'Collar-SmartRanch': (31.3012, -113.5320),
        'vaca_001': (31.3035, -113.5290),
        'vaca_002': (31.2990, -113.5345),
        'vaca_003': (31.3050, -113.5360),
        'vaca_004': (31.2980, -113.5280),
        'vaca_005': (31.3025, -113.5380),
      };
      final baseGps = gpsOffsets[animal.id] ?? (31.3012, -113.5320);
      final lat = baseGps.$1 + (_random.nextDouble() - 0.5) * 0.0008;
      final lng = baseGps.$2 + (_random.nextDouble() - 0.5) * 0.0008;

      final reading = SensorReading(
        deviceId: animal.id,
        animalName: animal.name,
        bodyTemp: double.parse(bodyTemp.toStringAsFixed(1)),
        ambientTemp: double.parse(ambientTemp.toStringAsFixed(1)),
        humidity: double.parse(humidity.toStringAsFixed(1)),
        thi: thi,
        thiLevel: SensorReading.thiLevelFromValue(thi),
        accelX: (_random.nextDouble() - 0.5) *
            (isEstrus ? 6 : animal.stressed ? 4 : 2),
        accelY: (_random.nextDouble() - 0.5) *
            (isEstrus ? 4 : animal.stressed ? 2 : 1),
        accelZ:
            9.8 +
            (_random.nextDouble() - 0.5) *
                (isEstrus ? 4 : animal.stressed ? 3 : 0.5),
        movementIntensity:
            double.parse(movementIntensity.toStringAsFixed(2)),
        estrusScore: double.parse(estrusScore.toStringAsFixed(2)),
        healthStatus: healthStatus,
        batteryPercent: batData.$1,
        batteryVoltage: batData.$2,
        latitude: lat,
        longitude: lng,
        satellites: 8,
      );

      _latestReadings[animal.id] = reading;
      _collarLastSeen[animal.id] = reading.timestamp;
      _lastKnownPositions[animal.id] = reading;
      _readingHistory.putIfAbsent(animal.id, () => []);
      _readingHistory[animal.id]!.add(reading);
      if (_readingHistory[animal.id]!.length > _maxHistory) {
        _readingHistory[animal.id]!.removeAt(0);
      }

      // Update active alert maps
      if (isEstrus && estrusScore > 0.7) {
        _activeEstrusAlerts[animal.id] = ReproductionAlert(
          deviceId: animal.id,
          animalName: animal.name,
          activityScore: estrusScore,
          movementIntensity: movementIntensity,
        );
      }
      if (healthStatus != 'healthy') {
        _activeHealthAlerts[animal.id] = HealthAlert(
          deviceId: animal.id,
          animalName: animal.name,
          type: healthStatus,
          bodyTemp: bodyTemp,
          movementIntensity: movementIntensity,
        );
      }
    }
    notifyListeners();
  }

  void _generateTroughReadings() {
    for (final entry in _troughNames.entries) {
      final id = entry.key;
      final name = entry.value;

      // Simulate water levels that slowly decrease then get refilled
      final existing = _troughReadings[id];
      double level;
      if (existing == null) {
        level = 60 + _random.nextDouble() * 40; // Start 60-100%
      } else {
        // Decrease by 1-3%, occasionally refill
        level = existing.levelPercent - (1 + _random.nextDouble() * 2);
        if (level <= 5 || _random.nextDouble() < 0.08) {
          level = 70 + _random.nextDouble() * 30; // Refill to 70-100%
        }
      }
      level = level.clamp(0.0, 100.0);

      final distanceCm = 100 - level; // Simplified: level% maps to distance

      _troughReadings[id] = TroughReading(
        troughId: id,
        troughName: name,
        levelPercent: double.parse(level.toStringAsFixed(1)),
        distanceCm: double.parse(distanceCm.toStringAsFixed(1)),
        tankDepthCm: 100,
      );
    }
  }

  /// Manually add or update a trough reading
  void addOrUpdateTrough(TroughReading trough) {
    _troughReadings[trough.troughId] = trough;
    notifyListeners();
  }

  /// Trigger a refill event for a specific trough (e.g. activating pump or float valve)
  void refillTrough(String troughId) {
    final existing = _troughReadings[troughId];
    if (existing != null) {
      _troughReadings[troughId] = existing.copyWith(
        levelPercent: 96.0,
        distanceCm: 4.0,
        timestamp: DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// Calibrate sensor offset for a specific trough
  void calibrateTrough(String troughId, double offsetCm) {
    final existing = _troughReadings[troughId];
    if (existing != null) {
      final newDist = (existing.distanceCm + offsetCm).clamp(2.0, existing.tankDepthCm);
      final newPct = ((existing.tankDepthCm - newDist) / existing.tankDepthCm * 100.0).clamp(0.0, 100.0);
      _troughReadings[troughId] = existing.copyWith(
        distanceCm: double.parse(newDist.toStringAsFixed(1)),
        levelPercent: double.parse(newPct.toStringAsFixed(1)),
        timestamp: DateTime.now(),
      );
      notifyListeners();
    }
  }
}

class _SimulatedAnimal {
  final String id;
  final String name;
  bool stressed;
  bool inEstrus;
  String healthState;
  int healthTicks;

  _SimulatedAnimal(this.id, this.name, this.stressed)
      : inEstrus = false,
        healthState = 'healthy',
        healthTicks = 0;
}
