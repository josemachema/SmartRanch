import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/health_alert.dart';
import '../models/ranch_models.dart';
import '../services/demo_service.dart';
import '../services/ranch_api_service.dart';
import '../widgets/crud_dialogs.dart';

/// Sanidad (Medical/Health) screen with 6 tabs, live collar IoT health scanning,
/// dedicated upcoming reminders card, and automatic event scheduling.
class SanidadScreen extends StatefulWidget {
  final DemoService? demoService;
  const SanidadScreen({super.key, this.demoService});

  @override
  State<SanidadScreen> createState() => _SanidadScreenState();
}

class _SanidadScreenState extends State<SanidadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MedicalRecord> _records = List.from(_demoRecords);
  List<Map<String, dynamic>> _upcoming = [
    {
      'animal_id': 1,
      'animal_name': 'Lupita',
      'product_name': 'Pasturela bovina (Refuerzo)',
      'type': 'vaccine',
      'next_due_date': DateTime.now().add(const Duration(days: 4)).toIso8601String(),
      'days_left': 4,
    },
    {
      'animal_id': 2,
      'animal_name': 'Estrella',
      'product_name': 'Ivermectina 1% Desparasitante',
      'type': 'deworming',
      'next_due_date': DateTime.now().add(const Duration(days: 11)).toIso8601String(),
      'days_left': 11,
    },
    {
      'animal_id': 3,
      'animal_name': 'Canela',
      'product_name': 'Clostridiosis 8 Vías',
      'type': 'vaccine',
      'next_due_date': DateTime.now().add(const Duration(days: 25)).toIso8601String(),
      'days_left': 25,
    },
    {
      'animal_id': 5,
      'animal_name': 'Valentina',
      'product_name': 'Revisión Cicatrización Quirúrgica',
      'type': 'surgery',
      'next_due_date': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
      'days_left': 2,
    },
  ];
  Timer? _refreshTimer;

  static final _demoRecords = [
    MedicalRecord(
      id: 1,
      animalId: 1,
      recordType: 'vaccine',
      productName: 'Pasturela bovina',
      dose: '5ml IM',
      administeredBy: 'Dr. Ramírez',
      cost: 180.0,
      nextDueDate: DateTime.now().add(const Duration(days: 180)),
      recordedAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    MedicalRecord(
      id: 2,
      animalId: 2,
      recordType: 'deworming',
      productName: 'Ivermectina 1%',
      dose: '10ml SC',
      administeredBy: 'Dr. Ramírez',
      cost: 95.0,
      nextDueDate: DateTime.now().add(const Duration(days: 90)),
      recordedAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    MedicalRecord(
      id: 3,
      animalId: 3,
      recordType: 'treatment',
      productName: 'Penicilina + Estreptomicina',
      dose: '15ml IM',
      administeredBy: 'Juan',
      cost: 220.0,
      withdrawalDays: 30,
      recordedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    MedicalRecord(
      id: 4,
      animalId: 4,
      recordType: 'vaccine',
      productName: 'Brucelosis (RB51)',
      dose: '2ml SC',
      administeredBy: 'Dr. Ramírez',
      cost: 350.0,
      nextDueDate: DateTime.now().add(const Duration(days: 340)),
      recordedAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
    MedicalRecord(
      id: 5,
      animalId: 5,
      recordType: 'surgery',
      productName: 'Descorné Quirúrgico',
      dose: 'Anestesia local 10ml',
      administeredBy: 'Dr. Ramírez',
      cost: 450.0,
      notes: 'Curación post-operatoria con cicatrizante',
      recordedAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
    MedicalRecord(
      id: 6,
      animalId: 1,
      recordType: 'exam',
      productName: 'Análisis de sangre y Brucela',
      dose: 'Muestra 10ml',
      administeredBy: 'Dr. Ramírez',
      cost: 500.0,
      notes: 'Resultados negativos / normales',
      recordedAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 6 Tabs: Vacunas, Tratamientos, Desparasit., Cirugías, Próximos, Historial
    _tabController = TabController(length: 6, vsync: this);
    _loadData();
    widget.demoService?.addListener(_onIoT);

    // Live refresh timer to update collar telemetry and check due dates in real-time
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkDueDatesProgression();
      if (mounted) setState(() {});
    });
  }

  void _onIoT() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    widget.demoService?.removeListener(_onIoT);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    try {
      final results = await Future.wait([
        RanchApiService.getMedicalRecords(),
        RanchApiService.getUpcomingMedical(days: 60),
      ]).timeout(const Duration(milliseconds: 1200));

      final records = results[0] as List<MedicalRecord>;
      final upcoming = results[1] as List<Map<String, dynamic>>;

      if (!mounted) return;
      setState(() {
        if (records.isNotEmpty) _records = records;
        if (upcoming.isNotEmpty) _upcoming = upcoming;
      });
    } catch (_) {
      // Graceful fallback to default records without blocking the screen
    }
  }

  void _checkDueDatesProgression() {
    final now = DateTime.now();
    for (final r in _records) {
      if (r.nextDueDate != null) {
        final diffDays = r.nextDueDate!.difference(now).inDays;
        final alreadyInUpcoming = _upcoming.any((u) =>
            u['animal_id'] == r.animalId &&
            u['product_name'] == (r.productName ?? 'Tratamiento'));
        if (diffDays <= 30 && !alreadyInUpcoming) {
          _upcoming.add({
            'animal_id': r.animalId,
            'animal_name': 'Animal #${r.animalId}',
            'product_name': '${r.productName ?? "Dosis"} (Refuerzo)',
            'type': r.recordType,
            'next_due_date': r.nextDueDate!.toIso8601String(),
            'days_left': diffDays,
          });
        }
      }
    }
  }

  Future<void> _openAddDialog({int? animalId, Map<String, dynamic>? upcomingItem}) async {
    final prodName = upcomingItem?['product_name']?.toString();
    final itemType = upcomingItem?['type']?.toString();

    final saved = await showAddMedicalDialog(
      context,
      animalId: animalId,
      initialProduct: prodName,
      initialType: itemType,
    );

    if (!mounted) return;

    if (saved == true) {
      setState(() {
        if (upcomingItem != null) {
          _upcoming.remove(upcomingItem);
        }
      });

      await _loadData();
      if (!mounted) return;

      // Switch to the relevant tab
      if (itemType == 'deworming' || (prodName != null && prodName.toLowerCase().contains('ivermectina'))) {
        _tabController.animateTo(2); // Desparasit.
      } else if (itemType == 'surgery' || (prodName != null && prodName.toLowerCase().contains('quir'))) {
        _tabController.animateTo(3); // Cirugías
      } else if (itemType == 'treatment') {
        _tabController.animateTo(1); // Tratamientos
      } else {
        _tabController.animateTo(0); // Vacunas
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(upcomingItem != null
                ? '✅ Dosis aplicada exitosamente. El pendiente fue archivado en el historial.'
                : '✅ Evento sanitario registrado y programado en el calendario'),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSonoraCalendarDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppTheme.divider),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.verified_user_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calendario Zoosanitario Sonora (SENASICA)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Campañas oficiales obligatorias para estatus de Hato Libre',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSonoraCampaignTile(
                        ctx,
                        title: 'Rabia Paralítica Bovina (Derriengue)',
                        frequency: 'Semestral (Abril / Octubre)',
                        description: 'Vacunación preventiva obligatoria en zonas con presencia del murciélago hematófago.',
                        type: 'vaccine',
                        product: 'Vacuna Derriengue Bovina',
                      ),
                      const SizedBox(height: 8),
                      _buildSonoraCampaignTile(
                        ctx,
                        title: 'Brucelosis Bovina (Cepa RB51)',
                        frequency: 'Becerros / Terneras de 3 a 8 meses',
                        description: 'Inmunización única de hembras jóvenes para mantener zona libre de abortos infecciosos.',
                        type: 'vaccine',
                        product: 'Brucelosis RB51',
                      ),
                      const SizedBox(height: 8),
                      _buildSonoraCampaignTile(
                        ctx,
                        title: 'Tuberculosis Bovina (Tuberculinización)',
                        frequency: 'Anual (Obligatorio para Guía REEMO)',
                        description: 'Prueba anocaudal por MVZ certificado requerida para movilización interestatal y rastro.',
                        type: 'exam',
                        product: 'Prueba Tuberculina PPD Bovina',
                      ),
                      const SizedBox(height: 8),
                      _buildSonoraCampaignTile(
                        ctx,
                        title: 'Control de Garrapata Boophilus Microplus',
                        frequency: 'Cada 21 a 30 días (Temporada Calurosa)',
                        description: 'Baños de inmersión / aspersión con amitraz o cipermetrina para evitar babesiosis.',
                        type: 'deworming',
                        product: 'Baño Acaricida Antiparasitario',
                      ),
                      const SizedBox(height: 8),
                      _buildSonoraCampaignTile(
                        ctx,
                        title: 'Clostridiosis 8 Vías (Carbón y Edema)',
                        frequency: 'Anual (Antes de lluvias de verano)',
                        description: 'Protección contra carbón sintomático, edema maligno y enterotoxemia en pastoreo.',
                        type: 'vaccine',
                        product: 'Bacterina Clostridial 8 Vías',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSonoraCampaignTile(
    BuildContext ctx, {
    required String title,
    required String frequency,
    required String description,
    required String type,
    required String product,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppTheme.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        frequency,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openAddDialog(
                        upcomingItem: {
                          'product_name': product,
                          'type': type,
                        },
                      );
                    },
                    icon: const Icon(Icons.add_task_rounded, size: 14),
                    label: const Text('Programar en Ranura', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthAlerts = widget.demoService?.activeHealthAlerts ?? {};

    return Column(
      children: [
        // Top Action Bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              Icon(Icons.medical_services_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Control Sanitario y Vacunación',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Cálculo automático de refuerzos, retiros y bitácora clínica',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _showSonoraCalendarDialog,
                icon: const Icon(Icons.shield_outlined, size: 15),
                label: const Text('Campaña Sonora', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: AppTheme.primary.withAlpha(120)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openAddDialog(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Registrar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 850) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLiveScanPanel(healthAlerts, isMobile: true),
                      const SizedBox(height: 12),
                      _buildWithdrawalTrackerCard(isMobile: true),
                      const SizedBox(height: 12),
                      _buildUpcomingSideCard(isMobile: true),
                      const SizedBox(height: 12),
                      _buildRecordsPanel(isMobile: true),
                    ],
                  ),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT COLUMN: Live Scan Box on top, Withdrawal & Upcoming Box below
                  SizedBox(
                    width: 320,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildLiveScanPanel(healthAlerts, isMobile: false),
                          const SizedBox(height: 12),
                          _buildWithdrawalTrackerCard(isMobile: false),
                          const SizedBox(height: 12),
                          _buildUpcomingSideCard(isMobile: false),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // RIGHT COLUMN: Medical Records Tabs
                  Expanded(child: _buildRecordsPanel()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Live Health Scanner Box (Collares IoT) — shortened title to prevent overflow
  Widget _buildLiveScanPanel(Map<String, HealthAlert> alerts, {bool isMobile = false}) {
    final readings = widget.demoService?.latestReadings ?? {};
    final activeCollar = readings['Collar-SmartRanch'] ?? (readings.isNotEmpty ? readings.values.first : null);

    return Container(
      margin: isMobile
          ? const EdgeInsets.fromLTRB(12, 12, 12, 0)
          : const EdgeInsets.fromLTRB(16, 12, 0, 0),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with pulsating green radar indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              children: [
                Icon(Icons.radar_rounded, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Escáner Sanitario IoT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'EN VIVO',
                        style: TextStyle(color: AppTheme.primary, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Live Telemetry or Alert Items
          alerts.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (activeCollar != null) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.sensors_rounded, size: 16, color: AppTheme.primary),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activeCollar.animalName.isNotEmpty
                                        ? activeCollar.animalName
                                        : 'Vaca Collar 01',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Collar: ${activeCollar.deviceId}',
                                    style: TextStyle(fontSize: 9.5, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withAlpha(15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Normotermia',
                                style: const TextStyle(color: AppTheme.primary, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Vitals row
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.divider),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.thermostat_rounded, size: 12, color: AppTheme.thiDanger),
                                        const SizedBox(width: 4),
                                        Text('MLX90614', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${activeCollar.temperature.toStringAsFixed(1)}°C',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                    ),
                                    Text('Temp. Corporal', style: TextStyle(fontSize: 8.5, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.divider),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.directions_walk_rounded, size: 12, color: AppTheme.primary),
                                        const SizedBox(width: 4),
                                        Text('ADXL345', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${activeCollar.movementIntensity.toStringAsFixed(2)}g',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                    ),
                                    Text('Rumia / Actividad', style: TextStyle(fontSize: 8.5, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.bolt_rounded, size: 12, color: AppTheme.primary),
                                const SizedBox(width: 2),
                                Text(
                                  'Batería: ${activeCollar.batteryLevel}%',
                                  style: TextStyle(fontSize: 9.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Text(
                              'RTDB Puerto Peñasco',
                              style: TextStyle(fontSize: 9, color: AppTheme.textSecondary.withAlpha(150)),
                            ),
                          ],
                        ),
                      ] else ...[
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.health_and_safety_rounded, size: 28, color: AppTheme.primary.withAlpha(90)),
                              const SizedBox(height: 6),
                              Text('Sin anomalías de salud',
                                  style: TextStyle(fontSize: 11.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('Monitoreo MLX90614 y ADXL345 activo',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 9.5, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  children: alerts.values.map((HealthAlert alert) {
                    final t = alert.type;
                    final alertColor = t == 'sick_suspected'
                        ? AppTheme.thiEmergency
                        : t == 'fever'
                            ? AppTheme.thiDanger
                            : AppTheme.thiAlert;
                    final alertIcon = t == 'sick_suspected'
                        ? Icons.local_hospital_rounded
                        : t == 'fever'
                            ? Icons.thermostat_rounded
                            : Icons.trending_down_rounded;
                    final alertLabel = t == 'sick_suspected'
                        ? 'Posible enfermedad'
                        : t == 'fever'
                            ? 'Fiebre detectada'
                            : 'Letargo detectado';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: alertColor.withAlpha(12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: alertColor.withAlpha(50)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(alertIcon, size: 14, color: alertColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  alert.animalName.isNotEmpty ? alert.animalName : alert.deviceId,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(alertLabel,
                              style: TextStyle(fontSize: 10, color: alertColor, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.thermostat_rounded, size: 11, color: AppTheme.textSecondary),
                              const SizedBox(width: 2),
                              Text('${alert.bodyTemp.toStringAsFixed(1)}°C',
                                  style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                              const SizedBox(width: 8),
                              Icon(Icons.directions_walk_rounded, size: 11, color: AppTheme.textSecondary),
                              const SizedBox(width: 2),
                              Text('Mov: ${alert.movementIntensity.toStringAsFixed(1)}',
                                  style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  /// Semáforo de Tiempo de Retiro Farmacológico (Drug Withdrawal Tracker)
  Widget _buildWithdrawalTrackerCard({bool isMobile = false}) {
    final now = DateTime.now();
    final withdrawalRecords = _records.where((r) => r.withdrawalDays > 0).toList();

    return Container(
      margin: isMobile
          ? const EdgeInsets.symmetric(horizontal: 12)
          : const EdgeInsets.fromLTRB(16, 0, 0, 0),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 16, color: AppTheme.thiAlert),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tiempo de Retiro Farmacológico',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.thiAlert.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${withdrawalRecords.length}',
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.thiAlert),
                  ),
                ),
              ],
            ),
          ),
          if (withdrawalRecords.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Hato libre de periodos de retiro',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 10.5),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              itemCount: withdrawalRecords.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final rec = withdrawalRecords[index];
                final recorded = rec.recordedAt ?? now;
                final elapsed = now.difference(recorded).inDays;
                final daysLeft = (rec.withdrawalDays - elapsed).clamp(0, 999);
                final isInWithdrawal = daysLeft > 0;

                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isInWithdrawal ? AppTheme.thiAlert.withAlpha(12) : AppTheme.primary.withAlpha(10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isInWithdrawal ? AppTheme.thiAlert.withAlpha(50) : AppTheme.primary.withAlpha(40),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isInWithdrawal ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                        size: 16,
                        color: isInWithdrawal ? AppTheme.thiAlert : AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.productName ?? 'Antibiótico / Medicamento',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              isInWithdrawal
                                  ? 'Vaca #${rec.animalId} • Restricción de leche y carne'
                                  : 'Vaca #${rec.animalId} • Periodo finalizado',
                              style: TextStyle(
                                fontSize: 9,
                                color: isInWithdrawal ? AppTheme.thiAlert : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isInWithdrawal ? AppTheme.thiAlert.withAlpha(25) : AppTheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isInWithdrawal ? '$daysLeft d restantes' : 'Liberada',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isInWithdrawal ? AppTheme.thiAlert : AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Dedicated Upcoming Health Events Card (Separate box below live scan)
  Widget _buildUpcomingSideCard({bool isMobile = false}) {
    return Container(
      margin: isMobile
          ? const EdgeInsets.symmetric(horizontal: 12)
          : const EdgeInsets.fromLTRB(16, 0, 0, 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: AppTheme.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Próximos Eventos Sanitarios',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_upcoming.length}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.secondary),
                  ),
                ),
              ],
            ),
          ),
          if (_upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              child: Center(
                child: Text(
                  'No hay recordatorios pendientes',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              itemCount: _upcoming.take(4).length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = _upcoming[index];
                final name = item['animal_name'] ?? 'Animal #${item['animal_id'] ?? ''}';
                final product = item['product_name'] ?? 'Dosis';
                final daysLeft = item['days_left'] ?? 0;

                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                            Text('$name • En $daysLeft días',
                                style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () => _openAddDialog(
                          animalId: item['animal_id'],
                          upcomingItem: item,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Aplicada', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Medical Records Tabbed Panel
  Widget _buildRecordsPanel({bool isMobile = false}) {
    final tabContent = TabBarView(
      controller: _tabController,
      children: [
        _buildRecordsList('vaccine'),
        _buildRecordsList('treatment'),
        _buildRecordsList('deworming'),
        _buildRecordsList('surgery'),
        _buildUpcomingList(),
        _buildHistoryList(),
      ],
    );

    return Container(
      margin: isMobile
          ? const EdgeInsets.symmetric(horizontal: 12)
          : const EdgeInsets.fromLTRB(0, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          // Tab bar with 6 tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            dividerColor: AppTheme.divider,
            tabs: const [
              Tab(icon: Icon(Icons.vaccines_rounded, size: 16), text: 'Vacunas'),
              Tab(icon: Icon(Icons.medical_services_rounded, size: 16), text: 'Tratamientos'),
              Tab(icon: Icon(Icons.bug_report_rounded, size: 16), text: 'Desparasit.'),
              Tab(icon: Icon(Icons.content_cut_rounded, size: 16), text: 'Cirugías'),
              Tab(icon: Icon(Icons.calendar_month_rounded, size: 16), text: 'Próximos'),
              Tab(icon: Icon(Icons.history_rounded, size: 16), text: 'Historial'),
            ],
          ),
          if (isMobile)
            SizedBox(
              height: 420,
              child: tabContent,
            )
          else
            Expanded(
              child: tabContent,
            ),
        ],
      ),
    );
  }

  Widget _buildUpcomingList() {
    if (_upcoming.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_rounded, size: 40, color: AppTheme.textSecondary.withAlpha(80)),
            const SizedBox(height: 12),
            Text('No hay refuerzos pendientes', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _upcoming.length,
      itemBuilder: (context, index) {
        final item = _upcoming[index];
        final name = item['animal_name'] ?? 'Animal #${item['animal_id'] ?? ''}';
        final product = item['product_name'] ?? 'Vacunación';
        final daysLeft = item['days_left'] ?? 10;
        final dueDateStr = item['next_due_date'] ?? '';
        final dueDate = DateTime.tryParse(dueDateStr) ?? DateTime.now();
        final isUrgent = daysLeft <= 7;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isUrgent ? AppTheme.secondary.withAlpha(80) : AppTheme.divider,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isUrgent ? AppTheme.secondary.withAlpha(20) : AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: isUrgent ? AppTheme.secondary : AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vaca: $name • Fecha: ${dueDate.day}/${dueDate.month}/${dueDate.year}',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isUrgent ? AppTheme.secondary.withAlpha(20) : AppTheme.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  daysLeft <= 0 ? '¡HOY!' : 'En $daysLeft días',
                  style: TextStyle(
                    color: isUrgent ? AppTheme.secondary : AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openAddDialog(
                  animalId: item['animal_id'],
                  upcomingItem: item,
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                label: const Text('Aplicada', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// General Health Bitácora / History List
  Widget _buildHistoryList() {
    final sorted = List<MedicalRecord>.from(_records)
      ..sort((a, b) => (b.recordedAt ?? DateTime(2000)).compareTo(a.recordedAt ?? DateTime(2000)));

    if (sorted.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 40, color: AppTheme.textSecondary.withAlpha(80)),
            const SizedBox(height: 12),
            Text('No hay registros históricos', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final record = sorted[index];
        final typeLabel = record.recordType == 'vaccine'
            ? 'Vacuna'
            : record.recordType == 'treatment'
                ? 'Tratamiento'
                : record.recordType == 'deworming'
                    ? 'Desparasitación'
                    : record.recordType == 'surgery'
                        ? 'Cirugía'
                        : 'Examen';

        final icon = record.recordType == 'vaccine'
            ? Icons.vaccines_rounded
            : record.recordType == 'treatment'
                ? Icons.medical_services_rounded
                : record.recordType == 'deworming'
                    ? Icons.bug_report_rounded
                    : record.recordType == 'surgery'
                        ? Icons.content_cut_rounded
                        : Icons.biotech_rounded;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.productName ?? typeLabel,
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      typeLabel,
                      style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (record.cost != null) ...[
                    const SizedBox(width: 8),
                    Text('\$${record.cost!.toStringAsFixed(0)}',
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('Animal #${record.animalId}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                  if (record.dose != null) ...[
                    const SizedBox(width: 8),
                    Text('• ${record.dose!}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                  if (record.administeredBy != null) ...[
                    const SizedBox(width: 8),
                    Text('• Aplicó: ${record.administeredBy!}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ],
              ),
              if (record.recordedAt != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Registrado: ${record.recordedAt!.day}/${record.recordedAt!.month}/${record.recordedAt!.year}',
                    style: TextStyle(color: AppTheme.textSecondary.withAlpha(150), fontSize: 9),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecordsList(String type) {
    final filtered = _records.where((r) => r.recordType == type).toList();
    if (filtered.isEmpty) {
      final icon = type == 'vaccine'
          ? Icons.vaccines_rounded
          : type == 'treatment'
              ? Icons.medical_services_rounded
              : type == 'surgery'
                  ? Icons.content_cut_rounded
                  : Icons.bug_report_rounded;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppTheme.textSecondary.withAlpha(80)),
            const SizedBox(height: 12),
            Text('Sin registros en esta categoría', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final record = filtered[index];
        final typeIcon = record.recordType == 'vaccine'
            ? Icons.vaccines_rounded
            : record.recordType == 'treatment'
                ? Icons.medical_services_rounded
                : record.recordType == 'surgery'
                    ? Icons.content_cut_rounded
                    : record.recordType == 'exam'
                        ? Icons.biotech_rounded
                        : Icons.bug_report_rounded;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(typeIcon, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(record.productName ?? record.recordType,
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  if (record.cost != null)
                    Text('\$${record.cost!.toStringAsFixed(0)}',
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (record.dose != null) ...[
                    Icon(Icons.medication_liquid_rounded, size: 12, color: AppTheme.textSecondary),
                    const SizedBox(width: 3),
                    Text(record.dose!, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    const SizedBox(width: 12),
                  ],
                  if (record.administeredBy != null) ...[
                    Icon(Icons.person_outline_rounded, size: 12, color: AppTheme.textSecondary),
                    const SizedBox(width: 3),
                    Text(record.administeredBy!, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ],
              ),
              if (record.withdrawalDays > 0) ...[
                const SizedBox(height: 4),
                Builder(
                  builder: (context) {
                    final recDate = record.recordedAt ?? DateTime.now();
                    final elapsed = DateTime.now().difference(recDate).inDays;
                    final daysLeft = (record.withdrawalDays - elapsed).clamp(0, 999);
                    final isRestricted = daysLeft > 0;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isRestricted ? AppTheme.thiAlert.withAlpha(20) : AppTheme.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isRestricted ? AppTheme.thiAlert.withAlpha(60) : AppTheme.primary.withAlpha(40),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isRestricted ? Icons.timer_outlined : Icons.check_circle_outline_rounded,
                            size: 11,
                            color: isRestricted ? AppTheme.thiAlert : AppTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isRestricted
                                ? 'Retiro: $daysLeft días restantes (Total: ${record.withdrawalDays}d)'
                                : 'Retiro cumplido (${record.withdrawalDays}d) — Apta',
                            style: TextStyle(
                              color: isRestricted ? AppTheme.thiAlert : AppTheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              if (record.nextDueDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.event_rounded, size: 12, color: AppTheme.secondary),
                    const SizedBox(width: 3),
                    Text('Próximo: ${record.nextDueDate!.day}/${record.nextDueDate!.month}/${record.nextDueDate!.year}',
                        style: const TextStyle(color: AppTheme.secondary, fontSize: 10)),
                  ],
                ),
              ],
              if (record.recordedAt != null) ...[
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('${record.recordedAt!.day}/${record.recordedAt!.month}/${record.recordedAt!.year}',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
