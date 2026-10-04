import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/trough_reading.dart';

/// Industrial IoT Card displaying a water trough or reservoir tank
/// with realistic visual reservoir level, telemetry metrics, and tactile actions.
class TroughCard extends StatefulWidget {
  final TroughReading reading;
  final VoidCallback? onRefill;
  final VoidCallback? onCalibrate;
  final VoidCallback? onViewHistory;

  const TroughCard({
    super.key,
    required this.reading,
    this.onRefill,
    this.onCalibrate,
    this.onViewHistory,
  });

  @override
  State<TroughCard> createState() => _TroughCardState();
}

class _TroughCardState extends State<TroughCard> {
  bool _hovered = false;

  Color _levelColor(double level) {
    if (level <= 15) return const Color(0xFFFF1744); // Critical red
    if (level <= 30) return const Color(0xFFFF6D00); // Warning orange
    if (level <= 60) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFF0288D1); // Pure water blue
  }

  Color _levelBgColor(double level) {
    if (level <= 15) return const Color(0xFFFF1744).withAlpha(15);
    if (level <= 30) return const Color(0xFFFF6D00).withAlpha(15);
    if (level <= 60) return const Color(0xFFF59E0B).withAlpha(15);
    return const Color(0xFF0288D1).withAlpha(15);
  }

  String _statusBadgeText(double level) {
    if (level <= 15) return 'CRÍTICO (<15%)';
    if (level <= 30) return 'BAJO (ALERTA)';
    if (level <= 60) return 'MEDIO';
    return 'ÓPTIMO (>60%)';
  }

  @override
  Widget build(BuildContext context) {
    final reading = widget.reading;
    final isLow = reading.isLow;
    final mainColor = _levelColor(reading.levelPercent);
    final statusBg = _levelBgColor(reading.levelPercent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0.0, _hovered ? -2.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          color: _hovered ? AppTheme.cardBright : AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLow
                ? const Color(0xFFFF1744).withAlpha(140)
                : (_hovered ? mainColor.withAlpha(90) : AppTheme.divider),
            width: isLow ? 1.5 : (_hovered ? 1.2 : 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color: isLow
                  ? const Color(0xFFFF1744).withAlpha(25)
                  : (_hovered ? mainColor.withAlpha(20) : Colors.black.withAlpha(6)),
              blurRadius: _hovered ? 18 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Card Header ──────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Water droplet icon badge
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: mainColor.withAlpha(24),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: mainColor.withAlpha(60)),
                  ),
                  child: Icon(
                    isLow ? Icons.warning_rounded : Icons.water_drop_rounded,
                    size: 22,
                    color: mainColor,
                  ),
                ),
                const SizedBox(width: 12),
                // Titles
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              reading.troughName.isNotEmpty
                                  ? reading.troughName
                                  : reading.troughId,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Live telemetry pulse
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isLow ? const Color(0xFFFF1744) : const Color(0xFF00C853),
                              boxShadow: [
                                BoxShadow(
                                  color: (isLow ? const Color(0xFFFF1744) : const Color(0xFF00C853))
                                      .withAlpha(120),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${reading.effectiveTankType} • ID: ${reading.troughId}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: mainColor.withAlpha(80)),
                  ),
                  child: Text(
                    _statusBadgeText(reading.levelPercent),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: mainColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Reservoir Visual + Telemetry Metrics ───────────────────
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Visual Tank Vessel
                  _VisualReservoirTank(
                    reading: reading,
                    mainColor: mainColor,
                  ),
                  const SizedBox(width: 16),

                  // Metrics Column
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Metric 1: Stored Volume
                        _MiniTelemetryTile(
                          icon: Icons.local_drink_rounded,
                          title: 'Volumen Almacenado',
                          value: '${reading.currentVolumeLiters.toStringAsFixed(0)} L',
                          subtitle: 'de ${reading.effectiveCapacityLiters.toStringAsFixed(0)} L capacidad',
                          accentColor: mainColor,
                        ),
                        const SizedBox(height: 8),

                        // Metric 2: Sensor Distance & Depth
                        _MiniTelemetryTile(
                          icon: Icons.straighten_rounded,
                          title: 'Espejo de Agua',
                          value: '${reading.distanceCm.toStringAsFixed(1)} cm',
                          subtitle: 'Prof. tanque: ${reading.tankDepthCm.toStringAsFixed(0)} cm',
                          accentColor: const Color(0xFF00897B),
                        ),
                        const SizedBox(height: 8),

                        // Metric 3: Water Temperature
                        _MiniTelemetryTile(
                          icon: Icons.device_thermostat_rounded,
                          title: 'Temp. del Agua',
                          value: '${reading.effectiveWaterTemp.toStringAsFixed(1)}°C',
                          subtitle: reading.effectiveWaterTemp > 24
                              ? '⚠️ Tibia (>24°C)'
                              : '✅ Fresca / Óptima',
                          accentColor: reading.effectiveWaterTemp > 24
                              ? const Color(0xFFFF6D00)
                              : const Color(0xFF0288D1),
                        ),
                        const SizedBox(height: 8),

                        // Metric 4: Sensor Hardware & Battery
                        _MiniTelemetryTile(
                          icon: Icons.battery_charging_full_rounded,
                          title: 'Nodo LoRaWAN',
                          value: '${reading.effectiveBatteryPercent}% Batería',
                          subtitle: reading.effectiveSensorType,
                          accentColor: const Color(0xFF43A047),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Card Footer Actions & Sync ───────────────────────────
            Row(
              children: [
                // Telemetry sync indicator
                Icon(
                  Icons.sensors_rounded,
                  size: 14,
                  color: AppTheme.textSecondary.withAlpha(160),
                ),
                const SizedBox(width: 5),
                Text(
                  'LoRaWAN SF7 • RSSI -78dBm • En línea',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),

                // Secondary Action: Calibrar
                OutlinedButton.icon(
                  onPressed: widget.onCalibrate,
                  icon: const Icon(Icons.tune_rounded, size: 13),
                  label: const Text('Calibrar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: AppTheme.divider),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Primary Action: Refill / Llenar
                ElevatedButton.icon(
                  onPressed: widget.onRefill,
                  icon: const Icon(Icons.water_rounded, size: 14),
                  label: const Text('Llenar Tanque'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0288D1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Stylized Visual Reservoir Vessel with realistic liquid simulation
class _VisualReservoirTank extends StatelessWidget {
  final TroughReading reading;
  final Color mainColor;

  const _VisualReservoirTank({
    required this.reading,
    required this.mainColor,
  });

  @override
  Widget build(BuildContext context) {
    final pct = reading.levelPercent.clamp(0.0, 100.0);
    final fillFraction = pct / 100.0;

    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withAlpha(80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Ultrasonic sensor illustration at top
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.radar_rounded,
                      size: 11,
                      color: mainColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'JSN-SR04T',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tank Cylinder Body
          Expanded(
            child: Row(
              children: [
                // Fluid chamber
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: mainColor.withAlpha(60), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // Background gradient indicating empty capacity
                        Container(
                          color: AppTheme.surfaceVariant.withAlpha(40),
                        ),

                        // Liquid Fill animated
                        FractionallySizedBox(
                          heightFactor: fillFraction,
                          widthFactor: 1.0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  mainColor.withAlpha(200),
                                  mainColor,
                                ],
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Liquid surface shimmer line
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: 4,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(140),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withAlpha(160),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Center Percentage Overlay
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.card.withAlpha(210),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.divider),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(15),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Text(
                              '${pct.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: mainColor,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Graduated Scale ruler
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _scaleTick('100%'),
                    _scaleTick('75%'),
                    _scaleTick('50%'),
                    _scaleTick('25%'),
                    _scaleTick('0%'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Total Volume pill
          Text(
            '${reading.currentVolumeLiters.toStringAsFixed(0)} Lts',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scaleTick(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 1,
          color: AppTheme.textSecondary.withAlpha(120),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 8.5,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Mini Telemetry data tile inside trough card
class _MiniTelemetryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;

  const _MiniTelemetryTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withAlpha(60),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider.withAlpha(80)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppTheme.textSecondary.withAlpha(200),
                  ),
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
