import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/app_theme.dart';
import '../models/ranch_models.dart';
import '../services/ranch_api_service.dart';
import '../widgets/crud_dialogs.dart';

/// Weight tracking screen with interactive animal selection and editing.
class PesoScreen extends StatefulWidget {
  const PesoScreen({super.key});

  @override
  State<PesoScreen> createState() => _PesoScreenState();
}

class _PesoScreenState extends State<PesoScreen> {
  List<WeightRecord> _records = [];
  bool _isLoading = true;
  int? _selectedAnimalId;

  static final _demoRecords = [
    WeightRecord(id: 1, animalId: 1, weightKg: 420, bodyConditionScore: 6,
        notes: 'Condición normal', recordedAt: DateTime.now().subtract(const Duration(days: 0))),
    WeightRecord(id: 2, animalId: 1, weightKg: 415, bodyConditionScore: 6,
        recordedAt: DateTime.now().subtract(const Duration(days: 30))),
    WeightRecord(id: 3, animalId: 1, weightKg: 408, bodyConditionScore: 5,
        recordedAt: DateTime.now().subtract(const Duration(days: 60))),
    WeightRecord(id: 4, animalId: 1, weightKg: 395, bodyConditionScore: 5,
        recordedAt: DateTime.now().subtract(const Duration(days: 90))),
    WeightRecord(id: 5, animalId: 2, weightKg: 380, bodyConditionScore: 5,
        recordedAt: DateTime.now().subtract(const Duration(days: 0))),
    WeightRecord(id: 6, animalId: 2, weightKg: 372, bodyConditionScore: 5,
        recordedAt: DateTime.now().subtract(const Duration(days: 30))),
    WeightRecord(id: 7, animalId: 3, weightKg: 350, bodyConditionScore: 7,
        recordedAt: DateTime.now().subtract(const Duration(days: 0))),
    WeightRecord(id: 8, animalId: 4, weightKg: 450, bodyConditionScore: 6,
        recordedAt: DateTime.now().subtract(const Duration(days: 0))),
    WeightRecord(id: 9, animalId: 5, weightKg: 400, bodyConditionScore: 6,
        recordedAt: DateTime.now().subtract(const Duration(days: 0))),
  ];

