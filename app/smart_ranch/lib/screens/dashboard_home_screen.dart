import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/ranch_models.dart';
import '../models/sensor_reading.dart';
import '../models/trough_reading.dart';
import '../services/ranch_api_service.dart';
import '../services/auth_service.dart';
import '../services/demo_service.dart';
import '../widgets/crud_dialogs.dart';

/// Dashboard home screen — Operational Command Center with real-time IoT telemetry,
/// thermal comfort (THI) index, water trough monitoring, and tactile quick actions.
class DashboardHomeScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  final DemoService? demoService;

  const DashboardHomeScreen({
    super.key,
    this.onNavigate,
    this.demoService,
  });

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  static final _demoStats = DashboardStats(
    totalActive: 5,
    animalsByStatus: {'active': 5},
    animalsByCategory: {'vaca': 3, 'becerro': 1, 'toro': 1},
    upcomingMedical7d: 2,
    expectedBirths30d: 1,
    unacknowledgedAlerts: 3,
  );

  static final _cleanStats = DashboardStats(
    totalActive: 0,
    animalsByStatus: {'active': 0},
    animalsByCategory: {'vaca': 0, 'becerro': 0, 'toro': 0},
    upcomingMedical7d: 0,
    expectedBirths30d: 0,
    unacknowledgedAlerts: 0,
  );

  DashboardStats _stats = AuthService.isDemoMode ? _demoStats : _cleanStats;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final result = await RanchApiService.getDashboardStats().timeout(
        const Duration(seconds: 2),
      );
      if (mounted) {
        setState(() {
          _stats = result;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _stats = AuthService.isDemoMode ? _demoStats : _cleanStats;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = widget.demoService;

    if (demo != null) {
      return ListenableBuilder(
        listenable: demo,
        builder: (context, _) => _buildContent(demo),
      );
    }

    return _buildContent(null);
  }

  Widget _buildContent(DemoService? demo) {
    final readings = demo?.latestReadings.values.toList() ?? [];
    final troughs = demo?.troughReadings.values.toList() ?? [];
    final estrusAlerts = demo?.activeEstrusAlerts ?? {};
    final healthAlerts = demo?.activeHealthAlerts ?? {};

    // Telemetry calculations
    final hasReadings = readings.isNotEmpty;
    final double avgThi = hasReadings
        ? readings.map((r) => r.thi).reduce((a, b) => a + b) / readings.length
        : 71.4;
    final double avgTemp = hasReadings
        ? readings.map((r) => r.ambientTemp).reduce((a, b) => a + b) / readings.length
        : 31.2;
    final double avgHumidity = hasReadings
        ? readings.map((r) => r.humidity).reduce((a, b) => a + b) / readings.length
        : 45.0;

    String thiLevel = 'normal';
    if (avgThi >= 89) {
      thiLevel = 'emergency';
    } else if (avgThi >= 79) {
      thiLevel = 'danger';
    } else if (avgThi >= 72) {
      thiLevel = 'alert';
    }

    // Troughs calculations
    final double avgWaterPct = troughs.isNotEmpty
        ? troughs.map((t) => t.levelPercent).reduce((a, b) => a + b) / troughs.length
        : 82.0;

    // Cattle counts
    final int totalActive = _stats.totalActive > 0
        ? _stats.totalActive
        : (hasReadings ? readings.length : 0);

    // Total pending alerts
    final int totalAlerts = _stats.unacknowledgedAlerts +
        estrusAlerts.length +
        healthAlerts.length;

    // Collar disconnection watchdog check
    final bool hasDisconnectedCollar = demo?.isCollarSimulatedDisconnected == true ||
        (demo != null && readings.any((r) => !demo.isCollarOnline(r.deviceId)));
    final String disconnectedDevice = demo?.isCollarSimulatedDisconnected == true
        ? 'Collar-SmartRanch'
        : (readings.cast<SensorReading?>().firstWhere(
            (r) => r != null && demo != null && !demo.isCollarOnline(r.deviceId),
            orElse: () => null,
          )?.deviceId ?? 'Collar-SmartRanch');
    final int disconnectedMinutes = demo?.timeSinceLastCollarPacket(disconnectedDevice)?.inMinutes ?? 24;

    // Zero-state condition
    final bool isZeroState = totalActive == 0 && !hasReadings;

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Ranch Command Header (Weather, THI pulse, connectivity)
            _buildHeader(
              avgThi: avgThi,
              thiLevel: thiLevel,
              avgTemp: avgTemp,
              avgHumidity: avgHumidity,
              iotOnline: demo?.isRunning ?? true,
              collarsCount: readings.length,
              hasDisconnectedCollar: hasDisconnectedCollar,
              disconnectedMinutes: disconnectedMinutes,
            ),
            const SizedBox(height: 18),

            // Collar Disconnection Contingency Banner (High-Priority)
            if (hasDisconnectedCollar) ...[
              _buildCollarContingencyBanner(disconnectedDevice, disconnectedMinutes),
              const SizedBox(height: 18),
            ],

            // 2. High-Impact Responsive KPI Grid (Full width)
            _buildKpiGrid(
              totalActive: totalActive,
              totalAlerts: totalAlerts,
              avgWaterPct: avgWaterPct,
              troughCount: troughs.isNotEmpty ? troughs.length : 3,
              upcomingMedical7d: _stats.upcomingMedical7d,
              reproductiveEvents: _stats.expectedBirths30d + estrusAlerts.length,
              estrusCount: estrusAlerts.length,
            ),
            const SizedBox(height: 20),

            // 3. Zero-state onboarding banner (if empty)
            if (isZeroState) ...[
              _buildZeroStateBanner(),
              const SizedBox(height: 20),
            ],

            // 4. Main 2-Column Responsive Operational Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1060;

                if (!isWide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildWaterMonitoringCard(troughs, avgWaterPct),
                      const SizedBox(height: 16),
                      _buildHerdDistributionCard(_stats, totalActive),
                      const SizedBox(height: 16),
                      _buildThiComfortCard(avgThi, thiLevel, readings),
                      const SizedBox(height: 16),
                      _buildTactileQuickActions(),
                      const SizedBox(height: 16),
                      _buildOperationsFeed(estrusAlerts, healthAlerts, _stats),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (60%) — IoT Telemetry, Water & Herd Welfare
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildWaterMonitoringCard(troughs, avgWaterPct),
                          const SizedBox(height: 16),
                          _buildHerdDistributionCard(_stats, totalActive),
                          const SizedBox(height: 16),
                          _buildThiComfortCard(avgThi, thiLevel, readings),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),

                    // Right Column (40%) — Tactile Quick Actions & Live Operations Stream
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTactileQuickActions(),
                          const SizedBox(height: 16),
                          _buildOperationsFeed(estrusAlerts, healthAlerts, _stats),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCollarContingencyBanner(String deviceId, int minutes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F).withAlpha(14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD32F2F).withAlpha(120), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD32F2F).withAlpha(16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;

          final content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F).withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD32F2F).withAlpha(80)),
                ),
                child: const Icon(
                  Icons.sensors_off_rounded,
                  color: Color(0xFFD32F2F),
                  size: 24,
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
                            '⚠️ CONTINGENCIA IOT: Collar "$deviceId" Desconectado',
                            style: const TextStyle(
                              color: Color(0xFFD32F2F),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD32F2F),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'HACE $minutes MIN',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Se interrumpió la señal LoRa/Celular. El sistema ha activado el protocolo de contingencia: posición satelital y signos vitales congelados en Última Posición Conocida (LKP) con radio de búsqueda dinámico.',
                      style: TextStyle(
                        color: AppTheme.textPrimary.withAlpha(210),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final actions = Row(
            mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showContingencyProtocolModal(context, deviceId, minutes),
                icon: const Icon(Icons.checklist_rounded, size: 15),
                label: const Text('Protocolo', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD32F2F),
                  side: BorderSide(color: const Color(0xFFD32F2F).withAlpha(120)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => widget.onNavigate?.call(9),
                icon: const Icon(Icons.radar_rounded, size: 15),
                label: const Text('Rastrear LKP en Mapa', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  elevation: 0,
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content,
                const SizedBox(height: 12),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: content),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }

  void _showContingencyProtocolModal(BuildContext context, String deviceId, int minutes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFFD32F2F).withAlpha(80)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emergency_outlined, color: Color(0xFFD32F2F), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Protocolo de Contingencia IoT',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Collar $deviceId • Desconectado hace $minutes min',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F).withAlpha(12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD32F2F).withAlpha(50)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFFD32F2F), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Las coordenadas del animal quedan congeladas en LKP (Última Posición Conocida) para evitar pérdida en el mapa.',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textPrimary.withAlpha(220), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('PASOS OPERATIVOS EN CAMPO:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              _buildHomeProtocolStep(
                '1',
                'Localizar LKP en Mapa Satelital',
                'Abrir la pantalla de GPS y dirigirse al centro del círculo de dispersión estimado en potrero.',
              ),
              _buildHomeProtocolStep(
                '2',
                'Inspección Visual del Ejemplar',
                'Verificar que el animal no esté encallado o atrapado en cañadas, presas o alambrados.',
              ),
              _buildHomeProtocolStep(
                '3',
                'Diagnóstico de Batería y Panel Solar',
                'Revisar si las celdas solares tienen lodo o si el pack LiFePO4 bajó de 3.0V por falta de radiación.',
              ),
              _buildHomeProtocolStep(
                '4',
                'Reset o Reemplazo de Dispositivo',
                'Acercar imán al sensor Hall para reiniciar el microcontrolador o sustituir por collar de repuesto.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cerrar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onNavigate?.call(9);
            },
            icon: const Icon(Icons.radar_rounded, size: 16),
            label: const Text('Rastrear en Mapa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeProtocolStep(String step, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(25),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary.withAlpha(80)),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.25)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 1. HEADER & ENVIRONMENTAL PULSE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeader({
    required double avgThi,
    required String thiLevel,
    required double avgTemp,
    required double avgHumidity,
    required bool iotOnline,
    required int collarsCount,
    bool hasDisconnectedCollar = false,
    int disconnectedMinutes = 24,
  }) {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Buenos días'
        : hour < 19
            ? 'Buenas tardes'
            : 'Buenas noches';

    String name = AuthService.displayName;
    if (name.isEmpty || name.toLowerCase() == 'demo') {
      name = 'Carlos';
    }
    final ranchName = AuthService.ranchName.isNotEmpty
        ? AuthService.ranchName
        : 'Rancho Puerto Peñasco';

    final now = DateTime.now();
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    final dateStr = '${now.day} ${months[now.month - 1]} ${now.year}';
    final thiColor = AppTheme.thiColor(thiLevel);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 750;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isCompact ? 6 : 8),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // User Greeting & Ranch Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '$timeGreeting, $name',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: isCompact ? 20 : 24,
                              letterSpacing: -0.6,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '🤠',
                          style: TextStyle(fontSize: isCompact ? 18 : 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$ranchName, Sonora • $dateStr',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Environmental & IoT Pulse Badge
              if (!isCompact) ...[
                // THI Badge
                InkWell(
                  onTap: () => widget.onNavigate?.call(1),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: thiColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: thiColor.withAlpha(80)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppTheme.thiIcon(thiLevel),
                            size: 18, color: thiColor),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'THI ${avgThi.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    color: thiColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '• ${AppTheme.thiLabel(thiLevel)}',
                                  style: TextStyle(
                                    color: thiColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${avgTemp.toStringAsFixed(1)}°C • ${avgHumidity.toStringAsFixed(0)}% HR',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // IoT Status Capsule
                InkWell(
                  onTap: () => widget.onNavigate?.call(hasDisconnectedCollar ? 9 : 14),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: hasDisconnectedCollar
                          ? const Color(0xFFD32F2F).withAlpha(18)
                          : AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasDisconnectedCollar
                            ? const Color(0xFFD32F2F).withAlpha(120)
                            : AppTheme.divider,
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
                            color: hasDisconnectedCollar
                                ? const Color(0xFFD32F2F)
                                : (iotOnline
                                    ? AppTheme.primary
                                    : AppTheme.thiEmergency),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hasDisconnectedCollar
                                  ? 'Alerta Desconexión'
                                  : (iotOnline ? 'IoT En línea' : 'Sin conexión'),
                              style: TextStyle(
                                color: hasDisconnectedCollar
                                    ? const Color(0xFFD32F2F)
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                            Text(
                              hasDisconnectedCollar
                                  ? 'LKP activa ($disconnectedMinutes min)'
                                  : (collarsCount > 0
                                      ? '$collarsCount collares activos'
                                      : 'Esperando collares'),
                              style: TextStyle(
                                color: hasDisconnectedCollar
                                    ? const Color(0xFFD32F2F).withAlpha(220)
                                    : AppTheme.textSecondary,
                                fontSize: 10,
                                fontWeight: hasDisconnectedCollar
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // Refresh Button
              IconButton(
                icon: _isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      )
                    : Icon(Icons.refresh_rounded,
                        color: AppTheme.primary, size: 22),
                onPressed: _isLoading ? null : _loadStats,
                tooltip: 'Sincronizar datos',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.surfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppTheme.divider),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 2. EXPANDED RESPONSIVE KPI GRID
  // ═══════════════════════════════════════════════════════════════

  Widget _buildKpiGrid({
    required int totalActive,
    required int totalAlerts,
    required double avgWaterPct,
    required int troughCount,
    required int upcomingMedical7d,
    required int reproductiveEvents,
    required int estrusCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Adaptive column count: 5 columns on desktop, 3 on tablet, 2 on mobile
        int crossAxisCount = 5;
        if (width < 640) {
          crossAxisCount = 2;
        } else if (width < 1000) {
          crossAxisCount = 3;
        }

        final cards = [
          _KpiCard(
            title: 'Hato Total',
            value: '$totalActive',
            subtitle: totalActive > 0 ? 'Bovinos activos' : 'Sin registros',
            badge: totalActive > 0 ? 'En potrero' : 'Alta requerida',
            icon: Icons.pets_rounded,
            color: AppTheme.primary,
            onTap: () => widget.onNavigate?.call(3), // Navigate to Herd
          ),
          _KpiCard(
            title: 'Alertas',
            value: '$totalAlerts',
            subtitle: totalAlerts > 0 ? 'Requieren revisión' : 'Todo en orden',
            badge: totalAlerts > 0 ? 'Atención' : 'Óptimo',
            icon: Icons.notifications_active_rounded,
            color: totalAlerts > 0 ? AppTheme.thiDanger : AppTheme.primary,
            onTap: () => widget.onNavigate?.call(6), // Navigate to Alerts
          ),
          _KpiCard(
            title: 'Reserva Hídrica',
            value: '${avgWaterPct.round()}%',
            subtitle: '$troughCount bebederos IoT',
            badge: avgWaterPct <= 20
                ? 'Crítico'
                : avgWaterPct <= 50
                    ? 'Medio'
                    : 'Lleno',
            icon: Icons.water_drop_rounded,
            color: const Color(0xFF0288D1),
            onTap: () => widget.onNavigate?.call(2), // Navigate to Water
          ),
          _KpiCard(
            title: 'Sanidad (7d)',
            value: '$upcomingMedical7d',
            subtitle: upcomingMedical7d > 0
                ? 'Dosis programadas'
                : 'Al día',
            badge: upcomingMedical7d > 0 ? 'Pendiente' : 'Al día',
            icon: Icons.vaccines_rounded,
            color: const Color(0xFFFB8C00),
            onTap: () => widget.onNavigate?.call(4), // Navigate to Sanidad
          ),
          _KpiCard(
            title: 'Reproducción',
            value: '$reproductiveEvents',
            subtitle: estrusCount > 0
                ? '$estrusCount celo(s) en curso'
                : 'Control gestacional',
            badge: estrusCount > 0 ? 'Celo Activo' : 'Normal',
            icon: Icons.favorite_rounded,
            color: const Color(0xFFE91E63),
            onTap: () => widget.onNavigate?.call(5), // Navigate to Reproductive
          ),
        ];

        if (crossAxisCount == 5) {
          return Row(
            children: cards
                .map((c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: c,
                      ),
                    ))
                .toList(),
          );
        }

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards.map((c) {
            final cardWidth = (width - ((crossAxisCount - 1) * 10)) / crossAxisCount;
            return SizedBox(
              width: cardWidth,
              child: c,
            );
          }).toList(),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 3. ZERO STATE ONBOARDING BANNER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildZeroStateBanner() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 650;

        return Container(
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withAlpha(60)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primary.withAlpha(12),
                AppTheme.card,
              ],
            ),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add_home_work_rounded,
                              color: AppTheme.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '¡Comienza a operar tu Rancho!',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tu cuenta está activa en Puerto Peñasco. Registra tu primer lote o vincula un collar IoT para ver telemetría en vivo.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Registrar Primer Bovino'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => widget.onNavigate?.call(12),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_home_work_rounded,
                          color: AppTheme.primary, size: 30),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Comienza a operar tu Rancho Inteligente!',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tu cuenta está activa en Puerto Peñasco, pero aún no tiene bovinos registrados. '
                            'Comienza registrando tu primer lote o vincula un collar IoT para ver telemetría en vivo.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Registrar Primer Bovino'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => widget.onNavigate?.call(12),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 4. WATER MONITORING CARD (CRITICAL SONORA RESOURCE)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildWaterMonitoringCard(
      List<TroughReading> troughs, double avgWaterPct) {
    // If no readings, use realistic default representation for Puerto Peñasco ranches
    final displayTroughs = troughs.isNotEmpty
        ? troughs
        : [
            TroughReading(
              troughId: 'bebedero_01',
              troughName: 'Potrero Norte',
              levelPercent: 88,
              distanceCm: 14.5,
            ),
            TroughReading(
              troughId: 'bebedero_02',
              troughName: 'Corral Principal',
              levelPercent: 92,
              distanceCm: 11.2,
            ),
            TroughReading(
              troughId: 'bebedero_03',
              troughName: 'Potrero Sur',
              levelPercent: 72,
              distanceCm: 25.8,
            ),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0288D1).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.water_drop_rounded,
                    size: 16, color: Color(0xFF0288D1)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nivel de Agua en Potreros (IoT)',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Ver Bebederos'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0288D1),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => widget.onNavigate?.call(2), // Navigate to Water
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Troughs list
          ...displayTroughs.map((t) {
            Color statusCol = AppTheme.thiNormal;
            if (t.levelPercent <= 20) {
              statusCol = AppTheme.thiEmergency;
            } else if (t.levelPercent <= 50) {
              statusCol = AppTheme.thiAlert;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          t.troughName.isNotEmpty ? t.troughName : t.troughId,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${t.distanceCm.toStringAsFixed(1)} cm al nivel)',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${t.levelPercent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: statusCol,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          color: AppTheme.surfaceVariant,
                        ),
                        FractionallySizedBox(
                          widthFactor: (t.levelPercent / 100.0).clamp(0.0, 1.0),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusCol,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 5. HERD DISTRIBUTION CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHerdDistributionCard(DashboardStats stats, int totalActive) {
    Map<String, int> categories = stats.animalsByCategory;

    // Fallback if empty and demo mode
    if (categories.isEmpty || categories.values.every((v) => v == 0)) {
      if (AuthService.isDemoMode || totalActive > 0) {
        categories = {'vaca': 3, 'becerro': 1, 'toro': 1};
      }
    }

    final total = categories.values.fold<int>(0, (s, v) => s + v);

    final colorMap = {
      'vaca': AppTheme.primary,
      'becerro': const Color(0xFF43A047),
      'toro': const Color(0xFF7E57C2),
      'novilla': const Color(0xFFAB47BC),
      'novillo': const Color(0xFF26A69A),
    };

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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.pie_chart_rounded,
                    size: 16, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Composición y Estructura del Hato',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$total animales',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (total == 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: Text(
                'Sin bovinos registrados para categorizar.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          ] else ...[
            // Multi-segment horizontal bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: categories.entries
                      .where((e) => e.value > 0)
                      .map((e) {
                    final pct = total > 0 ? e.value / total : 0.0;
                    final flexValue = (pct * 100).round().clamp(1, 100);
                    return Flexible(
                      flex: flexValue,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: colorMap[e.key] ?? AppTheme.textSecondary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Category Badges Wrap
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: categories.entries.map((e) {
                final pct = total > 0 ? (e.value / total * 100).round() : 0;
                final col = colorMap[e.key] ?? AppTheme.textSecondary;

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_categoryLabel(e.key)}: ',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${e.value} ($pct%)',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _categoryLabel(String key) => switch (key.toLowerCase()) {
        'vaca' => 'Vacas',
        'becerro' => 'Becerros',
        'toro' => 'Toros',
        'novilla' => 'Novillas',
        'novillo' => 'Novillos',
        _ => key,
      };

  // ═══════════════════════════════════════════════════════════════
  // 6. THI COMFORT & CLIMATE WELFARE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildThiComfortCard(
      double avgThi, String thiLevel, List<SensorReading> readings) {
    final thiColor = AppTheme.thiColor(thiLevel);

    // Count stress levels in cattle
    int normalCount = 0;
    int alertCount = 0;
    int dangerCount = 0;
    int emergencyCount = 0;

    for (final r in readings) {
      if (r.thiLevel == 'emergency') {
        emergencyCount++;
      } else if (r.thiLevel == 'danger') {
        dangerCount++;
      } else if (r.thiLevel == 'alert') {
        alertCount++;
      } else {
        normalCount++;
      }
    }

    String advisory = 'Condiciones confortables para el ganado. '
        'Sin riesgo de caída en producción lechera ni ganancia de peso.';
    if (thiLevel == 'alert') {
      advisory = 'Estrés térmico moderado. Asegurar sombra abundante y flujo constante de agua fresca.';
    } else if (thiLevel == 'danger' || thiLevel == 'emergency') {
      advisory = '¡Alerta de estrés calórico severo! Activar aspersores y ventilación en corrales.';
    }

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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: thiColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.thermostat_rounded,
                    size: 16, color: thiColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bienestar Térmico del Hato (Índice THI)',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: thiColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: thiColor.withAlpha(80)),
                ),
                child: Text(
                  AppTheme.thiLabel(thiLevel),
                  style: TextStyle(
                    color: thiColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stress level status bar
          Row(
            children: [
              _ThiLevelPill(
                  label: 'Normal (<72)',
                  count: normalCount > 0 ? normalCount : (readings.isEmpty ? 4 : 0),
                  color: AppTheme.thiNormal),
              const SizedBox(width: 6),
              _ThiLevelPill(
                  label: 'Alerta (72-78)',
                  count: alertCount > 0 ? alertCount : (readings.isEmpty ? 1 : 0),
                  color: AppTheme.thiAlert),
              const SizedBox(width: 6),
              _ThiLevelPill(
                  label: 'Peligro (79-88)',
                  count: dangerCount,
                  color: AppTheme.thiDanger),
              const SizedBox(width: 6),
              _ThiLevelPill(
                  label: 'Emergencia (>88)',
                  count: emergencyCount,
                  color: AppTheme.thiEmergency),
            ],
          ),
          const SizedBox(height: 12),

          // Recommendation banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_rounded,
                    size: 16, color: thiColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    advisory,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11.5,
                      height: 1.3,
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
  // 7. TACTILE QUICK ACTIONS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTactileQuickActions() {
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.bolt_rounded,
                    size: 16, color: AppTheme.secondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Acciones Rápidas Operativas',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Grid of Action Buttons
          LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  _TactileActionTile(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Registrar Animal',
                    subtitle: 'Alta de nuevo bovino o arete',
                    color: AppTheme.primary,
                    onTap: () => widget.onNavigate?.call(12),
                  ),
                  const SizedBox(height: 8),
                  _TactileActionTile(
                    icon: Icons.vaccines_rounded,
                    title: 'Nueva Vacuna / Medicamento',
                    subtitle: 'Registrar tratamiento y retiro',
                    color: const Color(0xFFFB8C00),
                    onTap: () => showAddMedicalDialog(context),
                  ),
                  const SizedBox(height: 8),
                  _TactileActionTile(
                    icon: Icons.monitor_weight_rounded,
                    title: 'Registrar Pesaje',
                    subtitle: 'Báscula y condición corporal',
                    color: const Color(0xFF26A69A),
                    onTap: () => showAddWeightDialog(context),
                  ),
                  const SizedBox(height: 8),
                  _TactileActionTile(
                    icon: Icons.map_rounded,
                    title: 'Ver Mapa Satelital',
                    subtitle: 'Geocercas y ubicación en potrero',
                    color: const Color(0xFF0288D1),
                    onTap: () => widget.onNavigate?.call(9),
                  ),
                  const SizedBox(height: 8),
                  _TactileActionTile(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Movimiento Financiero',
                    subtitle: 'Ingresos, ventas y gastos del rancho',
                    color: const Color(0xFF7E57C2),
                    onTap: () => showAddFinancialDialog(context),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 8. OPERATIONS FEED & ALERTS STREAM
  // ═══════════════════════════════════════════════════════════════

  Widget _buildOperationsFeed(
    Map<String, dynamic> estrusAlerts,
    Map<String, dynamic> healthAlerts,
    DashboardStats stats,
  ) {
    final bool hasUrgentItems = estrusAlerts.isNotEmpty ||
        healthAlerts.isNotEmpty ||
        stats.unacknowledgedAlerts > 0 ||
        stats.upcomingMedical7d > 0;

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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.thiDanger.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.notifications_active_rounded,
                    size: 16, color: AppTheme.thiDanger),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Alertas & Eventos Críticos',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasUrgentItems) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.thiDanger.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Atención',
                    style: TextStyle(
                      color: AppTheme.thiDanger,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          if (estrusAlerts.isNotEmpty)
            ...estrusAlerts.entries.map((e) => _EventNotificationTile(
                  icon: Icons.local_fire_department_rounded,
                  title: '¡Posible Celo Detectado! — ${e.key}',
                  subtitle: 'Actividad giroscópica +160% en collar',
                  color: const Color(0xFFE91E63),
                  onTap: () => widget.onNavigate?.call(5),
                )),

          if (healthAlerts.isNotEmpty)
            ...healthAlerts.entries.map((e) => _EventNotificationTile(
                  icon: Icons.medical_services_rounded,
                  title: 'Alerta de Salud — ${e.key}',
                  subtitle: 'Caída de rumia o posible estado febril',
                  color: AppTheme.thiDanger,
                  onTap: () => widget.onNavigate?.call(4),
                )),

          if (stats.upcomingMedical7d > 0)
            _EventNotificationTile(
              icon: Icons.vaccines_rounded,
              title: '${stats.upcomingMedical7d} Tratamiento(s) Programado(s)',
              subtitle: 'Vacunas y desparasitaciones en los próximos 7 días',
              color: const Color(0xFFFB8C00),
              onTap: () => widget.onNavigate?.call(4),
            ),

          if (stats.expectedBirths30d > 0)
            _EventNotificationTile(
              icon: Icons.child_care_rounded,
              title: '${stats.expectedBirths30d} Parto(s) en 30 Días',
              subtitle: 'Preparar área de maternidad en corral',
              color: AppTheme.secondary,
              onTap: () => widget.onNavigate?.call(5),
            ),

          if (!hasUrgentItems)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppTheme.thiNormal, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hato en Parámetros Normales',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sin incidencias sanitarias, retiros médicos ni alertas de calor vigentes.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
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

// ═══════════════════════════════════════════════════════════════
// REUSABLE MICRO-COMPONENTS (MAKE INTERFACES FEEL BETTER)
// ═══════════════════════════════════════════════════════════════

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Icon Container + Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withAlpha(16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Metric Value with Tabular figures
              Text(
                value,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  letterSpacing: -0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),

              // Title and Subtitle
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
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

class _TactileActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _TactileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventNotificationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _EventNotificationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: color.withAlpha(12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withAlpha(50)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThiLevelPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ThiLevelPill({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: count > 0 ? color.withAlpha(20) : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: count > 0 ? color.withAlpha(80) : AppTheme.divider,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: count > 0 ? color : AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}