import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/trough_reading.dart';
import '../services/demo_service.dart';
import '../widgets/trough_card.dart';

/// Console for ranch water management and IoT trough telemetry.
/// Designed for desert cattle operations (Puerto Peñasco, Sonora).
class WaterDashboardScreen extends StatefulWidget {
  final DemoService demoService;

  const WaterDashboardScreen({super.key, required this.demoService});

  @override
  State<WaterDashboardScreen> createState() => _WaterDashboardScreenState();
}

class _WaterDashboardScreenState extends State<WaterDashboardScreen> {
  String _selectedFilter = 'all'; // 'all', 'optimal', 'low'
  final TextEditingController _searchCtrl = TextEditingController();

  // Simulated herd parameters for water autonomy calculations
  static const int _herdSize = 52; // 52 bovinos
  static const double _baseLitersPerCowDay = 68.0; // 68 L en verano Sonora

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.demoService,
      builder: (context, _) {
        final allTroughs = widget.demoService.troughReadings.values.toList();

        // If empty in demo, fallback to standard Puerto Peñasco troughs
        final troughs = allTroughs.isNotEmpty
            ? allTroughs
            : [
                TroughReading(
                  troughId: 'bebedero_01',
                  troughName: 'Potrero Norte',
                  levelPercent: 85,
                  distanceCm: 15.0,
                  tankDepthCm: 100,
                  capacityLiters: 8000,
                  waterTemperature: 21.4,
                  batteryPercent: 94,
                  tankType: 'Tanque Nodriza UV 8,000L',
                ),
                TroughReading(
                  troughId: 'bebedero_02',
                  troughName: 'Corral Principal',
                  levelPercent: 92,
                  distanceCm: 8.0,
                  tankDepthCm: 100,
                  capacityLiters: 5000,
                  waterTemperature: 22.1,
                  batteryPercent: 88,
                  tankType: 'Pileta Concreto Corral 5,000L',
                ),
              ];

        // Filtered list
        final filteredTroughs = troughs.where((t) {
          final query = _searchCtrl.text.toLowerCase().trim();
          final matchesQuery = query.isEmpty ||
              t.troughName.toLowerCase().contains(query) ||
              t.troughId.toLowerCase().contains(query) ||
              t.effectiveTankType.toLowerCase().contains(query);

          if (!matchesQuery) return false;

          if (_selectedFilter == 'optimal') return t.levelPercent > 50;
          if (_selectedFilter == 'low') return t.levelPercent <= 25;
          return true;
        }).toList();

        // Ranch totals
        final double totalStoredLiters = troughs.fold(
            0.0, (acc, t) => acc + t.currentVolumeLiters);
        final double totalCapacityLiters = troughs.fold(
            0.0, (acc, t) => acc + t.effectiveCapacityLiters);
        final double avgLevelPercent = totalCapacityLiters > 0
            ? (totalStoredLiters / totalCapacityLiters) * 100.0
            : 0.0;
        final double avgTemp = troughs.isNotEmpty
            ? troughs.map((t) => t.effectiveWaterTemp).reduce((a, b) => a + b) /
                troughs.length
            : 21.0;

        // Autonomy calculation: total stored / daily demand
        final double dailyHerdDemandLiters = _herdSize * _baseLitersPerCowDay;
        final double daysAutonomy = dailyHerdDemandLiters > 0
            ? (totalStoredLiters / dailyHerdDemandLiters)
            : 0.0;

        final int lowCount = troughs.where((t) => t.isLow).length;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Screen Header ────────────────────────────────────
                _buildHeader(context),

                const SizedBox(height: 18),

                // ── Critical Warning Banner (if low troughs exist) ───
                if (lowCount > 0)
                  _buildCriticalAlertBanner(context, lowCount),

                // ── Ranch Water Console KPI Cards ────────────────────
                _buildKpiGrid(
                  totalStoredLiters: totalStoredLiters,
                  totalCapacityLiters: totalCapacityLiters,
                  avgLevelPercent: avgLevelPercent,
                  daysAutonomy: daysAutonomy,
                  avgTemp: avgTemp,
                  troughsCount: troughs.length,
                ),

                const SizedBox(height: 24),

                // ── Controls & Filter Bar ────────────────────────────
                _buildControlsBar(context, troughs.length, lowCount),

                const SizedBox(height: 20),

                // ── Main Content: 2-Column Responsive Layout ────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isDesktop = constraints.maxWidth >= 1000;

                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Trough Cards (62%)
                          Expanded(
                            flex: 62,
                            child: _buildTroughsList(filteredTroughs),
                          ),
                          const SizedBox(width: 24),

                          // Right Column: Water Intelligence & Drought Protocol (38%)
                          Expanded(
                            flex: 38,
                            child: _buildIntelligenceSideColumn(
                              totalStoredLiters: totalStoredLiters,
                              dailyHerdDemandLiters: dailyHerdDemandLiters,
                              daysAutonomy: daysAutonomy,
                              avgTemp: avgTemp,
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Stacked layout for tablet / mobile
                      return Column(
                        children: [
                          _buildTroughsList(filteredTroughs),
                          const SizedBox(height: 24),
                          _buildIntelligenceSideColumn(
                            totalStoredLiters: totalStoredLiters,
                            dailyHerdDemandLiters: dailyHerdDemandLiters,
                            daysAutonomy: daysAutonomy,
                            avgTemp: avgTemp,
                          ),
                        ],
                      );
                    }
                  },
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Drop droplet icon
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0288D1), Color(0xFF00ACC1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0288D1).withAlpha(60),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        // Title & Location
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Gestión Hídrica & Bebederos IoT',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0288D1).withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0288D1).withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0288D1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Telemetría en Vivo',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0288D1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Rancho Puerto Peñasco, Sonora • Reserva Hídrica Total y Monitoreo Ultrasónico JSN-SR04T',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Quick Action: Add Trough Button
        ElevatedButton.icon(
          onPressed: () => _showAddTroughDialog(context),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('+ Nuevo Bebedero'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CRITICAL ALERT BANNER
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCriticalAlertBanner(BuildContext context, int lowCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF1744).withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF1744).withAlpha(80), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF1744).withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFF1744),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALERTA DE DESABASTO: $lowCount bebedero(s) con nivel crítico (≤ 20%)',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF1744),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'El ganado en potreros afectados requiere acceso urgente a agua fresca para evitar deshidratación y detención de rumia.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textPrimary.withAlpha(200),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // Refill all low troughs
              for (final t in widget.demoService.troughReadings.values) {
                if (t.isLow) {
                  widget.demoService.refillTrough(t.troughId);
                }
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bomba activada: Llenando bebederos en alerta.'),
                  backgroundColor: Color(0xFF0288D1),
                ),
              );
            },
            icon: const Icon(Icons.flash_on_rounded, size: 14),
            label: const Text('Activar Bomba'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF1744),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 4 GLOBAL KPI CONSOLE CARDS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildKpiGrid({
    required double totalStoredLiters,
    required double totalCapacityLiters,
    required double avgLevelPercent,
    required double daysAutonomy,
    required double avgTemp,
    required int troughsCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final cardWidth = isWide
            ? (constraints.maxWidth - (3 * 16)) / 4
            : (constraints.maxWidth - 16) / 2;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            // KPI 1: Total Stored Water
            SizedBox(
              width: cardWidth,
              child: _WaterKpiCard(
                title: 'Reserva Hídrica Total',
                value: '${totalStoredLiters.toStringAsFixed(0)} L',
                subtitle: 'de ${totalCapacityLiters.toStringAsFixed(0)} L capacidad',
                badgeText: '${avgLevelPercent.toStringAsFixed(0)}% Óptimo',
                badgeColor: const Color(0xFF0288D1),
                icon: Icons.water_rounded,
                progressFactor: (avgLevelPercent / 100.0).clamp(0.0, 1.0),
              ),
            ),

            // KPI 2: Herd Autonomy
            SizedBox(
              width: cardWidth,
              child: _WaterKpiCard(
                title: 'Autonomía del Hato',
                value: '${daysAutonomy.toStringAsFixed(1)} Días',
                subtitle: 'Demanda: ~${(_herdSize * _baseLitersPerCowDay).toStringAsFixed(0)} L/día',
                badgeText: daysAutonomy > 2.5 ? 'Garantizada' : 'Vulnerable',
                badgeColor: daysAutonomy > 2.5
                    ? const Color(0xFF00C853)
                    : const Color(0xFFFF6D00),
                icon: Icons.hourglass_top_rounded,
                progressFactor: (daysAutonomy / 5.0).clamp(0.0, 1.0),
              ),
            ),

            // KPI 3: Water Temperature
            SizedBox(
              width: cardWidth,
              child: _WaterKpiCard(
                title: 'Temp. Promedio Agua',
                value: '${avgTemp.toStringAsFixed(1)}°C',
                subtitle: 'Umbral de estrés: 24.0°C',
                badgeText: avgTemp <= 24.0 ? 'Fresca / Óptima' : 'Caliente / Alerta',
                badgeColor: avgTemp <= 24.0
                    ? const Color(0xFF00897B)
                    : const Color(0xFFFF1744),
                icon: Icons.thermostat_rounded,
                progressFactor: (avgTemp / 35.0).clamp(0.0, 1.0),
              ),
            ),

            // KPI 4: IoT Ultrasonic Sensor Network
            SizedBox(
              width: cardWidth,
              child: _WaterKpiCard(
                title: 'Red de Sensores IoT',
                value: '$troughsCount / $troughsCount Nodos',
                subtitle: 'LoRaWAN SF7 • RSSI -76 dBm',
                badgeText: '100% En Línea',
                badgeColor: const Color(0xFF43A047),
                icon: Icons.sensors_rounded,
                progressFactor: 1.0,
              ),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CONTROLS & FILTER BAR
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildControlsBar(BuildContext context, int totalCount, int lowCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          // Filter Chips
          _FilterChip(
            label: 'Todos ($totalCount)',
            isSelected: _selectedFilter == 'all',
            onTap: () => setState(() => _selectedFilter = 'all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Nivel Óptimo (>50%)',
            isSelected: _selectedFilter == 'optimal',
            onTap: () => setState(() => _selectedFilter = 'optimal'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Nivel Bajo ($lowCount)',
            isSelected: _selectedFilter == 'low',
            badgeColor: lowCount > 0 ? const Color(0xFFFF1744) : null,
            onTap: () => setState(() => _selectedFilter = 'low'),
          ),

          const Spacer(),

          // Search Field
          SizedBox(
            width: 220,
            height: 36,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar tanque o potrero...',
                hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withAlpha(140)),
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: AppTheme.textSecondary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 14),
                        onPressed: () => setState(() => _searchCtrl.clear()),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                filled: true,
                fillColor: AppTheme.surfaceVariant.withAlpha(80),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.divider),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Simulation Button
          OutlinedButton.icon(
            onPressed: () => _showHeatStressSimulationDialog(context),
            icon: const Icon(Icons.calculate_outlined, size: 15),
            label: const Text('Simulador de Estrés'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              side: BorderSide(color: AppTheme.divider),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // LEFT COLUMN: TROUGHS LIST
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildTroughsList(List<TroughReading> troughs) {
    if (troughs.isEmpty) {
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.water_drop_outlined, size: 44, color: AppTheme.textSecondary.withAlpha(90)),
              const SizedBox(height: 12),
              Text(
                'No se encontraron bebederos con este filtro',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Prueba seleccionando "Todos" o borrando la búsqueda.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bebederos y Piletas Monitoreadas (${troughs.length})',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Actualizado vía IoT en tiempo real',
              style: TextStyle(
                fontSize: 11.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // List of Cards
        ...troughs.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TroughCard(
                reading: t,
                onRefill: () {
                  widget.demoService.refillTrough(t.troughId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Llenando "${t.troughName}" al 96% de capacidad.'),
                      backgroundColor: const Color(0xFF0288D1),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                },
                onCalibrate: () => _showCalibrationDialog(context, t),
                onViewHistory: () => _showHistoryDialog(context, t),
              ),
            )),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // RIGHT COLUMN: WATER INTELLIGENCE & DROUGHT PROTOCOLS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildIntelligenceSideColumn({
    required double totalStoredLiters,
    required double dailyHerdDemandLiters,
    required double daysAutonomy,
    required double avgTemp,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Card 1: Calculadora de Demanda y Autonomía Hídrica ────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0288D1).withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.analytics_rounded, size: 16, color: Color(0xFF0288D1)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Autonomía & Demanda del Hato',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Herd Demands breakdown
              _buildDemandRow('Población de Ganado', '$_herdSize cabezas'),
              const SizedBox(height: 8),
              _buildDemandRow('Consumo Promedio/Vaca', '${_baseLitersPerCowDay.toStringAsFixed(0)} L / día'),
              const SizedBox(height: 8),
              _buildDemandRow('Demanda Diaria Total', '${dailyHerdDemandLiters.toStringAsFixed(0)} Lts / 24h'),
              const SizedBox(height: 8),
              _buildDemandRow('Ajuste THI Puerto Peñasco', '+20% por Calor (THI 73)', isWarning: true),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Visual Days Autonomy countdown
              Text(
                'Proyección de Suministro sin Recarga de Pozo:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 10),

              // Visual Step bar for days
              Row(
                children: List.generate(4, (index) {
                  final dayNum = index + 1;
                  final isCovered = daysAutonomy >= dayNum;
                  final isPartial = !isCovered && daysAutonomy > (dayNum - 1);

                  Color stepColor = AppTheme.divider;
                  if (isCovered) {
                    stepColor = const Color(0xFF00C853);
                  } else if (isPartial) {
                    stepColor = const Color(0xFFFFD600);
                  }

                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: stepColor.withAlpha(isCovered ? 25 : 15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: stepColor, width: 1.2),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Día $dayNum',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isCovered
                                  ? const Color(0xFF00C853)
                                  : (isPartial ? const Color(0xFFF59E0B) : AppTheme.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Icon(
                            isCovered ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 13,
                            color: isCovered ? const Color(0xFF00C853) : AppTheme.textSecondary.withAlpha(120),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant.withAlpha(70),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF0288D1)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Con la reserva actual (${totalStoredLiters.toStringAsFixed(0)} L), se recomienda encender la bomba del pozo en 48 hrs.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textPrimary.withAlpha(220),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Card 2: Termorregulación y Calidad del Agua (INIFAP Sonora) ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B).withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.wb_sunny_rounded, size: 16, color: Color(0xFF00897B)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Temperatura de Abrevadero (INIFAP)',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                'En el desierto de Sonora, el ganado reduce su consumo voluntario de agua en un 25% si supera los 24°C, acelerando el estrés calórico:',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 12),

              // Color-coded zones
              _buildTempZoneRow('15°C - 22°C', 'Zona Confort (Óptima hidratación)', const Color(0xFF00C853), isCurrent: avgTemp <= 22.0),
              const SizedBox(height: 6),
              _buildTempZoneRow('23°C - 25°C', 'Zona Alerta (Menor ingesta)', const Color(0xFFF59E0B), isCurrent: avgTemp > 22.0 && avgTemp <= 25.0),
              const SizedBox(height: 6),
              _buildTempZoneRow('> 26°C', 'Zona Crítica (Riesgo de shock calórico)', const Color(0xFFFF1744), isCurrent: avgTemp > 25.0),

              const SizedBox(height: 14),
              // System recommendation pill
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00897B).withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFF00897B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recomendación: Mantener malla sombra del 80% sobre piletas para reducir hasta 4.2°C en el espejo de agua.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Card 3: Protocolo Preventivo de Mantenimiento ─────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.checklist_rounded, size: 16, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Protocolo de Mantenimiento',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _buildChecklistItem('Revisión de flotador y empaque de compuerta', true),
              _buildChecklistItem('Limpieza de algas y sedimentos de fondo', true),
              _buildChecklistItem('Calibración cero sensor ultrasónico JSN-SR04T', true),
              _buildChecklistItem('Prueba mensual de motobomba solar/eléctrica', false),

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reporte de disponibilidad hídrica descargado en PDF.'),
                        backgroundColor: Color(0xFF2E7D32),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('Descargar Bitácora Hídrica PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: AppTheme.divider),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDemandRow(String label, String value, {bool isWarning = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isWarning ? const Color(0xFFFF6D00) : AppTheme.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildTempZoneRow(String range, String desc, Color color, {required bool isCurrent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrent ? color.withAlpha(20) : AppTheme.surfaceVariant.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent ? color : AppTheme.divider.withAlpha(60),
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            range,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              desc,
              style: TextStyle(
                fontSize: 11,
                color: isCurrent ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'ACTUAL',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String title, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isDone ? const Color(0xFF00C853) : AppTheme.textSecondary.withAlpha(120),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                color: isDone ? AppTheme.textPrimary : AppTheme.textSecondary,
                decoration: isDone ? TextDecoration.none : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DIALOGS: ADD TROUGH, CALIBRATION, SIMULATOR
  // ═══════════════════════════════════════════════════════════════════

  void _showAddTroughDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: 'Potrero Este');
    final idCtrl = TextEditingController(text: 'bebedero_03');
    final capCtrl = TextEditingController(text: '6500');
    final depthCtrl = TextEditingController(text: '110');
    String selectedType = 'Tanque Australiano 6,500L';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: AppTheme.divider),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0288D1).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF0288D1), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Registrar Nuevo Bebedero'),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Potrero / Tanque',
                    hintText: 'Ej. Potrero Este',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: idCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Identificador IoT',
                          hintText: 'bebedero_03',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: capCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Capacidad (Litros)',
                          hintText: '6500',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: depthCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Profundidad de Pileta (cm)',
                    hintText: '110',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Tipo de Estructura'),
                  items: const [
                    DropdownMenuItem(value: 'Tanque Nodriza UV 8,000L', child: Text('Tanque Nodriza UV')),
                    DropdownMenuItem(value: 'Pileta Concreto Corral 5,000L', child: Text('Pileta Concreto Corral')),
                    DropdownMenuItem(value: 'Tanque Australiano 6,500L', child: Text('Tanque Australiano')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedType = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final double cap = double.tryParse(capCtrl.text) ?? 6000;
                final double depth = double.tryParse(depthCtrl.text) ?? 100;
                final newTrough = TroughReading(
                  troughId: idCtrl.text.trim(),
                  troughName: nameCtrl.text.trim(),
                  levelPercent: 90.0,
                  distanceCm: (depth * 0.1).clamp(2.0, 30.0),
                  tankDepthCm: depth,
                  capacityLiters: cap,
                  waterTemperature: 21.0,
                  batteryPercent: 95,
                  tankType: selectedType,
                );
                widget.demoService.addOrUpdateTrough(newTrough);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Bebedero "${nameCtrl.text}" registrado con éxito.'),
                    backgroundColor: const Color(0xFF00C853),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCalibrationDialog(BuildContext context, TroughReading reading) {
    double offset = 0.0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: AppTheme.divider),
          ),
          title: Row(
            children: [
              const Icon(Icons.tune_rounded, color: Color(0xFF0288D1)),
              const SizedBox(width: 10),
              Text('Calibrar Sensor: ${reading.troughName}'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajuste de distancia offset del transductor ultrasónico JSN-SR04T.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Offset de altura:'),
                  Text(
                    '${offset > 0 ? '+' : ''}${offset.toStringAsFixed(1)} cm',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Slider(
                value: offset,
                min: -15.0,
                max: 15.0,
                divisions: 30,
                activeColor: const Color(0xFF0288D1),
                onChanged: (val) => setDialogState(() => offset = val),
              ),
              const SizedBox(height: 8),
              Text(
                'Distancia estimada resultante: ${(reading.distanceCm + offset).clamp(2.0, reading.tankDepthCm).toStringAsFixed(1)} cm',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                widget.demoService.calibrateTrough(reading.troughId, offset);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calibración de sensor aplicada.')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0288D1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Aplicar Calibración'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHeatStressSimulationDialog(BuildContext context) {
    double simTemp = 36.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Dynamic calculation based on temperature
          // Cattle drink 60L at 25C, up to 105L at 42C
          final litersPerCow = 60.0 + ((simTemp - 25.0).clamp(0.0, 20.0) * 2.5);
          final totalDailyLiters = _herdSize * litersPerCow;
          final currentStored = widget.demoService.troughReadings.values
              .fold(0.0, (acc, t) => acc + t.currentVolumeLiters);
          final simAutonomy = currentStored / totalDailyLiters;

          return AlertDialog(
            backgroundColor: AppTheme.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: AppTheme.divider),
            ),
            title: Row(
              children: [
                const Icon(Icons.wb_sunny_rounded, color: Color(0xFFFF6D00)),
                const SizedBox(width: 10),
                const Text('Simulador de Estrés Térmico & Consumo'),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modela cómo la temperatura extrema en Puerto Peñasco eleva la demanda de agua del hato y reduce la autonomía de los tanques:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Temperatura Ambiente Simulada:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '${simTemp.toStringAsFixed(0)}°C',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: simTemp > 38 ? const Color(0xFFFF1744) : const Color(0xFFFF6D00),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: simTemp,
                    min: 25.0,
                    max: 45.0,
                    divisions: 20,
                    activeColor: simTemp > 38 ? const Color(0xFFFF1744) : const Color(0xFFFF6D00),
                    onChanged: (val) => setDialogState(() => simTemp = val),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant.withAlpha(80),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      children: [
                        _buildDemandRow('Demanda por Cabeza:', '${litersPerCow.toStringAsFixed(0)} Litros / día'),
                        const SizedBox(height: 6),
                        _buildDemandRow('Demanda Total del Hato:', '${totalDailyLiters.toStringAsFixed(0)} Litros / día'),
                        const SizedBox(height: 6),
                        _buildDemandRow(
                          'Autonomía de Reserva:',
                          '${simAutonomy.toStringAsFixed(1)} Días',
                          isWarning: simAutonomy < 2.5,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showHistoryDialog(BuildContext context, TroughReading reading) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppTheme.divider),
        ),
        title: Row(
          children: [
            const Icon(Icons.history_rounded, color: Color(0xFF0288D1)),
            const SizedBox(width: 10),
            Text('Historial de Consumo: ${reading.troughName}'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Registro de las últimas 24 horas (Lecturas cada 30 min):',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              // Mini Table of recent readings
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  children: [
                    _historyRow('14:00 hrs', '${reading.levelPercent.toStringAsFixed(0)}%', 'Normal', const Color(0xFF00C853)),
                    _historyRow('12:00 hrs', '${(reading.levelPercent + 3).clamp(0, 100).toStringAsFixed(0)}%', 'Abrevadero activo', const Color(0xFF0288D1)),
                    _historyRow('10:00 hrs', '${(reading.levelPercent + 5).clamp(0, 100).toStringAsFixed(0)}%', 'Abrevadero activo', const Color(0xFF0288D1)),
                    _historyRow('08:00 hrs', '98%', 'Rebombeo completo', const Color(0xFF00C853)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _historyRow(String time, String level, String note, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text(level, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
          Text(note, style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SUPPORTING COMPONENTS
// ═══════════════════════════════════════════════════════════════════

class _WaterKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final double progressFactor;

  const _WaterKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.progressFactor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title + Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: badgeColor),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Value + Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withAlpha(60)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Subtitle
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // Mini progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  color: AppTheme.surfaceVariant,
                ),
                FractionallySizedBox(
                  widthFactor: progressFactor,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(4),
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
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (badgeColor ?? const Color(0xFF0288D1)).withAlpha(25)
              : AppTheme.surfaceVariant.withAlpha(60),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (badgeColor ?? const Color(0xFF0288D1))
                : AppTheme.divider,
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (badgeColor ?? const Color(0xFF0288D1))
                : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
