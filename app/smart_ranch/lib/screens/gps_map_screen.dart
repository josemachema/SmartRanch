import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../services/mqtt_realtime_service.dart';
import '../services/demo_service.dart';

/// GPS Map screen — real OpenStreetMap view of Puerto Peñasco, Sonora
/// Displays exclusively animals registered in the database (Firebase RTDB / Firestore)
/// with persistent Last Known Location (Última Conexión) tracking and geofencing.
class GpsMapScreen extends StatefulWidget {
  final DemoService? demoService;
  final bool enableMqtt;

  const GpsMapScreen({
    super.key,
    this.demoService,
    this.enableMqtt = true,
  });

  @override
  State<GpsMapScreen> createState() => _GpsMapScreenState();
}

class _GpsMapScreenState extends State<GpsMapScreen> {
  final MapController _mapController = MapController();
  final List<Map<String, dynamic>> _positions = [];
  List<Map<String, dynamic>> _violations = [];

  StreamSubscription<Map<String, dynamic>>? _mqttSubscription;
  StreamSubscription? _firestoreGpsSubscription;
  StreamSubscription? _firestoreAnimalsSubscription;
  StreamSubscription? _collarGpsSubscription;
  Timer? _uiRefreshTimer;
  Timer? _fallbackTimer;

  bool _mqttConnected = false;
  String? _selectedDeviceId;
  bool _hasCenteredOnCow = false;
  bool _isLoading = true;
  final Map<String, String> _animalNamesByDevice = {};

  final LatLng _phoneLocation = const LatLng(31.3175, -113.5372);

  // Fallback demo positions — used strictly in demo mode if no database records exist
  static const _demoPositions = [
    {
      'device_id': 'vaca_001',
      'animal_name': 'Lupita',
      'latitude': 31.3200,
      'longitude': -113.5360,
      'current_zone': 'Potrero Peñasco Norte',
      'speed': 0.2,
      'battery_v': 3.9,
      'battery_pct': 70,
      'satellites': 6,
      'is_real_db': false,
    },
    {
      'device_id': 'vaca_002',
      'animal_name': 'Estrella',
      'latitude': 31.3190,
      'longitude': -113.5390,
      'current_zone': 'Potrero Peñasco Norte',
      'speed': 0.0,
      'battery_v': 4.1,
      'battery_pct': 90,
      'satellites': 8,
      'is_real_db': false,
    },
  ];