  static const _animalNames = {
    1: 'Lupita', 2: 'Estrella', 3: 'Canela', 4: 'Luna', 5: 'Valentina',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final records = await RanchApiService.getWeightRecords();
      if (!mounted) return;
      setState(() { _records = records; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _records = _demoRecords; _isLoading = false; });
    }
  }

  Future<void> _openWeightDialog({int? animalId}) async {
    final saved = await showAddWeightDialog(context, animalId: animalId);
    if (!mounted) return;
    if (saved == true) {
      await _loadData();
      if (!mounted) return;
      if (animalId != null) {
        setState(() => _selectedAnimalId = animalId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Peso registrado y actualizado exitosamente'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestByAnimal = <int, WeightRecord>{};
    for (final r in _records) {
      if (!latestByAnimal.containsKey(r.animalId) ||
          (r.recordedAt ?? DateTime(2000)).isAfter(latestByAnimal[r.animalId]!.recordedAt ?? DateTime(2000))) {
        latestByAnimal[r.animalId] = r;
      }
    }

    final avgWeight = latestByAnimal.values.isEmpty
        ? 0.0
        : latestByAnimal.values.map((r) => r.weightKg).reduce((a, b) => a + b) / latestByAnimal.values.length;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Stats strip
          _buildStatsRow(latestByAnimal, avgWeight),
          const SizedBox(height: 12),

          // Stacked layout: chart on top, table below
          _buildWeightChart(),
          const SizedBox(height: 12),
          _buildLatestWeights(latestByAnimal),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Map<int, WeightRecord> latestByAnimal, double avgWeight) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatColumn(icon: Icons.monitor_weight_rounded, label: 'Pesados', value: '${latestByAnimal.length}'),
          _StatColumn(icon: Icons.bar_chart_rounded, label: 'Promedio', value: '${avgWeight.toStringAsFixed(0)} kg'),
          _StatColumn(icon: Icons.analytics_rounded, label: 'Registros', value: '${_records.length}'),
        ],
      ),
    );
  }

  Widget _buildWeightChart() {
    if (_selectedAnimalId == null) {
      return Container(
        height: 180,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.touch_app_rounded, size: 28, color: AppTheme.primary),
              ),
              const SizedBox(height: 10),
              Text(
                'Seleccione una vaca para ver su gráfica de peso',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Toca cualquier fila en la lista de abajo para consultar su curva de crecimiento.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final animalId = _selectedAnimalId!;
    final animalName = _animalNames[animalId] ?? 'Animal #$animalId';
    final animalRecords = _records.where((r) => r.animalId == animalId).toList()
      ..sort((a, b) => (a.recordedAt ?? DateTime.now()).compareTo(b.recordedAt ?? DateTime.now()));

    if (animalRecords.length < 2) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.show_chart_rounded, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text('Curva de Peso — $animalName',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openWeightDialog(animalId: animalId),
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('Nuevo pesaje', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Icon(Icons.show_chart_rounded, size: 32, color: AppTheme.textSecondary.withAlpha(80)),
            const SizedBox(height: 8),
            Text('Solo se cuenta con 1 pesaje registrado para $animalName (${animalRecords.first.weightKg.toStringAsFixed(0)} kg).',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text('Agrega más registros para trazar la curva de evolución.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            const SizedBox(height: 12),
          ],
        ),
      );
    }

    final spots = animalRecords.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.weightKg);
    }).toList();

    final minW = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 10;
    final maxW = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 10;

    final firstW = animalRecords.first.weightKg;
    final lastW = animalRecords.last.weightKg;
    final daysDiff = (animalRecords.last.recordedAt ?? DateTime.now())
        .difference(animalRecords.first.recordedAt ?? DateTime.now()).inDays;
    final gdp = daysDiff > 0 ? (lastW - firstW) / daysDiff : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text('Curva de Peso — $animalName',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: gdp >= 0 ? AppTheme.primary.withAlpha(15) : AppTheme.thiDanger.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(gdp >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 12, color: gdp >= 0 ? AppTheme.primary : AppTheme.thiDanger),
                    const SizedBox(width: 3),
                    Text(
                      'GDP: ${gdp >= 0 ? '+' : ''}${(gdp * 1000).toStringAsFixed(0)}g/día',
                      style: TextStyle(
                        color: gdp >= 0 ? AppTheme.primary : AppTheme.thiDanger,
                        fontSize: 10, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                color: AppTheme.primary,
                tooltip: 'Registrar nuevo peso',
                onPressed: () => _openWeightDialog(animalId: animalId),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minW,
                maxY: maxW,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) => FlLine(color: AppTheme.divider, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= animalRecords.length) return const SizedBox.shrink();
                        final dt = animalRecords[idx].recordedAt;
                        if (dt == null) return const SizedBox.shrink();
                        return Text('${dt.day}/${dt.month}',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 9));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 9));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(radius: 3, color: AppTheme.primary,
                              strokeWidth: 1.5, strokeColor: Colors.white),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primary.withAlpha(15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestWeights(Map<int, WeightRecord> latestByAnimal) {
    final sorted = latestByAnimal.entries.toList()
      ..sort((a, b) => b.value.weightKg.compareTo(a.value.weightKg));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.format_list_numbered_rounded, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text('Últimos Pesajes Registrados', style: TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _openWeightDialog(),
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('Registrar Peso', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.divider),
          ...sorted.map((entry) {
            final animalId = entry.key;
            final record = entry.value;
            final name = _animalNames[animalId] ?? 'Animal $animalId';
            final bcs = record.bodyConditionScore;
            final isSelected = _selectedAnimalId == animalId;

            return InkWell(
              onTap: () {
                setState(() => _selectedAnimalId = animalId);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary.withAlpha(20) : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(color: AppTheme.divider.withAlpha(80)),
                    left: isSelected ? const BorderSide(color: AppTheme.primary, width: 3) : BorderSide.none,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : AppTheme.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          record.weightKg.toStringAsFixed(0),
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Viendo gráfica', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text('${record.weightKg.toStringAsFixed(1)} kg',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                              if (bcs != null) ...[
                                const SizedBox(width: 8),
                                _buildBcsIndicator(bcs),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (record.recordedAt != null)
                      Text('${record.recordedAt!.day}/${record.recordedAt!.month}',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: AppTheme.primary,
                      tooltip: 'Editar o registrar peso',
                      onPressed: () => _openWeightDialog(animalId: animalId),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBcsIndicator(int bcs) {
    final color = bcs <= 3
        ? AppTheme.thiDanger
        : bcs <= 5
            ? AppTheme.thiAlert
            : bcs <= 7
                ? AppTheme.primary
                : AppTheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('CC $bcs/9',
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String label, value;

  const _StatColumn({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        Text(label, style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
      ],
    );
  }
}
