import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_theme.dart';
import '../services/demo_service.dart';
import '../services/ranch_api_service.dart';
import '../widgets/crud_dialogs.dart';

/// Animal profile model for herd management.
class AnimalProfile {
  final int id;
  final String siniigaTag;
  final String deviceId;
  final String name;
  final String breed;
  final String sex;
  final String category;
  final String? birthDate;
  final double? weightKg;
  final String pasture;
  final String status;
  final String notes;
  final int batteryLevel;

  AnimalProfile({
    required this.id,
    required this.siniigaTag,
    this.deviceId = '',
    required this.name,
    this.breed = '',
    this.sex = 'hembra',
    this.category = 'vaca',
    this.birthDate,
    this.weightKg,
    this.pasture = '',
    this.status = 'active',
    this.notes = 'En pastoreo regular. Sin anomalías.',
    this.batteryLevel = 92,
  });
}

/// Herd management screen — dual-view (Cards & Table) with IoT collar auto-discovery.
class HerdScreen extends StatefulWidget {
  final DemoService? demoService;
  final void Function(int index)? onNavigate;
  const HerdScreen({super.key, this.demoService, this.onNavigate});

  @override
  State<HerdScreen> createState() => _HerdScreenState();
}

class _HerdScreenState extends State<HerdScreen> {
  List<AnimalProfile> _animals = [];
  StreamSubscription? _animalsSub;

  String _searchQuery = '';
  String? _filterBreed;
  int? _hoveredIndex;
  bool _isTableView = false;
  bool _isLinking = false;

  @override
  void initState() {
    super.initState();
    _loadAnimals();
    _initFirestoreAnimals();
    widget.demoService?.addListener(_onIoT);
  }

