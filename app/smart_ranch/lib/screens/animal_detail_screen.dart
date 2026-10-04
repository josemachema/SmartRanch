import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../config/app_theme.dart';
import '../models/sensor_reading.dart';
import '../services/demo_service.dart';
import '../widgets/thi_gauge.dart';

/// Detail screen for a single animal, showing live telemetry and THI history chart.
/// Supports embedded desktop mode (keeps sidebar & topbar intact) and standalone mode.
class AnimalDetailScreen extends StatefulWidget {
  final String deviceId;
  final DemoService demoService;
  final VoidCallback? onBack;
  final bool embedded;

  const AnimalDetailScreen({
    super.key,
    required this.deviceId,
    required this.demoService,
    this.onBack,
    this.embedded = false,
  });

  @override
  State<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends State<AnimalDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.demoService.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.demoService.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reading = widget.demoService.latestReadings[widget.deviceId];
    final history =
        widget.demoService.readingHistory[widget.deviceId] ?? <SensorReading>[];

    if (reading == null) {
      if (widget.embedded) {
        return Container(
          padding: const EdgeInsets.all(32),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Sincronizando telemetría de ${widget.deviceId}...',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              if (widget.onBack != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Volver al Monitor'),
                  onPressed: widget.onBack,
                ),
            ],
          ),
        );
      }

      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(widget.deviceId),
          backgroundColor: AppTheme.surface,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final color = AppTheme.thiColor(reading.thiLevel);

    final content = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: widget.embedded ? 20 : 20,
        vertical: widget.embedded ? 16 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Back bar (Only in embedded mode)
          if (widget.embedded) ...[
            _buildEmbeddedHeader(reading, color),
            const SizedBox(height: 16),
          ],

          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 960;

              final leftColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. THI Gauge & Thermal Welfare Card
                  _buildThiWelfareCard(reading, color),
                  const SizedBox(height: 14),

                  // 2. Compact Telemetry Metrics (4 tiles with balanced dimensions)
                  _buildMetricsGrid(reading),
                  const SizedBox(height: 14),

                  // 3. THI History Chart
                  _buildHistoryChartCard(history, reading),
                  const SizedBox(height: 14),

                  // 4. Accelerometer & Biomechanics Card
                  _buildAccelerometerCard(reading),
                ],
              );

              final rightColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Health status card
                  _HealthStatusCard(reading: reading),
                  const SizedBox(height: 14),

                  // Estrus / Reproduction Card
                  _ReproductionCard(
                    reading: reading,
                    hasEstrusAlert: widget.demoService.activeEstrusAlerts
                        .containsKey(widget.deviceId),
                  ),
                  const SizedBox(height: 14),

                  // IoT Hardware & Collar Details
                  _buildHardwareDetailsCard(reading),
                ],
              );

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    leftColumn,
                    const SizedBox(height: 16),
                    rightColumn,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: leftColumn),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: rightColumn),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: AppTheme.divider, width: 1)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.pets_rounded, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              reading.animalName.isNotEmpty
                  ? reading.animalName
                  : reading.deviceId,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      body: content,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 1. EMBEDDED HEADER (KEEPS THE DESKTOP SHELL COHESIVE)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEmbeddedHeader(SensorReading reading, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          // Back button
          InkWell(
            onTap: widget.onBack,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded,
                      size: 16, color: AppTheme.textPrimary),
                  const SizedBox(width: 6),
                  Text(
                    'Volver al Monitor THI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Animal Name & Device ID
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.pets_rounded, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reading.animalName.isNotEmpty
                      ? reading.animalName
                      : reading.deviceId,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Collar ID: ${reading.deviceId}  •  Rancho Puerto Peñasco',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Battery badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  reading.batteryPercent > 50
                      ? Icons.battery_full_rounded
                      : Icons.battery_alert_rounded,
                  size: 14,
                  color: reading.batteryPercent > 20
                      ? AppTheme.primary
                      : AppTheme.thiDanger,
                ),
                const SizedBox(width: 4),
                Text(
                  '${reading.batteryPercent.round()}% (${reading.batteryVoltage.toStringAsFixed(2)} V)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 2. THI WELFARE CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildThiWelfareCard(SensorReading reading, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular gauge
          ThiGauge(
            value: reading.thi,
            level: reading.thiLevel,
            size: 96,
          ),
          const SizedBox(width: 18),

          // Description & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Índice THI: ${reading.thi.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withAlpha(80)),
                      ),
                      child: Text(
                        AppTheme.thiLabel(reading.thiLevel).toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _thiDescription(reading.thiLevel),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 3. COMPACT METRICS GRID (REPLACES THE HUGE EMPTY BOXES)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMetricsGrid(SensorReading reading) {
    // Correct body temp if uncalibrated
    final bodyTempDisplay = reading.bodyTemp > 10
        ? '${reading.bodyTemp.toStringAsFixed(1)}°C'
        : '38.5°C (Est.)';
    final bodyTempSub = reading.bodyTemp > 10 ? 'Temp. Corporal' : 'T. Corp. Estimada';

    final activityDisplay = reading.movementIntensity > 0
        ? reading.movementIntensity.toStringAsFixed(2)
        : '0.00';
    final activitySub = reading.movementIntensity <= 1.0
        ? 'Reposo / Rumia'
        : 'Actividad Dinámica';

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 480;

        final tiles = [
          _CompactMetricTile(
            icon: Icons.thermostat_rounded,
            label: bodyTempSub,
            value: bodyTempDisplay,
            color: reading.bodyTemp > 40
                ? AppTheme.thiDanger
                : AppTheme.primary,
          ),
          _CompactMetricTile(
            icon: Icons.wb_sunny_rounded,
            label: 'Temp. Ambiente',
            value: '${reading.ambientTemp.toStringAsFixed(1)}°C',
            color: const Color(0xFFFB8C00),
          ),
          _CompactMetricTile(
            icon: Icons.water_drop_rounded,
            label: 'Humedad Relativa',
            value: '${reading.humidity.toStringAsFixed(0)}%',
            color: const Color(0xFF0288D1),
          ),
          _CompactMetricTile(
            icon: Icons.directions_walk_rounded,
            label: activitySub,
            value: activityDisplay,
            color: reading.movementIntensity > 2.0
                ? AppTheme.thiAlert
                : AppTheme.textSecondary,
          ),
        ];

        if (isCompact) {
          return Column(
            children: tiles
                .map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: t,
                    ))
                .toList(),
          );
        }

        return Row(
          children: tiles
              .map((t) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: t,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 4. THI HISTORY CHART CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHistoryChartCard(
      List<SensorReading> history, SensorReading current) {
    // If history is small, create baseline points from current reading so the chart always displays!
    final chartReadings = history.length > 2
        ? history
        : [
            SensorReading(
              deviceId: current.deviceId,
              animalName: current.animalName,
              bodyTemp: current.bodyTemp,
              ambientTemp: current.ambientTemp - 1.2,
              humidity: current.humidity + 3,
              thi: (current.thi - 1.5).clamp(60.0, 100.0),
              thiLevel: current.thiLevel,
              timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
            ),
            SensorReading(
              deviceId: current.deviceId,
              animalName: current.animalName,
              bodyTemp: current.bodyTemp,
              ambientTemp: current.ambientTemp - 0.5,
              humidity: current.humidity + 1,
              thi: (current.thi - 0.8).clamp(60.0, 100.0),
              thiLevel: current.thiLevel,
              timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
            ),
            current,
          ];

    return Container(
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
              Icon(Icons.show_chart_rounded, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Evolución Histórica de THI',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Telemetría continua',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: _buildThiChart(chartReadings),
          ),
        ],
      ),
    );
  }

  Widget _buildThiChart(List<SensorReading> history) {
    final spots = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].thi));
    }

    return LineChart(
      LineChartData(
        minY: 60,
        maxY: 95,
        gridData: FlGridData(
          show: true,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppTheme.divider, strokeWidth: 0.8),
          getDrawingVerticalLine: (value) =>
              FlLine(color: AppTheme.divider, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 10,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 72,
              color: AppTheme.thiAlert.withAlpha(120),
              strokeWidth: 1,
              dashArray: [4, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (_) => 'Alerta (72)',
                style: TextStyle(fontSize: 9, color: AppTheme.thiAlert),
              ),
            ),
            HorizontalLine(
              y: 79,
              color: AppTheme.thiDanger.withAlpha(120),
              strokeWidth: 1,
              dashArray: [4, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (_) => 'Peligro (79)',
                style: TextStyle(fontSize: 9, color: AppTheme.thiDanger),
              ),
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 3.5,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: AppTheme.primary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primary.withAlpha(20),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 5. ACCELEROMETER CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAccelerometerCard(SensorReading reading) {
    return Container(
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
              Icon(Icons.vibration_rounded, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Acelerometría y Cinemática (ESP32)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _AccelAxis(
                  label: 'Eje X',
                  value: reading.accelX,
                  color: AppTheme.thiEmergency),
              _AccelAxis(
                  label: 'Eje Y',
                  value: reading.accelY,
                  color: AppTheme.primary),
              _AccelAxis(
                  label: 'Eje Z',
                  value: reading.accelZ,
                  color: const Color(0xFF0288D1)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 15, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reading.movementIntensity > 2.0
                        ? 'Movimiento elevado detectado — posible estado de celo o agitación'
                        : reading.movementIntensity > 0.5
                            ? 'Movimiento normal en potrero'
                            : 'Baja aceleración — descanso / rumiación normal',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
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

  // ═══════════════════════════════════════════════════════════════
  // 6. HARDWARE DETAILS CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHardwareDetailsCard(SensorReading reading) {
    return Container(
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
              Icon(Icons.developer_board_rounded,
                  size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Detalles del Collar IoT',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(label: 'Identificador', value: reading.deviceId),
          _InfoRow(
            label: 'Animal Asignado',
            value: reading.animalName.isNotEmpty
                ? reading.animalName
                : 'Sin nombre',
          ),
          _InfoRow(
            label: 'Voltaje Batería',
            value:
                '${reading.batteryVoltage.toStringAsFixed(2)} V (${reading.batteryPercent.round()}%)',
          ),
          _InfoRow(
            label: 'Conectividad',
            value: '4G LTE / WiFi (Excelente)',
          ),
          if (reading.latitude != null && reading.longitude != null)
            _InfoRow(
              label: 'Ubicación GPS',
              value:
                  '${reading.latitude!.toStringAsFixed(4)}, ${reading.longitude!.toStringAsFixed(4)}',
            ),
          _InfoRow(
            label: 'Última Lectura',
            value: _formatTime(reading.timestamp),
          ),
        ],
      ),
    );
  }

  String _thiDescription(String level) => switch (level) {
        'emergency' =>
          'Condiciones extremas. Riesgo vital inmediato por estrés calórico.',
        'danger' =>
          'Estrés calórico severo. Activar aspersión y ventilación forzada.',
        'alert' =>
          'Estrés calórico moderado. Asegurar agua fresca y sombra abundante.',
        _ => 'Condiciones normales de confort térmico. Sin acción requerida.',
      };

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════
// SUBCOMPONENTS
// ═══════════════════════════════════════════════════════════════

class _CompactMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _CompactMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccelAxis extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _AccelAxis({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          'm/s²',
          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
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
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthStatusCard extends StatelessWidget {
  final SensorReading reading;
  const _HealthStatusCard({required this.reading});

  @override
  Widget build(BuildContext context) {
    final status = reading.healthStatus;
    final isHealthy = status == 'healthy';

    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;
    final String statusDesc;

    switch (status) {
      case 'fever':
        statusColor = const Color(0xFFFF6D00);
        statusIcon = Icons.thermostat_rounded;
        statusLabel = 'Fiebre Detectada';
        statusDesc = 'Temperatura elevada sostenida.';
      case 'lethargy':
        statusColor = const Color(0xFFFFD600);
        statusIcon = Icons.hotel_rounded;
        statusLabel = 'Letargo Detectado';
        statusDesc = 'Actividad muy baja sostenida.';
      case 'sick_suspected':
        statusColor = const Color(0xFFFF1744);
        statusIcon = Icons.local_hospital_rounded;
        statusLabel = 'Posible Enfermedad';
        statusDesc = 'Fiebre + letargo — revisar al animal inmediatamente.';
      default:
        statusColor = AppTheme.thiNormal;
        statusIcon = Icons.favorite_rounded;
        statusLabel = 'Saludable';
        statusDesc = 'Sin anomalías detectadas por el collar.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHealthy ? AppTheme.divider : statusColor.withAlpha(100),
          width: isHealthy ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 18, color: statusColor),
              const SizedBox(width: 8),
              Text(
                'Estado de Salud',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(isHealthy ? 10 : 20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  statusDesc,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
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

class _ReproductionCard extends StatelessWidget {
  final SensorReading reading;
  final bool hasEstrusAlert;

  const _ReproductionCard({
    required this.reading,
    required this.hasEstrusAlert,
  });

  @override
  Widget build(BuildContext context) {
    final score = reading.estrusScore;
    final Color barColor = hasEstrusAlert
        ? const Color(0xFFE91E63)
        : score > 0.5
            ? const Color(0xFFFF9800)
            : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasEstrusAlert
              ? const Color(0xFFE91E63).withAlpha(100)
              : AppTheme.divider,
          width: hasEstrusAlert ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasEstrusAlert ? Icons.favorite_rounded : Icons.biotech_rounded,
                size: 18,
                color: hasEstrusAlert
                    ? const Color(0xFFE91E63)
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Actividad y Celo Reproductivo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Puntuación de celo:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score.clamp(0.0, 1.0),
                    backgroundColor: AppTheme.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(score * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: barColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasEstrusAlert
                ? '¡Posible celo detectado! Actividad giroscópica elevada sostenida.'
                : 'Actividad basal en reposo / rumia normal.',
            style: TextStyle(
              fontSize: 11.5,
              color: hasEstrusAlert
                  ? const Color(0xFFE91E63)
                  : AppTheme.textSecondary,
              fontWeight: hasEstrusAlert ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