  List<Polygon> get _geofencePolygons {
    final list = <Polygon>[];
    final perimeter = AuthService.effectiveGeofence;
    if (perimeter.length >= 3) {
      list.add(
        Polygon(
          points: perimeter,
          color: const Color(0xFF619F49).withAlpha(35),
          borderColor: const Color(0xFF619F49),
          borderStrokeWidth: 2.5,
          label: 'Perímetro ${AuthService.ranchName}',
          labelStyle: const TextStyle(
            color: Color(0xFF619F49),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Sub-potreros
    list.add(
      Polygon(
        points: const [
          LatLng(31.3130, -113.5360),
          LatLng(31.3155, -113.5360),
          LatLng(31.3155, -113.5320),
          LatLng(31.3130, -113.5320),
        ],
        color: const Color(0xFFFF9800).withAlpha(30),
        borderColor: const Color(0xFFFF9800),
        borderStrokeWidth: 2,
        label: 'Corral Central',
        labelStyle: const TextStyle(
          color: Color(0xFFFF9800),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    list.add(
      Polygon(
        points: const [
          LatLng(31.3155, -113.5380),
          LatLng(31.3170, -113.5380),
          LatLng(31.3170, -113.5360),
          LatLng(31.3155, -113.5360),
        ],
        color: const Color(0xFF3AAFA9).withAlpha(35),
        borderColor: const Color(0xFF3AAFA9),
        borderStrokeWidth: 2,
        label: 'Bebedero Principal',
        labelStyle: const TextStyle(
          color: Color(0xFF3AAFA9),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return list;
  }

  @override
  void initState() {
    super.initState();
    _initDataSources();
    if (widget.enableMqtt) {
      _connectMqtt();
    }

    // Timer to update relative timestamps ("Hace 1 min" -> "Hace 2 min")
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _mqttSubscription?.cancel();
    _firestoreGpsSubscription?.cancel();
    _firestoreAnimalsSubscription?.cancel();
    _collarGpsSubscription?.cancel();
    _uiRefreshTimer?.cancel();
    _fallbackTimer?.cancel();
    MqttRealtimeService.disconnect();
    super.dispose();
  }

  void _initDataSources() {
    // 1. Check existing readings from DemoService (synchronous initial check)
    if (widget.demoService != null) {
      for (final entry in widget.demoService!.latestReadings.entries) {
        final reading = entry.value;
        if (reading.latitude != null &&
            reading.longitude != null &&
            reading.latitude != 0.0 &&
            reading.longitude != 0.0) {
          _updateOrAddPosition(
            deviceId: reading.deviceId,
            latitude: reading.latitude!,
            longitude: reading.longitude!,
            animalName: reading.animalName,
            speed: reading.speed,
            batteryV: reading.batteryVoltage,
            batteryPct: reading.batteryPercent.toInt(),
            satellites: reading.satellites,
            wifiRssi: reading.wifiRssi,
            timestamp: reading.timestamp,
            isFromDb: true,
          );
        }
      }
    }

    // 2. Listen to DemoService stream (fires whenever ESP32 RTDB gets updated)
    _collarGpsSubscription = DemoService.collarReadingStream.listen((reading) {
      if (!mounted) return;
      if (reading.latitude != null &&
          reading.longitude != null &&
          reading.latitude != 0.0 &&
          reading.longitude != 0.0) {
        setState(() {
          _updateOrAddPosition(
            deviceId: reading.deviceId,
            latitude: reading.latitude!,
            longitude: reading.longitude!,
            animalName: reading.animalName,
            speed: reading.speed,
            batteryV: reading.batteryVoltage,
            batteryPct: reading.batteryPercent.toInt(),
            satellites: reading.satellites,
            wifiRssi: reading.wifiRssi,
            timestamp: reading.timestamp,
            isFromDb: true,
          );
          _isLoading = false;
        });
      }
    });

    // 4. Listen to Cloud Firestore telemetry collection
    _initFirestoreTelemetry();

    // 5. Query Firestore animals collection for official names
    _initFirestoreAnimals();

    // 6. If no database animals exist after 2 seconds, evaluate demo mode fallback
    _fallbackTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_positions.isEmpty && AuthService.isDemoMode) {
        setState(() {
          for (final demo in _demoPositions) {
            _updateOrAddPosition(
              deviceId: demo['device_id'] as String,
              latitude: demo['latitude'] as double,
              longitude: demo['longitude'] as double,
              animalName: demo['animal_name'] as String,
              speed: demo['speed'] as double,
              batteryV: demo['battery_v'] as double,
              batteryPct: demo['battery_pct'] as int,
              satellites: demo['satellites'] as int,
              timestamp: DateTime.now(),
              isFromDb: false,
            );
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    });
  }

  void _initFirestoreTelemetry() {
    try {
      _firestoreGpsSubscription = FirebaseFirestore.instance
          .collection('telemetry')
          .snapshots()
          .listen((snapshot) {
        if (!mounted || snapshot.docs.isEmpty) return;
        setState(() {
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final lat = (data['latitude'] as num?)?.toDouble() ??
                (data['lat'] as num?)?.toDouble();
            final lng = (data['longitude'] as num?)?.toDouble() ??
                (data['lng'] as num?)?.toDouble();
            if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
              final deviceId = (data['device_id'] as String?) ?? doc.id;
              final name = data['animal_name'] as String?;
              final speed = (data['speed'] as num?)?.toDouble() ?? 0.0;
              final batV = (data['battery_voltage'] as num?)?.toDouble() ??
                  (data['battery_v'] as num?)?.toDouble() ??
                  4.05;
              final batPct = (data['battery_pct'] as num?)?.toInt() ?? 90;
              final sats = (data['satellites'] as num?)?.toInt() ?? 0;

              DateTime? ts;
              if (data['timestamp'] != null) {
                if (data['timestamp'] is Timestamp) {
                  ts = (data['timestamp'] as Timestamp).toDate();
                } else if (data['timestamp'] is int) {
                  ts = DateTime.fromMillisecondsSinceEpoch(
                      data['timestamp'] as int);
                } else {
                  ts = DateTime.tryParse(data['timestamp'].toString());
                }
              }

              _updateOrAddPosition(
                deviceId: deviceId,
                latitude: lat,
                longitude: lng,
                animalName: name,
                speed: speed,
                batteryV: batV,
                batteryPct: batPct,
                satellites: sats,
                timestamp: ts,
                isFromDb: true,
              );
              _isLoading = false;
            }
          }
        });
      }, onError: (e) => debugPrint('Firestore GPS error: $e'));
    } catch (e) {
      debugPrint('Firestore GPS listener init error: $e');
    }
  }

  void _initFirestoreAnimals() {
    try {
      _firestoreAnimalsSubscription = FirebaseFirestore.instance
          .collection('animals')
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final devId = data['device_id'] as String?;
          final name = data['name'] as String?;
          if (devId != null && devId.isNotEmpty && name != null && name.isNotEmpty) {
            _animalNamesByDevice[devId] = name;
          }
        }
        if (mounted && _positions.isNotEmpty) {
          setState(() {
            for (final pos in _positions) {
              final devId = pos['device_id'] as String;
              if (_animalNamesByDevice.containsKey(devId)) {
                pos['animal_name'] = _animalNamesByDevice[devId];
              }
            }
          });
        }
      }, onError: (e) => debugPrint('Firestore animals stream error: $e'));
    } catch (e) {
      debugPrint('Firestore animals init error: $e');
    }
  }

  void _connectMqtt() async {
    final ok = await MqttRealtimeService.connect();
    if (ok) {
      if (mounted) setState(() => _mqttConnected = true);
      _mqttSubscription = MqttRealtimeService.gpsStream.listen((data) {
        final deviceId = data['device_id'];
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (mounted && lat != null && lng != null && lat != 0.0 && lng != 0.0) {
          setState(() {
            _updateOrAddPosition(
              deviceId: deviceId,
              latitude: lat,
              longitude: lng,
              animalName: data['animal_name'],
              speed: (data['speed'] as num?)?.toDouble() ?? 0.0,
              batteryV: (data['battery_v'] as num?)?.toDouble() ?? 4.0,
              timestamp: DateTime.now(),
              isFromDb: true,
            );
          });
        }
      });
    }
  }

  bool _isInsidePolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return true;
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].latitude, yi = polygon[i].longitude;
      final xj = polygon[j].latitude, yj = polygon[j].longitude;
      final intersect = ((yi > point.longitude) != (yj > point.longitude)) &&
          (point.latitude < (xj - xi) * (point.longitude - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  String? _determineZone(LatLng point) {
    // 1. Must be inside main ranch perimeter
    final perimeter = AuthService.effectiveGeofence;
    if (!_isInsidePolygon(point, perimeter)) {
      return null; // Out of bounds
    }

    // 2. Check sub-potreros
    const corralCentral = [
      LatLng(31.3130, -113.5360),
      LatLng(31.3155, -113.5360),
      LatLng(31.3155, -113.5320),
      LatLng(31.3130, -113.5320),
    ];
    if (_isInsidePolygon(point, corralCentral)) {
      return 'Corral Central';
    }

    const bebedero = [
      LatLng(31.3155, -113.5380),
      LatLng(31.3170, -113.5380),
      LatLng(31.3170, -113.5360),
      LatLng(31.3155, -113.5360),
    ];
    if (_isInsidePolygon(point, bebedero)) {
      return 'Bebedero Principal';
    }

    return 'Potrero Peñasco Norte';
  }

  void _updateOrAddPosition({
    required String deviceId,
    required double latitude,
    required double longitude,
    String? animalName,
    double speed = 0.0,
    double batteryV = 4.10,
    int? batteryPct,
    int satellites = 0,
    DateTime? timestamp,
    double? altitude,
    int? wifiRssi,
    bool isFromDb = true,
  }) {
    if (latitude == 0.0 && longitude == 0.0) return;

    // Purge mock entries whenever a real DB entry arrives
    if (isFromDb) {
      _positions.removeWhere((p) => p['is_real_db'] != true);
    }

    final point = LatLng(latitude, longitude);
    final zone = _determineZone(point);
    final isViolation = zone == null;
    final now = DateTime.now();
    final effectiveTime = timestamp ?? now;
    final isSimDisconnected = widget.demoService?.isCollarSimulatedDisconnected == true &&
        (deviceId == 'Collar-SmartRanch' || deviceId.toLowerCase().contains('collar'));
    final isOnline = !isSimDisconnected && now.difference(effectiveTime).inMinutes < 10;

    final resolvedName = animalName?.isNotEmpty == true
        ? animalName!
        : (_animalNamesByDevice[deviceId] ??
            (deviceId == 'Collar-SmartRanch' ? 'Vaca Collar 01' : deviceId));

    final effectiveBatPct = batteryPct ??
        (((batteryV - 3.2) / (4.2 - 3.2)) * 100).clamp(0, 100).toInt();

    final entry = {
      'device_id': deviceId,
      'animal_name': resolvedName,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'battery_v': batteryV,
      'battery_pct': effectiveBatPct,
      'satellites': satellites,
      'current_zone': zone,
      'is_violation': isViolation,
      'timestamp': effectiveTime,
      'is_online': isOnline,
      'is_real_db': isFromDb,
      'altitude': altitude,
      'wifi_rssi': wifiRssi,
    };

    final idx = _positions.indexWhere((p) => p['device_id'] == deviceId);
    if (idx >= 0) {
      _positions[idx] = entry;
    } else {
      _positions.add(entry);
    }

    _violations = _positions.where((p) => p['is_violation'] == true).toList();

    // Auto-focus smoothly on the real cow on initial discovery
    if (!_hasCenteredOnCow && _positions.isNotEmpty) {
      _hasCenteredOnCow = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(LatLng(latitude, longitude), 15.0);
        }
      });
    }
  }

  void _focusCow(Map<String, dynamic> pos) {
    final lat = (pos['latitude'] as num?)?.toDouble();
    final lng = (pos['longitude'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      setState(() => _selectedDeviceId = pos['device_id']);
      _mapController.move(LatLng(lat, lng), 15.5);
      _showCowModal(pos);
    }
  }

  String _formatRelativeTime(DateTime? timestamp) {
    if (timestamp == null) return 'Desconocida';
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inSeconds < 45) {
      return 'Hace unos segundos';
    } else if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return 'Hace $m min';
    } else if (diff.inHours < 24) {
      final h = diff.inHours;
      return 'Hace $h h';
    } else {
      final d = diff.inDays;
      return 'Hace $d d';
    }
  }

  String _formatExactTime(DateTime? timestamp) {
    if (timestamp == null) return '--:--';
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m hrs';
  }

  Map<String, dynamic>? get _firstDisconnectedPosition {
    for (final p in _positions) {
      final isSimDisconnected = widget.demoService?.isCollarSimulatedDisconnected == true &&
          (p['device_id'] == 'Collar-SmartRanch' || p['device_id'].toString().toLowerCase().contains('collar'));
      final ts = p['timestamp'] as DateTime?;
      final isOnline = !isSimDisconnected && ts != null && DateTime.now().difference(ts).inMinutes < 10;
      if (!isOnline) return p;
    }
    return null;
  }

  List<CircleMarker> get _dispersalCircles {
    final circles = <CircleMarker>[];
    for (final pos in _positions) {
      final isSimDisconnected = widget.demoService?.isCollarSimulatedDisconnected == true &&
          (pos['device_id'] == 'Collar-SmartRanch' || pos['device_id'].toString().toLowerCase().contains('collar'));
      final ts = pos['timestamp'] as DateTime?;
      final isOnline = !isSimDisconnected && ts != null && DateTime.now().difference(ts).inMinutes < 10;
      if (!isOnline) {
        final lat = (pos['latitude'] as num?)?.toDouble() ?? 0.0;
        final lng = (pos['longitude'] as num?)?.toDouble() ?? 0.0;
        if (lat != 0.0 && lng != 0.0) {
          final diffMin = ts != null ? DateTime.now().difference(ts).inMinutes : 24;
          final radiusMeters = (diffMin * 25.0).clamp(120.0, 800.0);
          circles.add(
            CircleMarker(
              point: LatLng(lat, lng),
              radius: radiusMeters,
              useRadiusInMeter: true,
              color: const Color(0xFFE65100).withAlpha(35),
              borderColor: const Color(0xFFE65100),
              borderStrokeWidth: 1.8,
            ),
          );
        }
      }
    }
    return circles;
  }

  void _showMapContingencyProtocol(Map<String, dynamic> pos) {
    final devId = pos['device_id'] ?? 'Collar-SmartRanch';
    final name = pos['animal_name'] ?? 'Bovino';
    final ts = pos['timestamp'] as DateTime?;
    final lat = (pos['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (pos['longitude'] as num?)?.toDouble() ?? 0.0;
    final dist = const Distance().as(LengthUnit.Meter, _phoneLocation, LatLng(lat, lng)).round();
    final zone = pos['current_zone'] ?? 'Rancho Peñasco';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.divider),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 540),
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100).withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.emergency_outlined, color: Color(0xFFE65100), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Protocolo de Búsqueda y Rescate IoT',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Ejemplar: $name • Dispositivo: $devId',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100).withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE65100).withAlpha(60)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_searching_rounded, color: Color(0xFFE65100), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Última Posición Conocida (LKP) anclada en $zone',
                              style: const TextStyle(
                                color: Color(0xFFE65100),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Desconectado ${_formatRelativeTime(ts)} (${_formatExactTime(ts)}) • Coords: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)} • Distancia a tu celular: ~$dist m.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildMapStep(
                  step: '1',
                  title: 'Navegación al Cuadrante LKP',
                  desc: 'El círculo naranja en el mapa indica el radio de dispersión calculado ($dist m). Desplácese en cuatrimoto o caballo hacia el punto central.',
                  icon: Icons.explore_rounded,
                ),
                const SizedBox(height: 8),
                _buildMapStep(
                  step: '2',
                  title: 'Inspección de Estado Zoosanitario',
                  desc: 'Ubique al ejemplar visualmente por su arete SINIIGA o fierro. Verifique que no esté encallado en arroyos o bebederos.',
                  icon: Icons.pets_rounded,
                ),
                const SizedBox(height: 8),
                _buildMapStep(
                  step: '3',
                  title: 'Revisión Física de Hardware ESP32',
                  desc: 'Compruebe el LED de estado. Si está apagado, cambie la batería 18650 o limpie el panel solar. Si parpadea, está vivo pero en zona de sombra RF.',
                  icon: Icons.battery_charging_full_rounded,
                ),
                const SizedBox(height: 8),
                _buildMapStep(
                  step: '4',
                  title: 'Arreo hacia Cobertura de Gateway',
                  desc: 'Mueva al lote fuera de cañadas o hacia lomas despejadas para restablecer de inmediato el enlace de telemetría en tiempo real.',
                  icon: Icons.cell_tower_rounded,
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cerrar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _mapController.move(LatLng(lat, lng), 16.5);
                      },
                      icon: const Icon(Icons.center_focus_strong_rounded, size: 16),
                      label: const Text('Centrar en LKP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapStep({
    required String step,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: const Color(0xFFE65100).withAlpha(25),
            child: Text(step, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 13, color: const Color(0xFFE65100)),
                    const SizedBox(width: 5),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10.5, height: 1.25)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCowModal(Map<String, dynamic> pos) {
    final isViolation = pos['is_violation'] == true || pos['current_zone'] == null;
    final speed = (pos['speed'] as num?)?.toDouble() ?? 0.0;
    final batV = (pos['battery_v'] as num?)?.toDouble() ?? 4.10;
    final batPct = (pos['battery_pct'] as int?) ?? 92;
    final sats = (pos['satellites'] as int?) ?? 0;
    final ts = pos['timestamp'] as DateTime?;
    final isSimDisconnected = widget.demoService?.isCollarSimulatedDisconnected == true &&
        (pos['device_id'] == 'Collar-SmartRanch' || pos['device_id'].toString().toLowerCase().contains('collar'));
    final isOnline = !isSimDisconnected && ts != null && DateTime.now().difference(ts).inMinutes < 10;
    final isRealDb = pos['is_real_db'] == true;
    final lat = (pos['latitude'] as num).toDouble();
    final lng = (pos['longitude'] as num).toDouble();
    final distMeters = const Distance().as(LengthUnit.Meter, _phoneLocation, LatLng(lat, lng)).round();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Cow header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: !isOnline
                          ? const Color(0xFFE65100).withAlpha(25)
                          : isViolation
                              ? AppTheme.thiDanger.withAlpha(25)
                              : AppTheme.primary.withAlpha(25),
                      child: Icon(
                        !isOnline
                            ? Icons.sensors_off_rounded
                            : Icons.pets_rounded,
                        color: !isOnline
                            ? const Color(0xFFE65100)
                            : isViolation
                                ? AppTheme.thiDanger
                                : AppTheme.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  pos['animal_name'] ?? 'Vaca Collar 01',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isRealDb) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withAlpha(25),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppTheme.primary.withAlpha(80),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Text(
                                    'BASE DE DATOS',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID Dispositivo: ${pos['device_id']}',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Geofence / Connection status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: !isOnline
                            ? const Color(0xFFE65100).withAlpha(25)
                            : isViolation
                                ? AppTheme.thiDanger.withAlpha(25)
                                : AppTheme.thiNormal.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: !isOnline
                              ? const Color(0xFFE65100)
                              : isViolation
                                  ? AppTheme.thiDanger
                                  : AppTheme.thiNormal,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            !isOnline
                                ? Icons.sensors_off_rounded
                                : isViolation
                                    ? Icons.warning_amber_rounded
                                    : Icons.check_circle_outline_rounded,
                            size: 13,
                            color: !isOnline
                                ? const Color(0xFFE65100)
                                : isViolation
                                    ? AppTheme.thiDanger
                                    : AppTheme.thiNormal,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            !isOnline
                                ? 'DESCONECTADO (LKP)'
                                : isViolation
                                    ? 'FUERA DE CERCO'
                                    : (pos['current_zone'] ?? 'En zona'),
                            style: TextStyle(
                              color: !isOnline
                                  ? const Color(0xFFE65100)
                                  : isViolation
                                      ? AppTheme.thiDanger
                                      : AppTheme.thiNormal,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Persistence Banner: Última Conexión registrada vs LKP
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: !isOnline
                        ? const Color(0xFFE65100).withAlpha(15)
                        : AppTheme.thiNormal.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: !isOnline
                          ? const Color(0xFFE65100).withAlpha(60)
                          : AppTheme.thiNormal.withAlpha(60),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        !isOnline
                            ? Icons.sensors_off_rounded
                            : Icons.sensors_rounded,
                        color: !isOnline
                            ? const Color(0xFFE65100)
                            : AppTheme.thiNormal,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              !isOnline
                                  ? 'Última Posición Conocida (LKP) — Desconectado'
                                  : 'Collar en Línea — Transmisión Activa',
                              style: TextStyle(
                                color: !isOnline
                                    ? const Color(0xFFE65100)
                                    : AppTheme.thiNormal,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              !isOnline
                                  ? 'Última señal: ${_formatExactTime(ts)} (${_formatRelativeTime(ts)}). Coordenadas ancladas para búsqueda de campo.'
                                  : 'Sincronizado vía Firebase RTDB (${_formatRelativeTime(ts)})',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Contingency Diagnostic Box if disconnected
                if (!isOnline) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.troubleshoot_rounded, size: 15, color: Color(0xFFE65100)),
                            const SizedBox(width: 6),
                            const Text(
                              'Diagnóstico de Campo',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              'A ~$distMeters m de tu celular',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          batPct < 25
                              ? '⚡ Causa probable: Agotamiento de celda LiFePO4 ($batPct%). Lleve batería de repuesto.'
                              : sats == 0
                                  ? '📡 Causa probable: Obstrucción de vista satelital (ejemplar en tejaban o cañada honda).'
                                  : '⛰️ Causa probable: Zona de sombra LoRa / Accidente orográfico en Puerto Peñasco.',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Metrics Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ModalMetric(
                      icon: Icons.speed_rounded,
                      label: 'Velocidad',
                      value: '${speed.toStringAsFixed(1)} km/h',
                      color: speed > 2.0 ? AppTheme.secondary : null,
                    ),
                    _ModalMetric(
                      icon: batPct < 20
                          ? Icons.battery_alert_rounded
                          : Icons.battery_charging_full_rounded,
                      label: 'Batería Li-Ion',
                      value: '$batPct% (${batV.toStringAsFixed(2)}V)',
                      color:
                          batPct < 25 ? AppTheme.thiDanger : AppTheme.primary,
                    ),
                    _ModalMetric(
                      icon: Icons.satellite_alt_rounded,
                      label: 'Satélites GPS',
                      value: sats > 0 ? '$sats sats (Fijo)' : 'NEO-6M Fix',
                      color: sats >= 4 ? AppTheme.thiNormal : AppTheme.thiAlert,
                    ),
                    _ModalMetric(
                      icon: Icons.my_location_rounded,
                      label: 'Coordenadas',
                      value:
                          '${(pos['latitude'] as num).toStringAsFixed(4)}, ${(pos['longitude'] as num).toStringAsFixed(4)}',
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Action buttons: Center on Map & Contingency Protocol
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _mapController.move(LatLng(lat, lng), 16.5);
                        },
                        icon: const Icon(Icons.center_focus_strong_rounded, size: 16),
                        label: const Text('Centrar Cámara', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    if (!isOnline) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showMapContingencyProtocol(pos);
                          },
                          icon: const Icon(Icons.checklist_rounded, size: 16),
                          label: const Text('Protocolo Búsqueda', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE65100),
                            side: const BorderSide(color: Color(0xFFE65100)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStatsBar(),
        Expanded(child: _buildMapArea()),
        _buildPositionList(),
      ],
    );
  }

  Widget _buildStatsBar() {
    final totalTracked = _positions.length;
    final inZone = _positions.where((p) => p['current_zone'] != null).length;
    final outOfZone = _violations.length;
    final hasRealDb = _positions.any((p) => p['is_real_db'] == true);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.gps_fixed_rounded,
            label: hasRealDb ? 'En Base Datos' : 'Rastreadas',
            value: '$totalTracked',
            color: AppTheme.primary,
          ),
          _StatItem(
            icon: Icons.check_circle_rounded,
            label: 'En Cerco',
            value: '$inZone',
            color: AppTheme.thiNormal,
          ),
          _StatItem(
            icon: Icons.warning_amber_rounded,
            label: 'Fuera',
            value: '$outOfZone',
            color: outOfZone > 0 ? AppTheme.thiDanger : AppTheme.textSecondary,
          ),
          _StatItem(
            icon: Icons.cloud_done_rounded,
            label: 'Fuente GPS',
            value: hasRealDb ? 'RTDB LIVE' : 'SYNC',
            color: hasRealDb ? AppTheme.thiNormal : AppTheme.textSecondary,
          ),
          _StatItem(
            icon: _mqttConnected
                ? Icons.wifi_rounded
                : Icons.satellite_alt_rounded,
            label: 'Recepción',
            value: hasRealDb ? 'ACTIVA' : 'ESPERA',
            color: hasRealDb ? AppTheme.thiNormal : AppTheme.thiAlert,
          ),
        ],
      ),
    );
  }

  Widget _buildMapArea() {
    final violationIds = _violations.map((v) => v['device_id']).toSet();

    final markers = _positions.map((pos) {
      final lat = (pos['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (pos['longitude'] as num?)?.toDouble() ?? 0.0;
      final isViolation =
          violationIds.contains(pos['device_id']) || pos['current_zone'] == null;
      final isSelected = pos['device_id'] == _selectedDeviceId;
      final isSimDisconnected = widget.demoService?.isCollarSimulatedDisconnected == true &&
          (pos['device_id'] == 'Collar-SmartRanch' || pos['device_id'].toString().toLowerCase().contains('collar'));
      final isOnline = !isSimDisconnected && pos['is_online'] == true;
      final color = !isOnline
          ? const Color(0xFFE65100)
          : isViolation
              ? AppTheme.thiDanger
              : AppTheme.primary;

      return Marker(
        point: LatLng(lat, lng),
        width: 88,
        height: 62,
        child: GestureDetector(
          onTap: () => _focusCow(pos),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.black45,
                    width: isSelected ? 1.8 : 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.greenAccent : const Color(0xFFFF9800),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        isOnline
                            ? (pos['animal_name'] ?? pos['device_id'] ?? 'Vaca')
                            : '${pos['animal_name'] ?? pos['device_id']} (LKP)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              Icon(
                !isOnline
                    ? Icons.sensors_off_rounded
                    : Icons.location_on_rounded,
                color: color,
                size: isSelected ? 32 : 24,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // OpenStreetMap
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _positions.isNotEmpty
                    ? LatLng(
                        (_positions.first['latitude'] as num).toDouble(),
                        (_positions.first['longitude'] as num).toDouble(),
                      )
                    : AuthService.ranchLocation,
                initialZoom: 14.5,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.smartranch.app',
                ),
                PolygonLayer(polygons: _geofencePolygons),
                CircleLayer(circles: _dispersalCircles),
                MarkerLayer(
                  markers: [
                    ...markers,
                    // User's Live Smartphone GPS Marker
                    Marker(
                      point: _phoneLocation,
                      width: 50,
                      height: 50,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Mi Celular',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.my_location_rounded,
                            color: Color(0xFF2196F3),
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Top-left label: Ranch & State
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withAlpha(235),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map_rounded,
                        size: 15, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${AuthService.ranchName} — Puerto Peñasco, Sonora',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Disconnection Contingency Floating Banner
            if (_firstDisconnectedPosition != null) ...[
              Positioned(
                top: 48,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withAlpha(245),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE65100), width: 1.2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65100).withAlpha(35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.sensors_off_rounded, color: Color(0xFFE65100), size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '⚠️ CONTINGENCIA IOT: ${_firstDisconnectedPosition!['animal_name']} DESCONECTADO',
                              style: const TextStyle(
                                color: Color(0xFFE65100),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              'Mostrando LKP (${_formatRelativeTime(_firstDisconnectedPosition!['timestamp'] as DateTime?)}) • Círculo naranja indica radio de dispersión',
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _focusCow(_firstDisconnectedPosition!),
                        icon: const Icon(Icons.radar_rounded, size: 12),
                        label: const Text('Rastrear LKP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE65100),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Top-right Legend
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withAlpha(235),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LegendItem(color: AppTheme.primary, label: 'En cerco'),
                    SizedBox(height: 3),
                    _LegendItem(
                        color: AppTheme.thiDanger, label: 'Fuera de cerco'),
                    SizedBox(height: 3),
                    _LegendItem(
                        color: Color(0xFFE65100), label: 'Desconectado (LKP)'),
                    SizedBox(height: 3),
                    _LegendItem(
                        color: Color(0xFF3AAFA9), label: 'Bebedero'),
                    SizedBox(height: 3),
                    _LegendItem(
                        color: Color(0xFF2196F3), label: 'Mi Celular (GPS)'),
                  ],
                ),
              ),
            ),

            // Bottom-right Map Controls
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quick Center on Cow
                  if (_positions.isNotEmpty) ...[
                    FloatingActionButton.small(
                      heroTag: 'map_cow_gps',
                      onPressed: () {
                        final pos = _positions.first;
                        _focusCow(pos);
                      },
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      tooltip: 'Centrar en Animal Registrado',
                      child: const Icon(Icons.pets_rounded, size: 18),
                    ),
                    const SizedBox(height: 6),
                  ],
                  // User Phone GPS
                  FloatingActionButton.small(
                    heroTag: 'map_user_gps',
                    onPressed: () {
                      _mapController.move(_phoneLocation, 16.0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              '📍 Centrado en la ubicación GPS de tu celular'),
                          backgroundColor: Color(0xFF2196F3),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    tooltip: 'Mi ubicación GPS',
                    child:
                        const Icon(Icons.person_pin_circle_rounded, size: 20),
                  ),
                  const SizedBox(height: 6),
                  // Recenter Ranch
                  FloatingActionButton.small(
                    heroTag: 'map_recenter_penasco',
                    onPressed: () {
                      setState(() => _selectedDeviceId = null);
                      _mapController.move(AuthService.ranchLocation, 14.5);
                    },
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.textPrimary,
                    tooltip: 'Centrar en Rancho Peñasco',
                    child: const Icon(Icons.home_work_rounded, size: 18),
                  ),
                  const SizedBox(height: 6),
                  // Zoom In
                  FloatingActionButton.small(
                    heroTag: 'map_zoom_in',
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(
                          _mapController.camera.center, currentZoom + 1);
                    },
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.textPrimary,
                    child: const Icon(Icons.add, size: 18),
                  ),
                  const SizedBox(height: 6),
                  // Zoom Out
                  FloatingActionButton.small(
                    heroTag: 'map_zoom_out',
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(
                          _mapController.camera.center, currentZoom - 1);
                    },
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.textPrimary,
                    child: const Icon(Icons.remove, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionList() {
    if (_positions.isEmpty) {
      return Container(
        height: 100,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                  : const Icon(
                      Icons.radar_rounded,
                      color: AppTheme.primary,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLoading
                        ? 'Sincronizando con base de datos...'
                        : 'Esperando primer reporte GPS',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Verifica que el ESP32 Collar-SmartRanch esté encendido con antena NEO-6M hacia cielo abierto.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 124,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _positions.length,
        itemBuilder: (context, index) {
          final pos = _positions[index];
          final isViolation =
              pos['is_violation'] == true || pos['current_zone'] == null;
          final isSelected = pos['device_id'] == _selectedDeviceId;
          final ts = pos['timestamp'] as DateTime?;
          final isSimDisconnected = widget.demoService?.isCollarSimulatedDisconnected == true &&
              (pos['device_id'] == 'Collar-SmartRanch' || pos['device_id'].toString().toLowerCase().contains('collar'));
          final isOnline = !isSimDisconnected && ts != null && DateTime.now().difference(ts).inMinutes < 10;
          final speed = (pos['speed'] as num?)?.toDouble() ?? 0.0;
          final batPct = (pos['battery_pct'] as int?) ?? 92;

          return InkWell(
            onTap: () => _focusCow(pos),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 210,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withAlpha(20)
                    : AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primary
                      : (!isOnline
                          ? const Color(0xFFE65100).withAlpha(80)
                          : isViolation
                              ? AppTheme.thiDanger.withAlpha(80)
                              : AppTheme.divider),
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top: Name + Online dot
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: !isOnline
                              ? const Color(0xFFE65100).withAlpha(20)
                              : isViolation
                                  ? AppTheme.thiDanger.withAlpha(20)
                                  : AppTheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          !isOnline
                              ? Icons.sensors_off_rounded
                              : Icons.pets_rounded,
                          size: 14,
                          color: !isOnline
                              ? const Color(0xFFE65100)
                              : isViolation
                                  ? AppTheme.thiDanger
                                  : AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pos['animal_name'] ?? pos['device_id'],
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              pos['device_id'] ?? '',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Connection status pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOnline
                              ? AppTheme.thiNormal.withAlpha(20)
                              : const Color(0xFFE65100).withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isOnline
                                ? AppTheme.thiNormal.withAlpha(60)
                                : const Color(0xFFE65100).withAlpha(60),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? AppTheme.thiNormal
                                    : const Color(0xFFE65100),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isOnline ? 'LIVE' : 'LKP',
                              style: TextStyle(
                                color: isOnline
                                    ? AppTheme.thiNormal
                                    : const Color(0xFFE65100),
                                fontWeight: FontWeight.bold,
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Zone / Geofence state
                  Row(
                    children: [
                      Icon(
                        !isOnline
                            ? Icons.sensors_off_rounded
                            : isViolation
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_rounded,
                        size: 12,
                        color: !isOnline
                            ? const Color(0xFFE65100)
                            : isViolation
                                ? AppTheme.thiDanger
                                : AppTheme.thiNormal,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          !isOnline
                              ? '🔴 LKP: ${pos['current_zone'] ?? 'Rancho'}'
                              : isViolation
                                  ? '⚠️ Fuera de cerco'
                                  : (pos['current_zone'] ?? 'En zona'),
                          style: TextStyle(
                            color: !isOnline
                                ? const Color(0xFFE65100)
                                : isViolation
                                    ? AppTheme.thiDanger
                                    : AppTheme.textPrimary,
                            fontSize: 11,
                            fontWeight: (!isOnline || isViolation)
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Bottom metrics: speed, battery, last seen
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${speed.toStringAsFixed(1)} km/h • $batPct%',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        _formatRelativeTime(ts),
                        style: TextStyle(
                          color: isOnline
                              ? AppTheme.thiNormal
                              : AppTheme.textSecondary,
                          fontSize: 9,
                          fontWeight: isOnline
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 9),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 9),
        ),
      ],
    );
  }
}

class _ModalMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _ModalMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? AppTheme.textSecondary),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: color ?? AppTheme.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}