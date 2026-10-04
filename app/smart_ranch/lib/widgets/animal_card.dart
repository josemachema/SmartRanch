import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/sensor_reading.dart';
import 'thi_gauge.dart';

/// Card widget displaying an animal's current status — responsive and overflow-safe.
class AnimalCard extends StatefulWidget {
  final SensorReading reading;
  final VoidCallback? onTap;
  final bool hasEstrusAlert;
  final String? healthAlertType;

  const AnimalCard({
    super.key,
    required this.reading,
    this.onTap,
    this.hasEstrusAlert = false,
    this.healthAlertType,
  });

  @override
  State<AnimalCard> createState() => _AnimalCardState();
}

class _AnimalCardState extends State<AnimalCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reading = widget.reading;
    final color = AppTheme.thiColor(reading.thiLevel);
    final isDanger =
        reading.thiLevel == 'danger' || reading.thiLevel == 'emergency';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.cardBright : AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDanger ? color.withAlpha(150) : color.withAlpha(50),
              width: isDanger ? 1.5 : 1,
            ),
            boxShadow: [
              if (isDanger)
                BoxShadow(
                  color: color.withAlpha(30),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              if (_hovered)
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Icon + Name + Alert Badges (NO status badge here)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.pets_rounded,
                        size: 18,
                        color: color,
                      ),
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
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  reading.deviceId,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                    fontFamily: 'monospace',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                reading.batteryPercent > 50
                                    ? Icons.battery_full_rounded
                                    : reading.batteryPercent > 20
                                        ? Icons.battery_4_bar_rounded
                                        : Icons.battery_alert_rounded,
                                size: 12,
                                color: reading.batteryPercent > 20
                                    ? AppTheme.textSecondary
                                    : AppTheme.thiDanger,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${reading.batteryPercent.round()}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.healthAlertType != null &&
                        widget.healthAlertType != 'healthy')
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _IconBadge(
                          icon: widget.healthAlertType == 'sick_suspected'
                              ? Icons.local_hospital_rounded
                              : widget.healthAlertType == 'fever'
                                  ? Icons.device_thermostat_rounded
                                  : Icons.bedtime_rounded,
                          color: const Color(0xFFFF1744),
                          tooltip: widget.healthAlertType == 'sick_suspected'
                              ? 'Enfermo sospechado'
                              : widget.healthAlertType == 'fever'
                                  ? 'Fiebre'
                                  : 'Letargia',
                        ),
                      ),
                    if (widget.hasEstrusAlert)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: const _IconBadge(
                          icon: Icons.favorite_rounded,
                          color: Color(0xFFE91E63),
                          tooltip: 'Celo detectado',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // THI Gauge (centered)
                Center(
                  child: ThiGauge(
                    value: reading.thi,
                    level: reading.thiLevel,
                    size: 82,
                  ),
                ),
                const SizedBox(height: 12),

                // Stats in 2 Rows x 2 Columns
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        icon: Icons.thermostat_rounded,
                        label: reading.bodyTemp > 10
                            ? '${reading.bodyTemp.toStringAsFixed(1)}°C'
                            : '38.5°C (Est.)',
                        sublabel: reading.bodyTemp > 10 ? 'T. Corporal' : 'T. Corp (Est.)',
                        color: reading.bodyTemp > 40
                            ? AppTheme.thiDanger
                            : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatChip(
                        icon: Icons.wb_sunny_rounded,
                        label: '${reading.ambientTemp.toStringAsFixed(1)}°C',
                        sublabel: 'T. Ambiente',
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        icon: Icons.water_drop_rounded,
                        label: '${reading.humidity.toStringAsFixed(0)}%',
                        sublabel: 'Humedad',
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatChip(
                        icon: Icons.directions_walk_rounded,
                        label: reading.movementIntensity > 0
                            ? reading.movementIntensity.toStringAsFixed(0)
                            : 'Reposo',
                        sublabel: reading.movementIntensity <= 1 ? 'En Rumia' : 'Actividad',
                        color: reading.movementIntensity > 80
                            ? AppTheme.thiAlert
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status Badge at the bottom
                _StatusBadge(level: reading.thiLevel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Material icon badge replacing emoji badges.
class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  const _IconBadge({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String level;
  const _StatusBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.thiColor(level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(90)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppTheme.thiIcon(level), size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            AppTheme.thiLabel(level).toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withAlpha(120),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  sublabel,
                  style: TextStyle(
                    fontSize: 9.5,
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