  void _onIoT() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.demoService?.removeListener(_onIoT);
    _animalsSub?.cancel();
    super.dispose();
  }

  void _initFirestoreAnimals() {
    try {
      _animalsSub = FirebaseFirestore.instance.collection('animals').snapshots().listen((snapshot) {
        if (!mounted) return;
        _loadAnimals();
      }, onError: (e) => debugPrint('Firestore animals stream error: $e'));
    } catch (e) {
      debugPrint('Firestore animals init error: $e');
    }
  }

  Future<void> _loadAnimals() async {
    if (!mounted) return;
    try {
      final animals = await RanchApiService.getAnimals();
      final records = await RanchApiService.getWeightRecords();
      final latestWeight = <int, double>{};
      for (final r in records) {
        if (!latestWeight.containsKey(r.animalId)) {
          latestWeight[r.animalId] = r.weightKg;
        }
      }
      if (!mounted) return;
      setState(() {
        _animals = animals.map((a) => AnimalProfile(
          id: a.id,
          siniigaTag: (a.earTag != null && a.earTag!.isNotEmpty) ? a.earTag! : 'S/N',
          deviceId: a.deviceId ?? '',
          name: a.name,
          breed: a.breed ?? 'Brangus',
          sex: a.sex,
          category: a.category,
          birthDate: a.birthDate?.toIso8601String().split('T').first,
          weightKg: latestWeight[a.id] ?? a.weightKg,
          pasture: 'Potrero Principal',
          status: a.status,
          notes: a.notes ?? '',
          batteryLevel: 92,
        )).toList();
      });
    } catch (e) {
      if (!mounted) return;
    }
  }

  List<AnimalProfile> get _filteredAnimals {
    var list = _animals.where((a) => a.status == 'active').toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) =>
          a.name.toLowerCase().contains(q) ||
          a.siniigaTag.toLowerCase().contains(q) ||
          a.breed.toLowerCase().contains(q) ||
          a.pasture.toLowerCase().contains(q) ||
          a.deviceId.toLowerCase().contains(q) ||
          '#${a.id}'.contains(q)
      ).toList();
    }
    if (_filterBreed != null && _filterBreed!.isNotEmpty && _filterBreed != 'Todas las razas') {
      list = list.where((a) => a.breed.toLowerCase() == _filterBreed!.toLowerCase()).toList();
    }
    return list;
  }

  List<String> get _breeds =>
      _animals.map((a) => a.breed).where((b) => b.isNotEmpty).toSet().toList()
        ..sort();

  String? get _unlinkedCollarId {
    final readings = widget.demoService?.latestReadings ?? {};
    for (final devId in readings.keys) {
      final exists = _animals.any((a) => a.deviceId.toLowerCase() == devId.toLowerCase());
      if (!exists) return devId;
    }
    if (!_animals.any((a) => a.deviceId.toLowerCase() == 'collar-smartranch')) {
      return 'Collar-SmartRanch';
    }
    return null;
  }

  Future<void> _quickLinkCollar(String deviceId) async {
    setState(() => _isLinking = true);
    final nextNum = _animals.length + 1;
    final animalData = {
      'name': 'Vaca Collar ${nextNum.toString().padLeft(2, '0')}',
      'ear_tag': 'MX-PP-${nextNum.toString().padLeft(4, '0')}',
      'device_id': deviceId,
      'breed': 'Brangus',
      'sex': 'female',
      'category': 'cow',
      'status': 'active',
      'weight_kg': 460.0,
      'notes': 'Bovino vinculado a collar IoT en tiempo real (Puerto Peñasco, Sonora).',
    };

    try {
      await RanchApiService.createAnimal(animalData);
    } catch (_) {
      // offline fallback handled by RanchApiService
    }

    await _loadAnimals();
    setState(() => _isLinking = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Dispositivo $deviceId vinculado exitosamente como ${animalData['name']} (Arete: ${animalData['ear_tag']})'),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  Future<void> _loadSampleHerd() async {
    setState(() => _isLinking = true);
    RanchApiService.initDemoData();
    await _loadAnimals();
    setState(() => _isLinking = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Hato de demostración cargado con 5 ejemplares registrados'),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  void _showAnimalDetails(AnimalProfile animal) {
    final isCollar = animal.deviceId.isNotEmpty;
    final isDis = isCollar && ((widget.demoService?.isCollarSimulatedDisconnected == true && animal.deviceId.toLowerCase().contains('collar')) || (widget.demoService != null && !widget.demoService!.isCollarOnline(animal.deviceId)));
    final elapsed = widget.demoService?.timeSinceLastCollarPacket(animal.deviceId) ?? const Duration(minutes: 24);
    final lkpReading = widget.demoService?.getLastKnownPosition(animal.deviceId);
    final lat = lkpReading?.latitude;
    final lng = lkpReading?.longitude;
    final coordsText = (lat != null && lng != null)
        ? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'
        : '31.3012, -113.5320';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDis ? const Color(0xFFD32F2F).withAlpha(120) : AppTheme.divider),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Avatar + Name + ID + Close
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDis ? const Color(0xFFD32F2F).withAlpha(20) : AppTheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDis ? const Color(0xFFD32F2F).withAlpha(80) : AppTheme.primary.withAlpha(60)),
                      ),
                      child: Icon(Icons.pets_rounded, color: isDis ? const Color(0xFFD32F2F) : AppTheme.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                animal.name,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDis ? const Color(0xFFD32F2F).withAlpha(20) : AppTheme.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '#${animal.id}',
                                  style: TextStyle(
                                    color: isDis ? const Color(0xFFD32F2F) : AppTheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'SINIIGA: ${animal.siniigaTag}',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(color: AppTheme.divider, height: 1),
                const SizedBox(height: 16),

                // IoT Collar Section
                Row(
                  children: [
                    Text(
                      'COLLAR INTELIGENTE (IoT)',
                      style: TextStyle(
                        color: isDis ? const Color(0xFFD32F2F) : AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isDis) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD32F2F),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'CONTINGENCIA LKP',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDis ? const Color(0xFFD32F2F).withAlpha(12) : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDis ? const Color(0xFFD32F2F).withAlpha(100) : AppTheme.divider,
                      width: isDis ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDis ? Icons.sensors_off_rounded : Icons.sensors_rounded,
                        color: isDis ? const Color(0xFFD32F2F) : AppTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              animal.deviceId.isNotEmpty ? animal.deviceId : 'Sin sensor vinculado',
                              style: TextStyle(
                                color: isDis ? const Color(0xFFD32F2F) : AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isDis
                                  ? 'Sin señal hace ${elapsed.inMinutes} min • LKP congelada'
                                  : 'Sensor NFC & GPS activo • En línea',
                              style: TextStyle(
                                color: isDis ? const Color(0xFFD32F2F).withAlpha(220) : AppTheme.textSecondary,
                                fontSize: 10.5,
                                fontWeight: isDis ? FontWeight.w600 : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDis ? const Color(0xFFD32F2F).withAlpha(20) : AppTheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                          border: isDis ? Border.all(color: const Color(0xFFD32F2F).withAlpha(80)) : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDis ? Icons.battery_alert_rounded : Icons.battery_charging_full_rounded,
                              size: 14,
                              color: isDis ? const Color(0xFFD32F2F) : AppTheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${animal.batteryLevel}%',
                              style: TextStyle(
                                color: isDis ? const Color(0xFFD32F2F) : AppTheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDis) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F).withAlpha(10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD32F2F).withAlpha(50)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFFD32F2F)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Última Posición Conocida: $coordsText. Radio de búsqueda activo en el mapa satelital.',
                            style: TextStyle(fontSize: 10.5, color: AppTheme.textPrimary.withAlpha(210), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Details Grid
                Text(
                  'DATOS GENERALES',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _InfoTile(label: 'Raza', value: animal.breed, icon: Icons.category_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _InfoTile(label: 'Sexo', value: animal.sex == 'hembra' ? 'Hembra' : 'Macho', icon: animal.sex == 'hembra' ? Icons.female_rounded : Icons.male_rounded)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _InfoTile(label: 'Categoría', value: animal.category.toUpperCase(), icon: Icons.pets_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _InfoTile(label: 'Peso Actual', value: animal.weightKg != null ? '${animal.weightKg!.toStringAsFixed(0)} kg' : '--', icon: Icons.monitor_weight_rounded)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _InfoTile(label: 'Ubicación / Potrero', value: animal.pasture, icon: Icons.location_on_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _InfoTile(label: 'Nacimiento', value: animal.birthDate ?? 'N/D', icon: Icons.event_rounded)),
                  ],
                ),
                const SizedBox(height: 12),

                // Notes
                Text('Notas:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(animal.notes, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.5)),

                const SizedBox(height: 20),

                if (animal.deviceId.isNotEmpty && widget.onNavigate != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onNavigate!(9); // GpsMapScreen index
                      },
                      icon: Icon(isDis ? Icons.radar_rounded : Icons.map_rounded, size: 16),
                      label: Text(isDis ? 'Rastrear LKP en Mapa GPS (Radio Activo)' : 'Rastrear en Mapa GPS Satelital'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDis ? const Color(0xFFD32F2F) : AppTheme.primary,
                        side: BorderSide(color: isDis ? const Color(0xFFD32F2F).withAlpha(140) : AppTheme.primary.withAlpha(120)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Quick Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final saved = await showAddWeightDialog(context, animalId: animal.id);
                          if (saved == true) {
                            _loadAnimals();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Peso registrado y actualizado en el inventario'),
                                  backgroundColor: AppTheme.primary,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.monitor_weight_outlined, size: 16),
                        label: const Text('Pesar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final saved = await showAddMedicalDialog(context, animalId: animal.id);
                          if (saved == true) {
                            _loadAnimals();
                          }
                        },
                        icon: const Icon(Icons.medical_services_outlined, size: 16),
                        label: const Text('Salud'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAnimals;
    final activeCount = _animals.where((a) => a.status == 'active').length;

    return Column(
      children: [
        // Stats + Search Bar
        Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            children: [
              // Stats Row — evenly centered across full width
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: _QuickStat(
                        icon: Icons.pets_rounded,
                        value: '$activeCount',
                        label: 'Total',
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  Container(height: 32, width: 1, color: AppTheme.divider),
                  Expanded(
                    child: Center(
                      child: _QuickStat(
                        icon: Icons.female_rounded,
                        value: '${_animals.where((a) => a.sex == "hembra" && a.status == "active").length}',
                        label: 'Hembras',
                        color: const Color(0xFFE91E63),
                      ),
                    ),
                  ),
                  Container(height: 32, width: 1, color: AppTheme.divider),
                  Expanded(
                    child: Center(
                      child: _QuickStat(
                        icon: Icons.male_rounded,
                        value: '${_animals.where((a) => a.sex == "macho" && a.status == "active").length}',
                        label: 'Machos',
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                  ),
                  Container(height: 32, width: 1, color: AppTheme.divider),
                  Expanded(
                    child: Center(
                      child: _QuickStat(
                        icon: Icons.category_rounded,
                        value: '${_breeds.length}',
                        label: 'Razas',
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: AppTheme.divider),
              const SizedBox(height: 12),

              // Search & Filter Row — centered
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Buscar nombre, arete, ID, sensor...',
                            hintStyle: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            prefixIcon: Icon(Icons.search_rounded,
                                color: AppTheme.textSecondary, size: 18),
                            filled: true,
                            fillColor: AppTheme.card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTheme.divider),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTheme.divider),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTheme.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Breed filter
                  PopupMenuButton<String?>(
                    icon: Icon(Icons.filter_list_rounded,
                        color: _filterBreed != null
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                        size: 22),
                    tooltip: 'Filtrar por raza',
                    onSelected: (value) {
                      setState(() {
                        _filterBreed = (value == null || value == 'Todas las razas' || value.isEmpty)
                            ? null
                            : value;
                      });
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem<String?>(value: null, child: Text('Todas las razas')),
                      ..._breeds.map(
                        (b) => PopupMenuItem<String?>(value: b, child: Text(b)),
                      ),
                    ],
                  ),

                  // Filter chip when active
                  if (_filterBreed != null) ...[
                    const SizedBox(width: 6),
                    InputChip(
                      label: Text(_filterBreed!, style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: AppTheme.primary.withAlpha(20),
                      deleteIconColor: AppTheme.primary,
                      onDeleted: () => setState(() => _filterBreed = null),
                    ),
                  ],

                  // View mode toggle (Cards vs Table)
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.grid_view_rounded, size: 18, color: !_isTableView ? AppTheme.primary : AppTheme.textSecondary),
                          tooltip: 'Vista en Tarjetas',
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _isTableView = false),
                        ),
                        Container(width: 1, height: 20, color: AppTheme.divider),
                        IconButton(
                          icon: Icon(Icons.table_rows_rounded, size: 18, color: _isTableView ? AppTheme.primary : AppTheme.textSecondary),
                          tooltip: 'Vista en Tabla',
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _isTableView = true),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Add animal button
                  ElevatedButton.icon(
                    onPressed: () async {
                      final saved = await showAddAnimalDialog(context);
                      if (saved == true) {
                        _loadAnimals();
                      }
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Registrar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Auto-discovery banner when an active collar exists and isn't linked yet
        if (_unlinkedCollarId != null && _animals.isNotEmpty)
          _buildIoTDiscoveryBanner(_unlinkedCollarId!),

        // Main Content: Empty State, Cards View or Data Table
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.divider),
              ),
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : _isTableView
                      ? _buildTableView(filtered)
                      : _buildCardsView(filtered),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIoTDiscoveryBanner(String deviceId) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sensors_rounded, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Dispositivo IoT Detectado: $deviceId',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'EN VIVO RTDB',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Transmisión continua de GPS y signos vitales activa. Vincúlalo a tu inventario con 1 clic.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isLinking ? null : () => _quickLinkCollar(deviceId),
            icon: _isLinking
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.link_rounded, size: 16),
            label: Text(_isLinking ? 'Vinculando...' : 'Vincular Bovino', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final unlinked = _unlinkedCollarId;

    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textSecondary.withAlpha(120)),
              const SizedBox(height: 12),
              Text(
                'No se encontraron animales con "$_searchQuery"',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'Verifica el nombre, raza, ID o arete SINIIGA ingresado.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.pets_rounded, size: 48, color: AppTheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Inventario de Ganado Disponible',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 6),
              Text(
                'Tu rancho no cuenta con ejemplares activos registrados en este momento.\nPuedes vincular el collar IoT detectado en vivo o cargar un hato de demostración.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 550;
                  return Flex(
                    direction: isWide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card 1: Live Collar
                      Expanded(
                        flex: isWide ? 1 : 0,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primary.withAlpha(70)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.sensors_rounded, color: AppTheme.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Collar IoT en Vivo',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 14),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(4)),
                                    child: const Text('EN VIVO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                unlinked != null
                                    ? 'Se detectó señal activa de $unlinked con telemetría continua cada 2s en Puerto Peñasco.'
                                    : 'Vincula un dispositivo ESP32 para transmisión GPS y signos vitales.',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, height: 1.3),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isLinking
                                      ? null
                                      : () => _quickLinkCollar(unlinked ?? 'Collar-SmartRanch'),
                                  icon: const Icon(Icons.link_rounded, size: 16),
                                  label: Text(_isLinking ? 'Vinculando...' : 'Vincular a Vaca 01'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 16),

                      // Card 2: Demo Herd
                      Expanded(
                        flex: isWide ? 1 : 0,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded, color: AppTheme.secondary, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Hato Demostración',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Carga 5 ejemplares de razas diversas (Brangus, Angus, Hereford) con pesos y aretes para evaluar el rancho.',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, height: 1.3),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isLinking ? null : _loadSampleHerd,
                                  icon: const Icon(Icons.download_rounded, size: 16),
                                  label: const Text('Cargar 5 Ejemplares Demo'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.textPrimary,
                                    side: BorderSide(color: AppTheme.divider),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () async {
                  final saved = await showAddAnimalDialog(context);
                  if (saved == true) _loadAnimals();
                },
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                label: const Text('O dar de alta un animal manualmente con formulario SINIIGA'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardsView(List<AnimalProfile> animals) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 3
            : constraints.maxWidth > 700
                ? 2
                : 1;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 220,
          ),
          itemCount: animals.length,
          itemBuilder: (context, index) => _buildAnimalCard(animals[index]),
        );
      },
    );
  }

  Widget _buildAnimalCard(AnimalProfile animal) {
    final readings = widget.demoService?.latestReadings ?? {};
    final reading = animal.deviceId.isNotEmpty ? readings[animal.deviceId] : null;
    final isCollar = animal.deviceId.isNotEmpty;
    final isDis = isCollar && ((widget.demoService?.isCollarSimulatedDisconnected == true && animal.deviceId.toLowerCase().contains('collar')) || (widget.demoService != null && !widget.demoService!.isCollarOnline(animal.deviceId)));
    final disMinutes = widget.demoService?.timeSinceLastCollarPacket(animal.deviceId)?.inMinutes ?? 24;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDis ? const Color(0xFFD32F2F).withAlpha(120) : AppTheme.divider,
          width: isDis ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDis ? const Color(0xFFD32F2F).withAlpha(16) : Colors.black.withAlpha(12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Tag badge + Status pill
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBC02D).withAlpha(35),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFBC02D).withAlpha(100)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag_rounded, size: 11, color: Color(0xFFE65100)),
                    const SizedBox(width: 3),
                    Text(
                      animal.siniigaTag,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE65100),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (isDis) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F).withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFD32F2F).withAlpha(80)),
                  ),
                  child: const Text(
                    '🔴 LKP ACTIVA',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD32F2F),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  animal.status.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Name and ID
          Row(
            children: [
              Icon(
                animal.sex == 'hembra' ? Icons.female_rounded : Icons.male_rounded,
                size: 16,
                color: animal.sex == 'hembra' ? const Color(0xFFE91E63) : const Color(0xFF2196F3),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  animal.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '#${animal.id}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${animal.breed} • ${animal.category.toUpperCase()} • ${animal.pasture}',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Live IoT Status / Telemetry strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isDis
                  ? const Color(0xFFD32F2F).withAlpha(12)
                  : (animal.deviceId.isNotEmpty ? AppTheme.surfaceVariant : AppTheme.surface),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDis ? const Color(0xFFD32F2F).withAlpha(70) : AppTheme.divider,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  animal.deviceId.isNotEmpty
                      ? (isDis ? Icons.sensors_off_rounded : Icons.sensors_rounded)
                      : Icons.sensors_off_rounded,
                  size: 13,
                  color: isDis
                      ? const Color(0xFFD32F2F)
                      : (animal.deviceId.isNotEmpty ? AppTheme.primary : AppTheme.textSecondary.withAlpha(100)),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    animal.deviceId.isNotEmpty
                        ? (isDis
                            ? '🔴 Desconectado ($disMinutes m) • LKP Congelada'
                            : (reading != null
                                ? '${reading.temperature.toStringAsFixed(1)}°C • Bat ${reading.batteryLevel}% • Activo'
                                : 'Collar: ${animal.deviceId}'))
                        : 'Sin collar IoT vinculado',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isDis ? FontWeight.w700 : FontWeight.w600,
                      color: isDis
                          ? const Color(0xFFD32F2F)
                          : (animal.deviceId.isNotEmpty ? AppTheme.textPrimary : AppTheme.textSecondary),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (animal.weightKg != null) ...[
                  Text(
                    '${animal.weightKg!.toStringAsFixed(0)} kg',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDis ? const Color(0xFFD32F2F) : AppTheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showAnimalDetails(animal),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: Size.zero,
                    side: BorderSide(color: AppTheme.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Ficha', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 6),
              if (animal.deviceId.isNotEmpty && widget.onNavigate != null) ...[
                IconButton(
                  onPressed: () => widget.onNavigate!(9),
                  icon: Icon(isDis ? Icons.radar_rounded : Icons.map_rounded, size: 16),
                  tooltip: isDis ? 'Rastrear LKP en Mapa GPS (Radio Activo)' : 'Rastrear en Mapa GPS',
                  style: IconButton.styleFrom(
                    backgroundColor: isDis ? const Color(0xFFD32F2F).withAlpha(20) : AppTheme.primary.withAlpha(15),
                    foregroundColor: isDis ? const Color(0xFFD32F2F) : AppTheme.primary,
                    padding: const EdgeInsets.all(6),
                    minimumSize: Size.zero,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final saved = await showAddMedicalDialog(context, animalId: animal.id);
                    if (saved == true) _loadAnimals();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Salud', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableView(List<AnimalProfile> filtered) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth > 850 ? constraints.maxWidth : 850,
            child: Column(
              children: [
                // Column Headers
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  child: Row(
                    children: const [
                      _ColHeader('ID', flex: 1),
                      _ColHeader('Nombre', flex: 2),
                      _ColHeader('Arete SINIIGA', flex: 2),
                      _ColHeader('Raza', flex: 2),
                      _ColHeader('Sexo', flex: 1),
                      _ColHeader('Peso', flex: 1),
                      _ColHeader('Potrero', flex: 2),
                      _ColHeader('Sensor / Collar', flex: 2),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppTheme.divider),

                // Rows
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.divider),
                    itemBuilder: (context, index) {
                      final animal = filtered[index];
                      final isHovered = _hoveredIndex == index;
                      final isCollar = animal.deviceId.isNotEmpty;
                      final isDis = isCollar && ((widget.demoService?.isCollarSimulatedDisconnected == true && animal.deviceId.toLowerCase().contains('collar')) || (widget.demoService != null && !widget.demoService!.isCollarOnline(animal.deviceId)));

                      return InkWell(
                        onTap: () => _showAnimalDetails(animal),
                        onHover: (hovering) {
                          setState(() {
                            _hoveredIndex = hovering ? index : null;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          color: isHovered ? AppTheme.primary.withAlpha(12) : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              // ID
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '#${animal.id}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                              // Nombre
                              Expanded(
                                flex: 2,
                                child: Row(
                                  children: [
                                    Icon(
                                      animal.sex == 'hembra' ? Icons.female_rounded : Icons.male_rounded,
                                      size: 16,
                                      color: animal.sex == 'hembra' ? const Color(0xFFE91E63) : const Color(0xFF2196F3),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      animal.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // SINIIGA
                              Expanded(
                                flex: 2,
                                child: Text(
                                  animal.siniigaTag,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              // Raza
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withAlpha(20),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      animal.breed,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Sexo
                              Expanded(
                                flex: 1,
                                child: Text(
                                  animal.sex == 'hembra' ? 'H' : 'M',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              // Peso
                              Expanded(
                                flex: 1,
                                child: Text(
                                  animal.weightKg != null ? '${animal.weightKg!.toStringAsFixed(0)} kg' : '--',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              // Potrero
                              Expanded(
                                flex: 2,
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on_rounded, size: 12, color: AppTheme.textSecondary),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        animal.pasture,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Sensor / Collar + GPS
                              Expanded(
                                flex: 2,
                                child: Row(
                                  children: [
                                    if (animal.deviceId.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDis ? const Color(0xFFD32F2F).withAlpha(15) : AppTheme.primary.withAlpha(12),
                                          borderRadius: BorderRadius.circular(4),
                                          border: isDis ? Border.all(color: const Color(0xFFD32F2F).withAlpha(80)) : null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isDis ? Icons.sensors_off_rounded : Icons.sensors_rounded,
                                              size: 12,
                                              color: isDis ? const Color(0xFFD32F2F) : AppTheme.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isDis ? '${animal.deviceId} (LKP)' : animal.deviceId,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isDis ? const Color(0xFFD32F2F) : AppTheme.primary,
                                                fontWeight: isDis ? FontWeight.bold : FontWeight.normal,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (widget.onNavigate != null) ...[
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () => widget.onNavigate!(9),
                                          child: Icon(
                                            isDis ? Icons.radar_rounded : Icons.map_rounded,
                                            size: 14,
                                            color: isDis ? const Color(0xFFD32F2F) : AppTheme.primary,
                                          ),
                                        ),
                                      ],
                                    ] else ...[
                                      Text(
                                        'Sin sensor',
                                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withAlpha(80)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String label;
  final int flex;
  const _ColHeader(this.label, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _QuickStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}