import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/sensor_reading.dart';
import '../services/demo_service.dart';
import '../widgets/animal_card.dart';
import 'animal_detail_screen.dart';

/// THI Monitor Dashboard — Full thermal comfort console with herd analytics,
/// USDA/INIFAP stress scale reference, real-time filters, and responsive layout.
class DashboardScreen extends StatefulWidget {
  final DemoService demoService;

  const DashboardScreen({super.key, required this.demoService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedFilter = 'all'; // 'all', 'normal', 'alert', 'danger', 'emergency'
  String _searchQuery = '';
  bool _isTableView = false;
  String? _selectedDeviceId;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedDeviceId != null) {
      return AnimalDetailScreen(
        deviceId: _selectedDeviceId!,
        demoService: widget.demoService,
        embedded: true,
        onBack: () => setState(() => _selectedDeviceId = null),
      );
    }

    return ListenableBuilder(
      listenable: widget.demoService,
      builder: (context, _) {
        final readings = widget.demoService.latestReadings;
        final animals = readings.values.toList();

        // Sort: emergencies and highest THI first
        animals.sort((a, b) {
          const order = {
            'emergency': 0,
            'danger': 1,
            'alert': 2,
            'normal': 3,
          };
          final comp = (order[a.thiLevel] ?? 4).compareTo(order[b.thiLevel] ?? 4);
          if (comp != 0) return comp;
          return b.thi.compareTo(a.thi);
        });

        // Calculate stats
        final counts = {
          'normal': 0,
          'alert': 0,
          'danger': 0,
          'emergency': 0,
        };
        double totalThi = 0;
        double totalTemp = 0;
        double totalHum = 0;
        double totalBat = 0;

        for (final a in animals) {
          counts[a.thiLevel] = (counts[a.thiLevel] ?? 0) + 1;
          totalThi += a.thi;
          totalTemp += a.ambientTemp;
          totalHum += a.humidity;
          totalBat += a.batteryPercent;
        }

        final avgThi = animals.isNotEmpty ? totalThi / animals.length : 71.4;
        final avgTemp = animals.isNotEmpty ? totalTemp / animals.length : 25.0;
        final avgHum = animals.isNotEmpty ? totalHum / animals.length : 40.0;
        final avgBattery = animals.isNotEmpty ? totalBat / animals.length : 90.0;

        String overallLevel = 'normal';
        if (avgThi >= 89) {
          overallLevel = 'emergency';
        } else if (avgThi >= 79) {
          overallLevel = 'danger';
        } else if (avgThi >= 72) {
          overallLevel = 'alert';
        }

        // Apply filters & search
        final filteredAnimals = animals.where((a) {
          if (_selectedFilter != 'all' && a.thiLevel != _selectedFilter) {
            return false;
          }
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            final nameMatch = a.animalName.toLowerCase().contains(query);
            final deviceMatch = a.deviceId.toLowerCase().contains(query);
            return nameMatch || deviceMatch;
          }
          return true;
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Herd Thermal Welfare Hero Card
              _buildHerdSummaryCard(
                avgThi: avgThi,
                overallLevel: overallLevel,
                avgTemp: avgTemp,
                avgHum: avgHum,
                totalAnimals: animals.length,
                counts: counts,
                isConnected: widget.demoService.isRunning,
              ),
              const SizedBox(height: 16),

              // 2. Toolbar (Filter chips + Search + View switch)
              _buildToolbar(animals.length, counts),
              const SizedBox(height: 16),

              // 3. Responsive Main Grid & Guide Panel
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 980;

                  if (!isWide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAnimalsSection(filteredAnimals),
                        const SizedBox(height: 20),
                        _buildThiGuidePanel(
                          avgBattery: avgBattery,
                          collarCount: animals.length,
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column (70%) — Animal Cards Grid or Table
                      Expanded(
                        flex: 7,
                        child: _buildAnimalsSection(filteredAnimals),
                      ),
                      const SizedBox(width: 18),

                      // Right Column (30%) — THI Scale Guide & Field Telemetry Console
                      Expanded(
                        flex: 3,
                        child: _buildThiGuidePanel(
                          avgBattery: avgBattery,
                          collarCount: animals.length,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 1. TOP HERD THERMAL WELFARE HERO CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHerdSummaryCard({
    required double avgThi,
    required String overallLevel,
    required double avgTemp,
    required double avgHum,
    required int totalAnimals,
    required Map<String, int> counts,
    required bool isConnected,
  }) {
    final color = AppTheme.thiColor(overallLevel);

    String advisory = 'Condiciones confortables para el ganado. '
        'Sin riesgo de caída en producción lechera ni ganancia de peso.';
    if (overallLevel == 'alert') {
      advisory = 'Estrés térmico moderado en el hato. Asegurar sombra abundante y flujo constante de agua fresca.';
    } else if (overallLevel == 'danger' || overallLevel == 'emergency') {
      advisory = '¡Alerta de estrés calórico severo! Activar aspersores y ventilación en corrales de manejo.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // THI Badge Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withAlpha(80)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      avgThi.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: -0.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'THI PROMEDIO',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Title and Ambient Telemetry
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Confort Térmico del Hato',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withAlpha(80)),
                          ),
                          child: Text(
                            AppTheme.thiLabel(overallLevel).toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _AmbientPill(
                          icon: Icons.wb_sunny_rounded,
                          text: '${avgTemp.toStringAsFixed(1)}°C Ambiente',
                        ),
                        _AmbientPill(
                          icon: Icons.water_drop_rounded,
                          text: '${avgHum.toStringAsFixed(0)}% Humedad',
                        ),
                        _AmbientPill(
                          icon: Icons.location_on_rounded,
                          text: 'Rancho Puerto Peñasco, Sonora',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // IoT Connection Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isConnected
                      ? AppTheme.thiNormal.withAlpha(20)
                      : AppTheme.thiEmergency.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isConnected
                        ? AppTheme.thiNormal.withAlpha(70)
                        : AppTheme.thiEmergency.withAlpha(70),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected
                            ? AppTheme.thiNormal
                            : AppTheme.thiEmergency,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? 'ESP32 En Línea' : 'Desconectado',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isConnected
                            ? AppTheme.thiNormal
                            : AppTheme.thiEmergency,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stress Distribution Row
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    _DistributionSegment(
                      label: 'Normal (<72)',
                      count: counts['normal'] ?? 0,
                      total: totalAnimals,
                      color: AppTheme.thiNormal,
                      isSelected: _selectedFilter == 'normal',
                      onTap: () => setState(() {
                        _selectedFilter =
                            _selectedFilter == 'normal' ? 'all' : 'normal';
                      }),
                    ),
                    const SizedBox(width: 8),
                    _DistributionSegment(
                      label: 'Alerta (72-78)',
                      count: counts['alert'] ?? 0,
                      total: totalAnimals,
                      color: AppTheme.thiAlert,
                      isSelected: _selectedFilter == 'alert',
                      onTap: () => setState(() {
                        _selectedFilter =
                            _selectedFilter == 'alert' ? 'all' : 'alert';
                      }),
                    ),
                    const SizedBox(width: 8),
                    _DistributionSegment(
                      label: 'Peligro (79-88)',
                      count: counts['danger'] ?? 0,
                      total: totalAnimals,
                      color: AppTheme.thiDanger,
                      isSelected: _selectedFilter == 'danger',
                      onTap: () => setState(() {
                        _selectedFilter =
                            _selectedFilter == 'danger' ? 'all' : 'danger';
                      }),
                    ),
                    const SizedBox(width: 8),
                    _DistributionSegment(
                      label: 'Emergencia (>88)',
                      count: counts['emergency'] ?? 0,
                      total: totalAnimals,
                      color: AppTheme.thiEmergency,
                      isSelected: _selectedFilter == 'emergency',
                      onTap: () => setState(() {
                        _selectedFilter =
                            _selectedFilter == 'emergency' ? 'all' : 'emergency';
                      }),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Technical Recommendation
          Row(
            children: [
              Icon(Icons.tips_and_updates_rounded, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  advisory,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 2. TOOLBAR (FILTERS, SEARCH & VIEW SWITCHER)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildToolbar(int totalCount, Map<String, int> counts) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;

        final filterChips = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'Todos ($totalCount)',
                selected: _selectedFilter == 'all',
                color: AppTheme.primary,
                onSelected: () => setState(() => _selectedFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Normal (${counts['normal'] ?? 0})',
                selected: _selectedFilter == 'normal',
                color: AppTheme.thiNormal,
                onSelected: () => setState(() => _selectedFilter = 'normal'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Alerta (${counts['alert'] ?? 0})',
                selected: _selectedFilter == 'alert',
                color: AppTheme.thiAlert,
                onSelected: () => setState(() => _selectedFilter = 'alert'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Peligro (${counts['danger'] ?? 0})',
                selected: _selectedFilter == 'danger',
                color: AppTheme.thiDanger,
                onSelected: () => setState(() => _selectedFilter = 'danger'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Emergencia (${counts['emergency'] ?? 0})',
                selected: _selectedFilter == 'emergency',
                color: AppTheme.thiEmergency,
                onSelected: () => setState(() => _selectedFilter = 'emergency'),
              ),
            ],
          ),
        );

        final searchAndViews = Row(
          children: [
            // Search Input
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar por arete, collar o nombre...',
                    hintStyle: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary.withAlpha(140)),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 16, color: AppTheme.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 14),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    filled: true,
                    fillColor: AppTheme.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // View Mode Toggle (Grid vs Table)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.grid_view_rounded,
                      size: 18,
                      color: !_isTableView
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                    tooltip: 'Vista Cuadrícula',
                    onPressed: () => setState(() => _isTableView = false),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.table_rows_rounded,
                      size: 18,
                      color: _isTableView
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                    tooltip: 'Vista Tabla',
                    onPressed: () => setState(() => _isTableView = true),
                  ),
                ],
              ),
            ),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              filterChips,
              const SizedBox(height: 10),
              searchAndViews,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: filterChips),
            const SizedBox(width: 16),
            SizedBox(width: 380, child: searchAndViews),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 3. ANIMALS SECTION (GRID OR TABLE)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAnimalsSection(List<SensorReading> animals) {
    if (animals.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off_rounded,
                size: 40, color: AppTheme.textSecondary.withAlpha(120)),
            const SizedBox(height: 12),
            Text(
              'No hay bovinos que coincidan con el filtro',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Prueba seleccionando otro nivel de estrés o limpiando la búsqueda.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _searchCtrl.clear();
                setState(() {
                  _selectedFilter = 'all';
                  _searchQuery = '';
                });
              },
              child: const Text('Restablecer Filtros'),
            ),
          ],
        ),
      );
    }

    if (_isTableView) {
      return _buildTableView(animals);
    }

    // Grid View
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 310,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 375,
          ),
          itemCount: animals.length,
          itemBuilder: (context, index) {
            final animal = animals[index];
            return AnimalCard(
              reading: animal,
              hasEstrusAlert: widget.demoService.activeEstrusAlerts
                  .containsKey(animal.deviceId),
              healthAlertType: widget.demoService
                  .activeHealthAlerts[animal.deviceId]?.type,
              onTap: () {
                setState(() => _selectedDeviceId = animal.deviceId);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTableView(List<SensorReading> animals) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppTheme.surfaceVariant),
            dataRowMaxHeight: 52,
            columns: const [
              DataColumn(label: Text('Bovino / Arete')),
              DataColumn(label: Text('Collar IoT')),
              DataColumn(label: Text('THI')),
              DataColumn(label: Text('Nivel Confort')),
              DataColumn(label: Text('T. Ambiente')),
              DataColumn(label: Text('Humedad')),
              DataColumn(label: Text('Batería')),
              DataColumn(label: Text('Actividad')),
              DataColumn(label: Text('Acción')),
            ],
            rows: animals.map((a) {
              final color = AppTheme.thiColor(a.thiLevel);
              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pets_rounded, size: 16, color: color),
                        const SizedBox(width: 8),
                        Text(
                          a.animalName.isNotEmpty ? a.animalName : a.deviceId,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      a.deviceId,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      a.thi.toStringAsFixed(1),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppTheme.thiLabel(a.thiLevel),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text('${a.ambientTemp.toStringAsFixed(1)}°C')),
                  DataCell(Text('${a.humidity.toStringAsFixed(0)}%')),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          a.batteryPercent > 50
                              ? Icons.battery_full_rounded
                              : Icons.battery_alert_rounded,
                          size: 14,
                          color: a.batteryPercent > 20
                              ? AppTheme.textSecondary
                              : AppTheme.thiDanger,
                        ),
                        const SizedBox(width: 4),
                        Text('${a.batteryPercent.round()}%'),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(a.movementIntensity <= 1 ? 'Reposo' : 'Activo'),
                  ),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      tooltip: 'Ver telemetría detallada',
                      onPressed: () {
                        setState(() => _selectedDeviceId = a.deviceId);
                      },
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 4. THI GUIDE PANEL & FIELD TELEMETRY CONSOLE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildThiGuidePanel({
    required double avgBattery,
    required int collarCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // THI Official Scale Card
        Container(
          padding: const EdgeInsets.all(18),
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
                  Icon(Icons.menu_book_rounded,
                      size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Escala Oficial de THI (INIFAP / USDA)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _ScaleLevelRow(
                color: AppTheme.thiNormal,
                range: '< 72 THI',
                title: 'Zona de Confort',
                desc: 'Sin estrés térmico. Rumiación, consumo y producción óptimos.',
              ),
              const SizedBox(height: 10),
              _ScaleLevelRow(
                color: AppTheme.thiAlert,
                range: '72 – 78 THI',
                title: 'Alerta / Estrés Leve',
                desc: 'Aumento de respiración y búsqueda de sombra. Consumo +20% agua.',
              ),
              const SizedBox(height: 10),
              _ScaleLevelRow(
                color: AppTheme.thiDanger,
                range: '79 – 88 THI',
                title: 'Peligro / Estrés Severo',
                desc: 'Jadeo continuo con boca abierta. Caída de ingesta y fertilidad.',
              ),
              const SizedBox(height: 10),
              _ScaleLevelRow(
                color: AppTheme.thiEmergency,
                range: '> 88 THI',
                title: 'Emergencia Crítica',
                desc: 'Riesgo inminente de mortalidad. Requiere aspersión y enfriamiento forzado.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Action Protocol in Sonora
        Container(
          padding: const EdgeInsets.all(18),
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
                  Icon(Icons.shield_rounded, size: 16, color: AppTheme.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'Protocolo de Manejo en Sonora',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _ProtocolItem(
                number: '1',
                text: 'Sombra per cápita garantizada: mínimo 4.5 m² de malla-sombra al 80%.',
              ),
              const SizedBox(height: 8),
              _ProtocolItem(
                number: '2',
                text: 'Bebederos a temperatura fresca (< 22°C) con caudal mínimo 20 L/min.',
              ),
              const SizedBox(height: 8),
              _ProtocolItem(
                number: '3',
                text: 'Evitar arreos o manejos en manga durante las horas de radiación pico (11:00 - 16:00).',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // IoT Collar Telemetry Status
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sensors_rounded, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Telemetría de Campo ESP32',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Collares enlazados:',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  Text('$collarCount activos',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Batería promedio:',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  Text('${avgBattery.round()}% (Óptima)',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.thiNormal)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Frecuencia de muestreo:',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  Text('Cada 5 segundos',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SUBCOMPONENTS
// ═══════════════════════════════════════════════════════════════

class _AmbientPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _AmbientPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DistributionSegment extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _DistributionSegment({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).round() : 0;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withAlpha(35)
                : count > 0
                    ? color.withAlpha(15)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? color
                  : count > 0
                      ? color.withAlpha(70)
                      : AppTheme.divider,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: count > 0 ? color : AppTheme.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: count > 0 ? color : AppTheme.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(25) : AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : AppTheme.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaleLevelRow extends StatelessWidget {
  final Color color;
  final String range;
  final String title;
  final String desc;

  const _ScaleLevelRow({
    required this.color,
    required this.range,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '($range)',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppTheme.textSecondary,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProtocolItem extends StatelessWidget {
  final String number;
  final String text;

  const _ProtocolItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.secondary.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppTheme.secondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
